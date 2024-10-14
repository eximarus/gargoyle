const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const platform = @import("platform");
const core = @import("../../root.zig");
const math = core.math;

const vk = @import("vulkan.zig");
const vkdraw = @import("vkdraw.zig");
const debug_utils = @import("debug_utils.zig");
const types = @import("types.zig");
const loader = @import("loader.zig");
const sc = @import("swapchain.zig");
const resources = @import("resources.zig");
const ImmediateCommand = @import("ImmediateCommand.zig");

const Options = @import("../Options.zig");

const Shader = @import("shader.zig").GraphicsShader;
const createShader = @import("shader.zig").create;

const createInstance = @import("instance.zig").create;
const pickPhysicalDevice = @import("physical_device.zig").pick;
const createDevice = @import("device.zig").create;
const createSwapchain = sc.create;

const Window = platform.Window;

const VulkanRenderer = @This();

const Frame = struct {
    command_pool: c.VkCommandPool,
    command_buffer: c.VkCommandBuffer,
    render_fence: c.VkFence,
    swapchain_semaphore: c.VkSemaphore,
    render_semaphore: c.VkSemaphore,
};

gpa: std.mem.Allocator,
arena: std.mem.Allocator,

instance: c.VkInstance,
debug_messenger: c.VkDebugUtilsMessengerEXT,

gpu: c.VkPhysicalDevice,
gpu_mem_props: c.VkPhysicalDeviceMemoryProperties,

device: c.VkDevice,
surface: c.VkSurfaceKHR,

swapchain: c.VkSwapchainKHR,
swapchain_extent: c.VkExtent2D,
swapchain_images: []c.VkImage,
swapchain_image_views: []c.VkImageView,

graphics_queue_family: u32,
graphics_queue: c.VkQueue,

frame_number: usize = 0,
frames: []Frame,
max_frames_in_flight: usize = 2,

depth_image: resources.Image,
draw_image: resources.Image,
draw_extent: c.VkExtent2D,

imm_command_pool: c.VkCommandPool,
imm_cmd: ImmediateCommand,

test_meshes: []types.Mesh,
test_images: []resources.Texture2D,
geometry_shader: Shader,

default_sampler_nearest: c.VkSampler,
default_sampler_linear: c.VkSampler,
descriptorBufferOffsetAlignment: c.VkDeviceSize,

window: Window,

pub fn init(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    window: Window,
    options: Options,
) !VulkanRenderer {
    vk.init();

    var self: VulkanRenderer = undefined;
    self.window = window;
    self.gpa = gpa;
    self.arena = arena;
    self.frame_number = 0;
    self.max_frames_in_flight = switch (options.n_buffering) {
        .none => 1,
        .double => 2,
        .triple => 3,
    };
    self.frames = try gpa.alloc(Frame, self.max_frames_in_flight);

    self.instance = try createInstance(arena);
    if (vk.enable_validation_layers) {
        self.debug_messenger = try debug_utils.createMessenger(self.instance);
    }

    try vk.check(platform.vk.createSurface(window, self.instance, &self.surface));

    const gpu_result = try pickPhysicalDevice(arena, self.instance, self.surface);
    self.gpu = gpu_result.gpu;
    self.graphics_queue_family = gpu_result.graphics_queue_family;
    vk.getPhysicalDeviceMemoryProperties(self.gpu, &self.gpu_mem_props);

    var descriptor_buffer_props = c.VkPhysicalDeviceDescriptorBufferPropertiesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_PROPERTIES_EXT,
    };
    var props = c.VkPhysicalDeviceProperties2{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
        .pNext = &descriptor_buffer_props,
    };
    vk.getPhysicalDeviceProperties2(self.gpu, &props);
    self.descriptorBufferOffsetAlignment = descriptor_buffer_props.descriptorBufferOffsetAlignment;

    self.device = try createDevice(self.gpu, self.graphics_queue_family);

    vk.getDeviceQueue(self.device, self.graphics_queue_family, 0, &self.graphics_queue);

    const sc_result = try createSwapchain(
        arena,
        self.gpu,
        self.device,
        self.surface,
        .{
            .vsync = options.vsync,
            .width = window.width,
            .height = window.height,
        },
    );
    self.swapchain_extent = sc_result.extent;
    self.swapchain = sc_result.swapchain;

    self.swapchain_images = try sc.getImages(gpa, self.device, self.swapchain);
    self.swapchain_image_views = try sc.getImageViews(
        gpa,
        self.device,
        self.swapchain_images,
    );

    const draw_image_extent = c.VkExtent3D{
        .width = window.width,
        .height = window.height,
        .depth = 1,
    };
    self.draw_image = try resources.createImage(
        self.device,
        c.VK_FORMAT_R16G16B16A16_SFLOAT,
        draw_image_extent,
        c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
            c.VK_IMAGE_USAGE_TRANSFER_DST_BIT |
            c.VK_IMAGE_USAGE_STORAGE_BIT |
            c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        c.VK_IMAGE_ASPECT_COLOR_BIT,
        self.gpu_mem_props,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );
    self.depth_image = try resources.createImage(
        self.device,
        c.VK_FORMAT_D32_SFLOAT,
        draw_image_extent,
        c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
        c.VK_IMAGE_ASPECT_DEPTH_BIT,
        self.gpu_mem_props,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );

    try self.initCommands();
    try self.initSync();
    try self.initDescriptors();

    self.geometry_shader = try createShader(
        "assets/shaders/default.spv",
        self.arena,
        self.device,
        .{},
    );
    self.test_meshes, self.test_images = try loader.loadGltfMeshes(self.gpa, self.arena, "assets/avocado.glb", self.gpu_mem_props, self.imm_cmd);

    // var sampler_info = c.VkSamplerCreateInfo{
    //     .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
    //     .magFilter = c.VK_FILTER_NEAREST,
    //     .minFilter = c.VK_FILTER_NEAREST,
    // };
    //
    // _ = vk.createSampler(self.device, &sampler_info, null, &self.default_sampler_nearest);
    //
    // sampler_info.magFilter = c.VK_FILTER_LINEAR;
    // sampler_info.minFilter = c.VK_FILTER_LINEAR;
    // _ = vk.createSampler(self.device, &sampler_info, null, &self.default_sampler_linear);

    return self;
}

fn initCommands(self: *VulkanRenderer) !void {
    const command_pool_info = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = self.graphics_queue_family,
    };
    for (self.frames) |*frame| {
        try vk.check(vk.createCommandPool(
            self.device,
            &command_pool_info,
            null,
            &frame.command_pool,
        ));

        try vk.check(vk.allocateCommandBuffers(
            self.device,
            &c.VkCommandBufferAllocateInfo{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .commandPool = frame.command_pool,
                .commandBufferCount = 1,
                .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            },
            &frame.command_buffer,
        ));
    }

    try vk.check(vk.createCommandPool(
        self.device,
        &command_pool_info,
        null,
        &self.imm_command_pool,
    ));

    self.imm_cmd = ImmediateCommand{
        .device = self.device,
        .fence = undefined,
        .queue = self.graphics_queue,
        .cmd = undefined,
    };

    try vk.check(vk.allocateCommandBuffers(
        self.device,
        &c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = self.imm_command_pool,
            .commandBufferCount = 1,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        },
        &self.imm_cmd.cmd,
    ));
}

fn initDescriptors(_: *VulkanRenderer) !void {}

fn initSync(self: *VulkanRenderer) !void {
    const fence_create_info = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };

    const sempahore_create_info = c.VkSemaphoreCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };

    for (self.frames) |*frame| {
        try vk.check(vk.createFence(self.device, &fence_create_info, null, &frame.render_fence));
        try vk.check(vk.createSemaphore(self.device, &sempahore_create_info, null, &frame.swapchain_semaphore));
        try vk.check(vk.createSemaphore(self.device, &sempahore_create_info, null, &frame.render_semaphore));
    }

    try vk.check(vk.createFence(self.device, &fence_create_info, null, &self.imm_cmd.fence));
}

var rotation: math.Quat = math.Quat.identity();

pub fn render(self: *VulkanRenderer) !void {
    const frame = self.frames[self.frame_number];
    const timeout = 1 * std.time.ns_per_s;

    try vk.check(vk.waitForFences(self.device, 1, &frame.render_fence, c.VK_TRUE, timeout));
    try vk.check(vk.resetFences(self.device, 1, &frame.render_fence));

    var swapchain_image_index: u32 = undefined;
    try vk.check(vk.acquireNextImageKHR(
        self.device,
        self.swapchain,
        timeout,
        frame.swapchain_semaphore,
        null,
        &swapchain_image_index,
    ));

    self.draw_extent = .{
        .width = self.draw_image.extent.width,
        .height = self.draw_image.extent.height,
    };

    try vk.check(vk.resetCommandBuffer(frame.command_buffer, 0));
    try vk.check(vk.beginCommandBuffer(frame.command_buffer, &.{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    }));

    vkdraw.transitionImage(
        frame.command_buffer,
        self.draw_image.image,
        c.VK_IMAGE_LAYOUT_UNDEFINED,
        c.VK_IMAGE_LAYOUT_GENERAL,
    );

    vkdraw.transitionImage(
        frame.command_buffer,
        self.draw_image.image,
        c.VK_IMAGE_LAYOUT_GENERAL,
        c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    );

    const mesh = self.test_meshes[0];
    // const image = self.test_images[0];

    if (self.window.input.kb.getKeyDown(.a)) {
        const rot = math.Quat.euler(0, 5, 0);
        rotation = rotation.mul(rot).norm();
    } else if (self.window.input.kb.getKeyDown(.d)) {
        const rot = math.Quat.euler(0, -5, 0);
        rotation = rotation.mul(rot).norm();
    }

    if (self.window.input.kb.getKeyDown(.w)) {
        const rot = math.Quat.euler(5, 0, 0);
        rotation = rotation.mul(rot).norm();
    } else if (self.window.input.kb.getKeyDown(.s)) {
        const rot = math.Quat.euler(-5, 0, 0);
        rotation = rotation.mul(rot).norm();
    }

    const model = math.Mat4.transform(
        mesh.bounds.center.mulf(-1),
        rotation,
        math.Vec3.one().mulf(50),
    );

    const view = math.Mat4.lookAt(
        math.vec3(0, 0.0, -5.0),
        math.vec3(0, 0.0, 0.0),
        math.vec3(0, 1.0, 0.0),
    );

    const projection = math.Mat4.perspective(
        math.degToRad(60.0),
        @floatFromInt(self.draw_extent.width),
        @floatFromInt(self.draw_extent.height),
        0.3,
        100.0,
    );

    const push_constants = types.PushConstants{
        .world_matrix = projection.mul(view.mul(model)),
        .vertex_buffer = mesh.vb_addr,
    };

    vkdraw.graphics(
        frame.command_buffer,
        self.draw_extent,
        self.draw_image,
        self.depth_image,
        self.geometry_shader,
        push_constants,
        mesh.index_buffer,
    );

    vkdraw.transitionImage(
        frame.command_buffer,
        self.draw_image.image,
        c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    );

    const next_image = self.swapchain_images[swapchain_image_index];

    vkdraw.transitionImage(
        frame.command_buffer,
        next_image,
        c.VK_IMAGE_LAYOUT_UNDEFINED,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    );

    vkdraw.copyImageToImage(
        frame.command_buffer,
        self.draw_image.image,
        next_image,
        self.draw_extent,
        self.swapchain_extent,
    );

    vkdraw.transitionImage(
        frame.command_buffer,
        next_image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    );

    vkdraw.transitionImage(
        frame.command_buffer,
        next_image,
        c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    );

    try vk.check(vk.endCommandBuffer(frame.command_buffer));

    try vk.check(vk.queueSubmit2(self.graphics_queue, 1, &c.VkSubmitInfo2{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO_2,
        .waitSemaphoreInfoCount = 1,
        .pWaitSemaphoreInfos = &c.VkSemaphoreSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
            .semaphore = frame.swapchain_semaphore,
            .stageMask = c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
            .deviceIndex = 0,
            .value = 1,
        },
        .signalSemaphoreInfoCount = 1,
        .pSignalSemaphoreInfos = &c.VkSemaphoreSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
            .semaphore = frame.render_semaphore,
            .stageMask = c.VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT,
            .deviceIndex = 0,
            .value = 1,
        },
        .commandBufferInfoCount = 1,
        .pCommandBufferInfos = &c.VkCommandBufferSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
            .commandBuffer = frame.command_buffer,
        },
    }, frame.render_fence));

    try vk.check(vk.queuePresentKHR(self.graphics_queue, &.{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pSwapchains = &self.swapchain,
        .swapchainCount = 1,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &frame.render_semaphore,
        .pImageIndices = &swapchain_image_index,
    }));

    self.frame_number = (self.frame_number + 1) % self.max_frames_in_flight;
}
