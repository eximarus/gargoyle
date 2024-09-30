const std = @import("std");
const c = @import("c");
const platform = @import("platform");
const core = @import("../../root.zig");
const math = core.math;

const vk = @import("vulkan.zig");
const vkinit = @import("vkinit.zig");
const vkdraw = @import("vkdraw.zig");
const descriptors = @import("descriptors.zig");
const pipelines = @import("pipelines.zig");
const types = @import("types.zig");
const loader = @import("loader.zig");

const Options = @import("../Options.zig");
const Swapchain = @import("Swapchain.zig");
const PhysicalDevice = @import("PhysicalDevice.zig");

const createInstance = @import("instance.zig").create;
const createDevice = @import("device.zig").create;

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
device: c.VkDevice,
surface: c.VkSurfaceKHR,

swapchain: c.VkSwapchainKHR,
swapchain_image_format: c.VkFormat,
swapchain_extent: c.VkExtent2D,
swapchain_images: std.ArrayList(c.VkImage),
swapchain_image_views: std.ArrayList(c.VkImageView),

graphics_queue_family: u32,
graphics_queue: c.VkQueue,

frame_number: usize = 0,
frames: []Frame,
max_frames_in_flight: usize = 2,

global_descriptor_pool: c.VkDescriptorPool,

depth_image: types.Image,
draw_image: types.Image,
draw_extent: c.VkExtent2D,
draw_image_descriptors: c.VkDescriptorSet,
draw_image_descriptor_layout: c.VkDescriptorSetLayout,

imm_fence: c.VkFence,
imm_command_buffer: c.VkCommandBuffer,
imm_command_pool: c.VkCommandPool,

mesh_pipeline_layout: c.VkPipelineLayout,
mesh_pipeline: c.VkPipeline,
test_meshes: []types.Mesh,

pub fn init(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    window: Window,
    options: Options,
) !VulkanRenderer {
    vk.init();

    var self: VulkanRenderer = undefined;
    self.gpa = gpa;
    self.arena = arena;
    self.frame_number = 0;
    self.max_frames_in_flight = if (options.tripple_buffering) 3 else 2;
    self.frames = try gpa.alloc(Frame, self.max_frames_in_flight);

    self.instance, self.debug_messenger = try createInstance(arena);

    const result, const surface = platform.vk.createSurface(window, self.instance);
    try vk.check(result);

    self.surface = @ptrCast(surface);
    self.gpu, self.graphics_queue_family, self.device = try createDevice(self.instance, self.surface, arena);
    vk.getDeviceQueue(self.device, self.graphics_queue_family, 0, &self.graphics_queue);

    self.swapchain_images = std.ArrayList(c.VkImage).init(gpa);
    self.swapchain_image_views = std.ArrayList(c.VkImageView).init(gpa);
    self.swapchain_image_format = c.VK_FORMAT_B8G8R8A8_UNORM;

    const bootstrap_swapchain = try Swapchain.init(
        arena,
        self.gpu,
        self.device,
        self.surface,
        &.{
            .desired_formats = &.{
                c.VkSurfaceFormatKHR{
                    .format = self.swapchain_image_format,
                    .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
                },
            },
            .desired_present_modes = &.{
                if (options.vsync)
                    c.VK_PRESENT_MODE_FIFO_KHR
                else
                    c.VK_PRESENT_MODE_IMMEDIATE_KHR,
            },
            .desired_extent = .{
                .width = window.width,
                .height = window.height,
            },
            .image_usage_flags = c.VK_IMAGE_USAGE_TRANSFER_DST_BIT |
                c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        },
    );
    self.swapchain_extent = bootstrap_swapchain.extent;
    self.swapchain = bootstrap_swapchain.swapchain;
    try bootstrap_swapchain.getImagesBuffered(&self.swapchain_images);
    try bootstrap_swapchain.getImageViewsBuffered(
        self.swapchain_images.items,
        &self.swapchain_image_views,
        null,
    );

    const draw_image_extent = c.VkExtent3D{
        .width = window.width,
        .height = window.height,
        .depth = 1,
    };

    self.draw_image.image_format = c.VK_FORMAT_R16G16B16A16_SFLOAT;
    self.draw_image.image_extent = draw_image_extent;
    const draw_image_usages =
        c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
        c.VK_IMAGE_USAGE_TRANSFER_DST_BIT |
        c.VK_IMAGE_USAGE_STORAGE_BIT |
        c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    try vk.check(vk.createImage(
        self.device,
        &vkinit.imageCreateInfo(
            self.draw_image.image_format,
            draw_image_usages,
            draw_image_extent,
        ),
        null,
        &self.draw_image.image,
    ));

    var req: c.VkMemoryRequirements = undefined;
    vk.getImageMemoryRequirements(self.device, self.draw_image.image, &req);

    try vk.check(vk.allocateMemory(self.device, &c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = req.size,
        .memoryTypeIndex = try self.findMemoryType(
            req.memoryTypeBits,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ),
    }, null, &self.draw_image.memory));

    try vk.check(vk.bindImageMemory(self.device, self.draw_image.image, self.draw_image.memory, 0));

    try vk.check(vk.createImageView(
        self.device,
        &vkinit.imageViewCreateInfo(
            self.draw_image.image_format,
            self.draw_image.image,
            c.VK_IMAGE_ASPECT_COLOR_BIT,
        ),
        null,
        &self.draw_image.image_view,
    ));

    self.depth_image.image_format = c.VK_FORMAT_D32_SFLOAT;
    self.depth_image.image_extent = draw_image_extent;

    const depth_image_usages = c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;

    try vk.check(vk.createImage(
        self.device,
        &vkinit.imageCreateInfo(
            self.depth_image.image_format,
            depth_image_usages,
            draw_image_extent,
        ),
        null,
        &self.depth_image.image,
    ));

    var depth_req: c.VkMemoryRequirements = undefined;
    vk.getImageMemoryRequirements(self.device, self.depth_image.image, &depth_req);

    try vk.check(vk.allocateMemory(
        self.device,
        &c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = req.size,
            .memoryTypeIndex = try self.findMemoryType(
                depth_req.memoryTypeBits,
                c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            ),
        },
        null,
        &self.depth_image.memory,
    ));

    try vk.check(vk.bindImageMemory(self.device, self.depth_image.image, self.depth_image.memory, 0));

    try vk.check(vk.createImageView(
        self.device,
        &vkinit.imageViewCreateInfo(
            self.depth_image.image_format,
            self.depth_image.image,
            c.VK_IMAGE_ASPECT_DEPTH_BIT,
        ),
        null,
        &self.depth_image.image_view,
    ));

    try self.initCommands();
    try self.initSync();
    try self.initDescriptors();
    try self.initPipelines();

    try self.initDefaultData();
    return self;
}

fn initDefaultData(self: *VulkanRenderer) !void {
    self.test_meshes = try loader.loadGltfMeshes(self, "assets/basicmesh.glb");
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
            &vkinit.commandBufferAllocateInfo(frame.command_pool, 1),
            &frame.command_buffer,
        ));
    }

    try vk.check(vk.createCommandPool(
        self.device,
        &command_pool_info,
        null,
        &self.imm_command_pool,
    ));
    try vk.check(vk.allocateCommandBuffers(
        self.device,
        &vkinit.commandBufferAllocateInfo(self.imm_command_pool, 1),
        &self.imm_command_buffer,
    ));
}

fn initDescriptors(self: *VulkanRenderer) !void {
    self.global_descriptor_pool = try descriptors.createPool(
        self.device,
        10,
        1,
        &.{
            .{ .desc_type = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, .ratio = 1 },
        },
    );

    self.draw_image_descriptor_layout = try descriptors.createLayout(
        self.device,
        c.VK_SHADER_STAGE_COMPUTE_BIT,
        null,
        0,
        @constCast(&[_]c.VkDescriptorSetLayoutBinding{
            descriptors.layoutBinding(
                0,
                c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            ),
        }),
    );

    self.draw_image_descriptors = try descriptors.allocate(
        self.global_descriptor_pool,
        self.device,
        self.draw_image_descriptor_layout,
    );

    vk.updateDescriptorSets(
        self.device,
        1,
        &c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstBinding = 0,
            .dstSet = self.draw_image_descriptors,
            .descriptorCount = 1,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .pImageInfo = &c.VkDescriptorImageInfo{
                .imageLayout = c.VK_IMAGE_LAYOUT_GENERAL,
                .imageView = self.draw_image.image_view,
            },
        },
        0,
        null,
    );
}

fn initPipelines(self: *VulkanRenderer) !void {
    const shader = try pipelines.loadShaderModule(
        "assets/shaders/default.spv",
        self.arena,
        self.device,
    );
    defer vk.destroyShaderModule(self.device, shader, null);

    var pipline_layout_info = vkinit.pipelineLayoutCreateInfo();
    pipline_layout_info.pushConstantRangeCount = 1;
    pipline_layout_info.pPushConstantRanges = &c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(types.DrawPushConstants),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };

    try vk.check(vk.createPipelineLayout(self.device, &pipline_layout_info, null, &self.mesh_pipeline_layout));

    self.mesh_pipeline = try pipelines.pipeline(self.device, &.{
        .shader_module = shader,
        .pipeline_layout = self.mesh_pipeline_layout,
        .input_topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .polygon_mode = c.VK_POLYGON_MODE_FILL,
        .cull_mode = .{
            .flags = c.VK_CULL_MODE_BACK_BIT,
            .front_face = c.VK_FRONT_FACE_CLOCKWISE,
        },
        .blending = .none,
        .depth_test = .{
            .depth_write_enable = true,
            .op = c.VK_COMPARE_OP_LESS,
        },
        .color_attachment_format = self.draw_image.image_format,
        .depth_format = self.depth_image.image_format,
    });
}

fn initSync(self: *VulkanRenderer) !void {
    const fence_create_info = vkinit.fenceCreateInfo(c.VK_FENCE_CREATE_SIGNALED_BIT);
    const sempahore_create_info = vkinit.semaphoreCreateInfo(0);

    for (self.frames) |*frame| {
        try vk.check(vk.createFence(self.device, &fence_create_info, null, &frame.render_fence));
        try vk.check(vk.createSemaphore(self.device, &sempahore_create_info, null, &frame.swapchain_semaphore));
        try vk.check(vk.createSemaphore(self.device, &sempahore_create_info, null, &frame.render_semaphore));
    }

    try vk.check(vk.createFence(self.device, &fence_create_info, null, &self.imm_fence));
}

fn createBuffer(
    self: *VulkanRenderer,
    alloc_size: usize,
    usage: c.VkBufferUsageFlags,
    memory_properties: c.VkMemoryPropertyFlags,
    next: ?*anyopaque,
) !types.Buffer {
    var new_buffer: types.Buffer = undefined;
    new_buffer.size = alloc_size;

    try vk.check(vk.createBuffer(
        self.device,
        &c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = @intCast(alloc_size),
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        },
        null,
        &new_buffer.buffer,
    ));

    var req: c.VkMemoryRequirements = undefined;
    vk.getBufferMemoryRequirements(self.device, new_buffer.buffer, &req);

    try vk.check(vk.allocateMemory(self.device, &c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = next,
        .allocationSize = req.size,
        .memoryTypeIndex = try self.findMemoryType(
            req.memoryTypeBits,
            memory_properties,
        ),
    }, null, &new_buffer.memory));

    try vk.check(vk.bindBufferMemory(self.device, new_buffer.buffer, new_buffer.memory, 0));
    return new_buffer;
}

fn findMemoryType(self: *VulkanRenderer, type_filter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    var mem_props: c.VkPhysicalDeviceMemoryProperties = undefined;
    vk.getPhysicalDeviceMemoryProperties(self.gpu, &mem_props);

    for (0..mem_props.memoryTypeCount) |i| {
        if (type_filter & (@as(u32, 1) << @intCast(i)) != 0 and (mem_props.memoryTypes[i].propertyFlags & properties) == properties) {
            return @intCast(i);
        }
    }

    return error.SuitableMemoryTypeNotFound;
}

pub fn render(self: *VulkanRenderer, app: anytype) !void {
    _ = app;
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
        .width = self.draw_image.image_extent.width,
        .height = self.draw_image.image_extent.height,
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

    vkdraw.geometry(self, frame.command_buffer);

    vkdraw.transitionImage(
        frame.command_buffer,
        self.draw_image.image,
        c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    );

    const next_image = self.swapchain_images.items[swapchain_image_index];

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

    const cmd_info = vkinit.commandBufferSubmitInfo(frame.command_buffer);
    const wait_info = vkinit.sempahoreSubmitInfo(
        frame.swapchain_semaphore,
        c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
    );

    const signal_info = vkinit.sempahoreSubmitInfo(
        frame.render_semaphore,
        c.VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT,
    );

    const submit = vkinit.submitInfo(&.{cmd_info}, &.{signal_info}, &.{wait_info});
    try vk.check(vk.queueSubmit2KHR(self.graphics_queue, 1, &submit, frame.render_fence));

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

pub fn uploadMesh(
    self: *VulkanRenderer,
    indices: []const u32,
    vertices: []const types.Vertex,
) !types.Mesh {
    const vb_size = vertices.len * @sizeOf(types.Vertex);
    const ib_size = indices.len * @sizeOf(u32);

    var mesh: types.Mesh = undefined;
    mesh.vertex_buffer = try self.createBuffer(
        vb_size,
        c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT |
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT |
            c.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        @constCast(&c.VkMemoryAllocateFlagsInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO,
            .flags = c.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT,
        }),
    );

    mesh.vb_addr = vk.getBufferDeviceAddress(
        self.device,
        &c.VkBufferDeviceAddressInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            .buffer = mesh.vertex_buffer.buffer,
        },
    );

    mesh.index_buffer = try self.createBuffer(
        ib_size,
        c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        null,
    );

    const staging = try self.createBuffer(
        vb_size + ib_size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        null,
    );

    // TODO allocate larger chunks of memory at once and use offsets
    var data: [*]u8 = undefined;
    try vk.check(vk.mapMemory(self.device, staging.memory, 0, vb_size + ib_size, 0, @ptrCast(&data)));
    @memcpy(data, std.mem.sliceAsBytes(vertices));
    @memcpy(data[vb_size..], std.mem.sliceAsBytes(indices));
    vk.unmapMemory(self.device, staging.memory);

    const Context = struct {
        vertex_buffer: c.VkBuffer,
        vb_size: usize,
        index_buffer: c.VkBuffer,
        ib_size: usize,
        staging_buffer: c.VkBuffer,

        pub fn submit(this: *@This(), cmd: c.VkCommandBuffer) void {
            const vertex_copy = c.VkBufferCopy{
                .dstOffset = 0,
                .srcOffset = 0,
                .size = this.vb_size,
            };

            vk.cmdCopyBuffer(cmd, this.staging_buffer, this.vertex_buffer, 1, &vertex_copy);

            const index_copy = c.VkBufferCopy{
                .dstOffset = 0,
                .srcOffset = this.vb_size,
                .size = this.ib_size,
            };

            vk.cmdCopyBuffer(cmd, this.staging_buffer, this.index_buffer, 1, &index_copy);
        }
    };

    var ctx = Context{
        .vertex_buffer = mesh.vertex_buffer.buffer,
        .vb_size = vb_size,
        .index_buffer = mesh.index_buffer.buffer,
        .ib_size = ib_size,
        .staging_buffer = staging.buffer,
    };

    try self.immediateSubmit(&ctx, @ptrCast(&Context.submit));

    vk.destroyBuffer(self.device, staging.buffer, null);
    vk.freeMemory(self.device, staging.memory, null);

    return mesh;
}

fn immediateSubmit(
    self: *VulkanRenderer,
    context: *anyopaque,
    submit: *const fn (self: *anyopaque, cmd: c.VkCommandBuffer) void,
) !void {
    try vk.check(vk.resetFences(self.device, 1, &self.imm_fence));
    try vk.check(vk.resetCommandBuffer(self.imm_command_buffer, 0));

    const cmd = self.imm_command_buffer;

    try vk.check(vk.beginCommandBuffer(cmd, &vkinit.commandBufferBeginInfo(
        c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    )));

    submit(context, cmd);

    try vk.check(vk.endCommandBuffer(cmd));

    const submit_info = vkinit.submitInfo(
        &.{vkinit.commandBufferSubmitInfo(cmd)},
        &.{},
        &.{},
    );

    try vk.check(vk.queueSubmit2KHR(self.graphics_queue, 1, &submit_info, self.imm_fence));
    try vk.check(vk.waitForFences(self.device, 1, &self.imm_fence, c.VK_TRUE, 9999999999));
}

pub fn deinit(self: *VulkanRenderer) void {
    _ = vk.deviceWaitIdle(self.device);

    vk.destroyDescriptorSetLayout(self.device, self.draw_image_descriptor_layout, null);
    vk.destroyDescriptorPool(self.device, self.global_descriptor_pool, null);

    vk.destroyPipelineLayout(self.device, self.mesh_pipeline_layout, null);
    vk.destroyPipeline(self.device, self.mesh_pipeline, null);

    vk.destroyImageView(self.device, self.draw_image.image_view, null);
    vk.destroyImage(self.device, self.draw_image.image, null);
    vk.freeMemory(self.device, self.draw_image.memory, null);

    vk.destroyImageView(self.device, self.depth_image.image_view, null);
    vk.destroyImage(self.device, self.depth_image.image, null);
    vk.freeMemory(self.device, self.depth_image.memory, null);

    for (self.test_meshes) |mesh_asset| {
        vk.destroyBuffer(self.device, mesh_asset.index_buffer.buffer, null);
        vk.freeMemory(self.device, mesh_asset.index_buffer.memory, null);

        vk.destroyBuffer(self.device, mesh_asset.vertex_buffer.buffer, null);
        vk.freeMemory(self.device, mesh_asset.vertex_buffer.memory, null);
    }

    vk.destroyFence(self.device, self.imm_fence, null);

    vk.destroyCommandPool(self.device, self.imm_command_pool, null);
    for (self.frames) |*frame| {
        vk.destroyCommandPool(self.device, frame.command_pool, null);
        vk.destroyFence(self.device, frame.render_fence, null);
        vk.destroySemaphore(self.device, frame.render_semaphore, null);
        vk.destroySemaphore(self.device, frame.swapchain_semaphore, null);
    }

    vk.destroySwapchainKHR(self.device, self.swapchain, null);
    for (self.swapchain_image_views.items) |image_view| {
        vk.destroyImageView(self.device, image_view, null);
    }
    vk.destroySurfaceKHR(self.instance, self.surface, null);
    vk.destroyDevice(self.device, null);
    vk.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messenger, null);
    vk.destroyInstance(self.instance, null);
}
