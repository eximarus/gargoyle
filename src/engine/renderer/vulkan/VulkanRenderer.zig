const std = @import("std");
const config = @import("config");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");
const vkinit = @import("vkinit.zig");
const vkdraw = @import("vkdraw.zig");
const vma = @import("vma.zig");
const imgui = @import("imgui.zig");
const common = @import("common.zig");
const descriptors = @import("descriptors.zig");
const pipelines = @import("pipelines.zig");
const math = @import("../../math/math.zig");
const types = @import("types.zig");
const loader = @import("loader.zig");

const Config = @import("../../core/app_config.zig").RenderConfig;
const CString = common.CString;
const Window = @import("../../core/window.zig").Window;
const Swapchain = @import("Swapchain.zig");
const Instance = @import("Instance.zig");
const PhysicalDevice = @import("PhysicalDevice.zig");
const App = @import("../../core/app_types.zig").App;

const VulkanRenderer = @This();

const FrameData = struct {
    command_pool: vk.CommandPool,
    command_buffer: vk.CommandBuffer,
    swapchain_semaphore: vk.Semaphore,
    render_semaphore: vk.Semaphore,
    render_fence: vk.Fence,
};

pub const ComputePushConstants = struct {
    data1: math.Vec4,
    data2: math.Vec4,
    data3: math.Vec4,
    data4: math.Vec4,
};

const ComputeEffect = struct {
    name: CString,
    pipeline: vk.Pipeline,
    layout: vk.PipelineLayout,
    data: ComputePushConstants,
};

allocator: std.mem.Allocator,

instance: vk.Instance,
debug_messenger: vk.DebugUtilsMessengerEXT,
gpu: vk.PhysicalDevice,
device: vk.Device,
surface: vk.SurfaceKHR,

swapchain: vk.SwapchainKHR,
swapchain_image_format: c.VkFormat,
swapchain_extent: c.VkExtent2D,
swapchain_images: std.ArrayList(vk.Image),
swapchain_image_views: std.ArrayList(vk.ImageView),

graphics_queue_family: ?u32 = null,
graphics_queue: vk.Queue,

frame_number: usize = 0,
frames: []FrameData,
frame_overlap: usize = 2,

vma_allocator: vma.Allocator,

global_descriptor_pool: vk.DescriptorPool,

depth_image: types.Image,
draw_image: types.Image,
draw_extent: c.VkExtent2D,
draw_image_descriptors: vk.DescriptorSet,
draw_image_descriptor_layout: vk.DescriptorSetLayout,

gradient_pipeline_layout: vk.PipelineLayout,

imm_fence: vk.Fence,
imm_command_buffer: vk.CommandBuffer,
imm_command_pool: vk.CommandPool,

imm_descriptor_pool: vk.DescriptorPool,

background_effects: std.ArrayList(ComputeEffect),
current_background_effect: i32 = 0,

mesh_pipeline_layout: vk.PipelineLayout,
mesh_pipeline: vk.Pipeline,
test_meshes: []loader.MeshAssets,

pub fn init(
    allocator: std.mem.Allocator,
    window: Window,
    options: Config,
) !VulkanRenderer {
    var aa = std.heap.ArenaAllocator.init(allocator);
    defer aa.deinit();
    const arena = aa.allocator();

    const window_extensions = try window.getVulkanExtensions(arena);

    try vk.check(vk.init());

    var self: VulkanRenderer = undefined;
    self.allocator = allocator;
    self.frame_number = 0;
    self.graphics_queue_family = null;
    self.frame_overlap = if (options.tripple_buffering) 3 else 2;
    self.frames = try allocator.alloc(FrameData, self.frame_overlap);

    const bootstrap_inst = try Instance.init(arena, &.{
        .app_name = @ptrCast(config.app_name),
        .request_validation_layers = true,
        .required_api_ver = c.VK_MAKE_VERSION(1, 3, 0),
        .extensions = window_extensions,
    });
    self.instance = bootstrap_inst.instance;
    self.debug_messenger = bootstrap_inst.debug_messenger;

    self.surface = try window.createVulkanSurface(self.instance);
    try self.createVkDevice(arena);
    self.graphics_queue = try self.device.getQueue(self.graphics_queue_family.?, 0);

    self.swapchain_images = std.ArrayList(vk.Image).init(allocator);
    self.swapchain_image_views = std.ArrayList(vk.ImageView).init(allocator);
    self.swapchain_image_format = c.VK_FORMAT_B8G8R8A8_UNORM;

    const window_extent = window.getSize();
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
                .width = window_extent.width,
                .height = window_extent.height,
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

    self.vma_allocator = try vma.createAllocator(&.{
        .instance = self.instance.handle(),
        .physicalDevice = self.gpu.handle(),
        .device = self.device.handle(),
        .flags = c.VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT,
        .pVulkanFunctions = &vma.getVulkanFunctions(),
    });

    const draw_image_extent = c.VkExtent3D{
        .width = window_extent.width,
        .height = window_extent.height,
        .depth = 1,
    };

    self.draw_image.image_format = c.VK_FORMAT_R16G16B16A16_SFLOAT;
    self.draw_image.image_extent = draw_image_extent;
    const draw_image_usages =
        c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
        c.VK_IMAGE_USAGE_TRANSFER_DST_BIT |
        c.VK_IMAGE_USAGE_STORAGE_BIT |
        c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    self.draw_image.image, self.draw_image.allocation = try self.vma_allocator.createImage(
        &vkinit.imageCreateInfo(
            self.draw_image.image_format,
            draw_image_usages,
            draw_image_extent,
        ),
        &.{
            .usage = c.VMA_MEMORY_USAGE_GPU_ONLY,
            .requiredFlags = c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        },
        null,
    );

    self.draw_image.image_view = try self.device.createImageView(
        &vkinit.imageViewCreateInfo(
            self.draw_image.image_format,
            self.draw_image.image,
            c.VK_IMAGE_ASPECT_COLOR_BIT,
        ),
        null,
    );

    self.depth_image.image_format = c.VK_FORMAT_D32_SFLOAT;
    self.depth_image.image_extent = draw_image_extent;
    const depth_image_usages = c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;

    self.depth_image.image, self.depth_image.allocation = try self.vma_allocator.createImage(
        &vkinit.imageCreateInfo(
            self.depth_image.image_format,
            depth_image_usages,
            draw_image_extent,
        ),
        &.{
            .usage = c.VMA_MEMORY_USAGE_GPU_ONLY,
            .requiredFlags = c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        },
        null,
    );

    self.depth_image.image_view = try self.device.createImageView(
        &vkinit.imageViewCreateInfo(
            self.depth_image.image_format,
            self.depth_image.image,
            c.VK_IMAGE_ASPECT_DEPTH_BIT,
        ),
        null,
    );

    self.current_background_effect = 0;
    self.background_effects = std.ArrayList(ComputeEffect).init(allocator);

    try self.initCommands();
    try self.initSync();
    try self.initDescriptors();
    try self.initPipelines();
    try self.initImgui(window);

    try self.initDefaultData();
    return self;
}

fn initDefaultData(self: *VulkanRenderer) !void {
    self.test_meshes = try loader.loadGltfMeshes(self, "basicmesh.glb");
}

fn createVkDevice(self: *VulkanRenderer, arena: std.mem.Allocator) !void {
    const gpus = try self.instance.enumeratePhysicalDevices(arena);
    for (gpus) |gpu| {
        self.gpu = gpu;
        const queue_family_properties =
            try gpu.getQueueFamilyProperties(arena);
        for (queue_family_properties, 0..) |prop, i| {
            const index: u32 = @intCast(i);
            const supports_present =
                try gpu.getSurfaceSupportKHR(index, self.surface);
            const graphics_bit = prop.queueFlags &
                c.VK_QUEUE_GRAPHICS_BIT != 0;
            if (graphics_bit and supports_present) {
                self.graphics_queue_family = index;
                if (gpu.getProperties().deviceType ==
                    c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
                {
                    break;
                }
            }
        }
    }
    if (self.graphics_queue_family == null) {
        std.log.err("Did not find suitable queue which supports graphics, compute and presentation.\n", .{});
    }
    const device_extensions =
        try self.gpu.enumerateDeviceExtensionProperties(arena);
    const required_device_extensions: []const CString = &.{
        "VK_KHR_swapchain",
    };
    try common.validateExtensions(device_extensions, required_device_extensions);
    var features12 = c.VkPhysicalDeviceVulkan12Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        .bufferDeviceAddress = c.VK_TRUE,
        .descriptorIndexing = c.VK_TRUE,
    };
    var features13 = c.VkPhysicalDeviceVulkan13Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
        .pNext = &features12,
        .dynamicRendering = c.VK_TRUE,
        .synchronization2 = c.VK_TRUE,
    };
    var queue_priority: f32 = 1.0;
    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &features13,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = self.graphics_queue_family.?,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        },
        .enabledExtensionCount = @intCast(required_device_extensions.len),
        .ppEnabledExtensionNames = @ptrCast(required_device_extensions.ptr),
        .pEnabledFeatures = &.{},
    };
    self.device = try self.gpu.createDevice(&device_info, null);
}

inline fn getCurrentFrame(self: *VulkanRenderer) *FrameData {
    return &self.frames[@rem(self.frame_number, self.frame_overlap)];
}

fn initCommands(self: *VulkanRenderer) !void {
    const command_pool_info = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = self.graphics_queue_family.?,
    };
    for (self.frames) |*frame| {
        frame.command_pool = try self.device.createCommandPool(
            &command_pool_info,
            null,
        );

        frame.command_buffer = try self.device.allocateCommandBuffers(
            &vkinit.commandBufferAllocateInfo(frame.command_pool, 1),
        );
    }

    self.imm_command_pool = try self.device.createCommandPool(
        &command_pool_info,
        null,
    );
    self.imm_command_buffer = try self.device.allocateCommandBuffers(
        &vkinit.commandBufferAllocateInfo(self.imm_command_pool, 1),
    );
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

    self.device.updateDescriptorSets(&.{
        c.VkWriteDescriptorSet{
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
    }, &.{});
}

fn initPipelines(self: *VulkanRenderer) !void {
    self.gradient_pipeline_layout = try self.device.createPipelineLayout(&.{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pSetLayouts = &self.draw_image_descriptor_layout,
        .setLayoutCount = 1,

        .pPushConstantRanges = &[1]c.VkPushConstantRange{
            .{
                .offset = 0,
                .size = @sizeOf(ComputePushConstants),
                .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            },
        },
        .pushConstantRangeCount = 1,
    }, null);

    const gradient_shader = try pipelines.loadShaderModule(
        "shaders/glsl/gradient.comp",
        self.device,
    );
    defer self.device.destroyShaderModule(gradient_shader, null);

    var compute_pipeline_create_info =
        c.VkComputePipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .layout = self.gradient_pipeline_layout,
        .stage = c.VkPipelineShaderStageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .module = gradient_shader,
            .pName = "main",
        },
    };

    const gradient = ComputeEffect{
        .layout = self.gradient_pipeline_layout,
        .name = "gradient",
        .data = .{
            .data1 = math.vec4(1, 0, 0, 1),
            .data2 = math.vec4(0, 0, 1, 1),
            .data3 = undefined,
            .data4 = undefined,
        },
        .pipeline = try self.device.createComputePipelines(
            null,
            &.{compute_pipeline_create_info},
            null,
        ),
    };

    const sky_shader = try pipelines.loadShaderModule("shaders/glsl/sky.comp", self.device);
    defer self.device.destroyShaderModule(sky_shader, null);
    compute_pipeline_create_info.stage.module = sky_shader;

    const sky = ComputeEffect{
        .layout = self.gradient_pipeline_layout,
        .name = "sky",
        .data = .{
            .data1 = math.vec4(0.1, 0.2, 0.4, 0.97),
            .data2 = undefined,
            .data3 = undefined,
            .data4 = undefined,
        },
        .pipeline = try self.device.createComputePipelines(
            null,
            &.{compute_pipeline_create_info},
            null,
        ),
    };

    try self.background_effects.append(gradient);
    try self.background_effects.append(sky);

    const triangle_frag_shader = try pipelines.loadShaderModule(
        "shaders/glsl/colored_triangle.frag",
        self.device,
    );
    defer self.device.destroyShaderModule(triangle_frag_shader, null);

    const triangle_vertex_shader = try pipelines.loadShaderModule(
        "shaders/glsl/colored_triangle.vert",
        self.device,
    );
    defer self.device.destroyShaderModule(triangle_vertex_shader, null);

    var pipline_layout_info = vkinit.pipelineLayoutCreateInfo();
    pipline_layout_info.pushConstantRangeCount = 1;
    pipline_layout_info.pPushConstantRanges = &c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(types.DrawPushConstants),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };

    self.mesh_pipeline_layout = try self.device.createPipelineLayout(&pipline_layout_info, null);

    self.mesh_pipeline = try pipelines.pipeline(self.device, &.{
        .shaders = .{
            .vertex_shader = triangle_vertex_shader,
            .fragment_shader = triangle_frag_shader,
        },
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
        frame.render_fence = try self.device.createFence(&fence_create_info, null);
        frame.swapchain_semaphore = try self.device.createSemaphore(&sempahore_create_info, null);
        frame.render_semaphore = try self.device.createSemaphore(&sempahore_create_info, null);
    }

    self.imm_fence = try self.device.createFence(&fence_create_info, null);
}

fn initImgui(self: *VulkanRenderer, window: Window) !void {
    const pool_sizes = [_]c.VkDescriptorPoolSize{
        .{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC, .descriptorCount = 1000 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, .descriptorCount = 1000 },
    };

    self.imm_descriptor_pool = try self.device.createDescriptorPool(&.{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
        .maxSets = 1000,
        .poolSizeCount = pool_sizes.len,
        .pPoolSizes = &pool_sizes,
    }, null);

    _ = c.igCreateContext(null);

    _ = c.ImGui_ImplSDL2_InitForVulkan(window._sdl_window);

    _ = imgui.ImGui_ImplVulkan_Init(&.{
        .instance = self.instance.handle(),
        .physical_device = self.gpu.handle(),
        .device = self.device.handle(),
        .queue = self.graphics_queue.handle(),
        .descriptor_pool = self.imm_descriptor_pool,
        .min_image_count = 3,
        .image_count = 3,
        .msaa_samples = c.VK_SAMPLE_COUNT_1_BIT,
        .use_dynamic_rendering = true,
        .pipeline_rendering_create_info = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &[1]c.VkFormat{self.swapchain_image_format},
        },
    });

    _ = imgui.ImGui_ImplVulkan_CreateFontsTexture();
}

fn createBuffer(
    self: *VulkanRenderer,
    alloc_size: usize,
    usage: c.VkBufferUsageFlags,
    memory_usage: c.VmaMemoryUsage,
) !types.Buffer {
    var new_buffer: types.Buffer = undefined;
    new_buffer.buffer, new_buffer.allocation = try self.vma_allocator.createBuffer(
        &c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = @intCast(alloc_size),
            .usage = usage,
        },
        &c.VmaAllocationCreateInfo{
            .usage = memory_usage,
            .flags = c.VMA_ALLOCATION_CREATE_MAPPED_BIT,
        },
        &new_buffer.info,
    );
    return new_buffer;
}

pub fn render(self: *VulkanRenderer, app: *App) !void {
    imgui.ImGui_ImplVulkan_NewFrame();
    c.ImGui_ImplSDL2_NewFrame();
    c.igNewFrame();

    if (c.igBegin("Background", null, 0)) {
        var selected = &self.background_effects.items[
            @intCast(self.current_background_effect)
        ];
        c.igText("Selected effect: ", selected.name);

        _ = c.igSliderInt(
            "Effect Index",
            &self.current_background_effect,
            0,
            @intCast(self.background_effects.items.len - 1),
            null,
            0,
        );

        _ = c.igInputFloat4("data1", @ptrCast(&selected.data.data1), null, 0);
        _ = c.igInputFloat4("data2", @ptrCast(&selected.data.data2), null, 0);
        _ = c.igInputFloat4("data3", @ptrCast(&selected.data.data3), null, 0);
        _ = c.igInputFloat4("data4", @ptrCast(&selected.data.data4), null, 0);

        c.igEnd();
    }
    _ = app.onGui();

    c.igRender();

    const frame = self.getCurrentFrame();
    const timeout = 1 * std.time.ns_per_s;

    try vk.check(self.device.waitForFences(&.{frame.render_fence}, true, timeout));
    try vk.check(self.device.resetFences(&.{frame.render_fence}));

    const swapchain_image_index = try self.device.acquireNextImageKHR(
        self.swapchain,
        timeout,
        frame.swapchain_semaphore,
        null,
    );

    self.draw_extent = .{
        .width = self.draw_image.image_extent.width,
        .height = self.draw_image.image_extent.height,
    };

    try vk.check(frame.command_buffer.reset(0));
    try vk.check(frame.command_buffer.begin(&.{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    }));

    vkdraw.transitionImage(
        frame.command_buffer,
        self.draw_image.image,
        c.VK_IMAGE_LAYOUT_UNDEFINED,
        c.VK_IMAGE_LAYOUT_GENERAL,
    );

    vkdraw.background(
        self,
        frame.command_buffer,
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

    vkdraw.gui(
        frame.command_buffer,
        self.swapchain_image_views.items[swapchain_image_index],
        self.swapchain_extent,
    );

    vkdraw.transitionImage(
        frame.command_buffer,
        next_image,
        c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    );

    try vk.check(frame.command_buffer.end());

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
    try vk.check(self.graphics_queue.submit2(&.{submit}, frame.render_fence));

    try vk.check(self.graphics_queue.presentKHR(&.{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pSwapchains = &self.swapchain,
        .swapchainCount = 1,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &frame.render_semaphore,
        .pImageIndices = &swapchain_image_index,
    }));

    self.frame_number += 1;
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
        c.VMA_MEMORY_USAGE_GPU_ONLY,
    );
    mesh.vb_addr = self.device.getBufferDeviceAddress(
        &c.VkBufferDeviceAddressInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            .buffer = mesh.vertex_buffer.buffer,
        },
    );
    mesh.index_buffer = try self.createBuffer(
        ib_size,
        c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        c.VMA_MEMORY_USAGE_GPU_ONLY,
    );

    const staging = try self.createBuffer(
        vb_size + ib_size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VMA_MEMORY_USAGE_CPU_ONLY,
    );

    var data: [*]u8 = @ptrCast(try self.vma_allocator.mapMemory(staging.allocation));
    @memcpy(data, std.mem.sliceAsBytes(vertices));
    @memcpy(data[vb_size..], std.mem.sliceAsBytes(indices));
    self.vma_allocator.unmapMemory(staging.allocation);

    try self.immediateSubmit(struct {
        vertex_buffer: vk.Buffer,
        vb_size: usize,
        index_buffer: vk.Buffer,
        ib_size: usize,
        staging_buffer: vk.Buffer,

        pub fn submit(this: @This(), cmd: vk.CommandBuffer) void {
            const vertex_copy = c.VkBufferCopy{
                .dstOffset = 0,
                .srcOffset = 0,
                .size = this.vb_size,
            };

            cmd.copyBuffer(this.staging_buffer, this.vertex_buffer, &.{vertex_copy});

            const index_copy = c.VkBufferCopy{
                .dstOffset = 0,
                .srcOffset = this.vb_size,
                .size = this.ib_size,
            };

            cmd.copyBuffer(this.staging_buffer, this.index_buffer, &.{index_copy});
        }
    }{
        .vertex_buffer = mesh.vertex_buffer.buffer,
        .vb_size = vb_size,
        .index_buffer = mesh.index_buffer.buffer,
        .ib_size = ib_size,
        .staging_buffer = staging.buffer,
    });

    self.vma_allocator.destroyBuffer(staging.buffer, staging.allocation);

    return mesh;
}

fn immediateSubmit(self: *VulkanRenderer, context: anytype) !void {
    try vk.check(self.device.resetFences(&.{self.imm_fence}));
    try vk.check(self.imm_command_buffer.reset(0));

    const cmd = self.imm_command_buffer;

    try vk.check(cmd.begin(&vkinit.commandBufferBeginInfo(
        c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    )));

    const ctx_type = @TypeOf(context);
    if (!@hasDecl(ctx_type, "submit")) {
        @compileError("context should have a submit method");
    }

    if (@TypeOf(@field(ctx_type, "submit")) != fn (ctx_type, vk.CommandBuffer) void) {
        @compileError("context submit has wrong signature. expected: submit(self: @This(), cmd: vk.CommandBuffer) void");
    }

    context.submit(cmd);

    try vk.check(cmd.end());

    const submit = vkinit.submitInfo(
        &.{vkinit.commandBufferSubmitInfo(cmd)},
        &.{},
        &.{},
    );

    try vk.check(self.graphics_queue.submit2(&.{submit}, self.imm_fence));
    try vk.check(self.device.waitForFences(&.{self.imm_fence}, true, 9999999999));
}

pub fn onWindowResize(self: *VulkanRenderer, width: u32, height: u32) void {
    _ = self;
    _ = width;
    _ = height;
}

fn destroySwapchain(self: *VulkanRenderer) void {
    self.device.destroySwapchainKHR(self.swapchain, null);
    for (self.swapchain_image_views.items) |image_view| {
        self.device.destroyImageView(image_view, null);
    }
    self.swapchain_image_views.deinit();
    self.swapchain_images.deinit();
}

pub fn deinit(self: *VulkanRenderer) void {
    _ = self.device.waitIdle() catch {};

    imgui.ImGui_ImplVulkan_Shutdown();
    self.device.destroyDescriptorPool(self.imm_descriptor_pool, null);

    self.device.destroyDescriptorSetLayout(self.draw_image_descriptor_layout, null);
    self.device.destroyDescriptorPool(self.global_descriptor_pool, null);

    self.device.destroyPipelineLayout(self.mesh_pipeline_layout, null);
    self.device.destroyPipeline(self.mesh_pipeline, null);

    self.device.destroyPipelineLayout(self.gradient_pipeline_layout, null);
    for (self.background_effects.items) |*effect| {
        self.device.destroyPipeline(effect.pipeline, null);
    }
    self.background_effects.deinit();

    self.device.destroyImageView(self.draw_image.image_view, null);
    self.vma_allocator.destroyImage(
        self.draw_image.image,
        self.draw_image.allocation,
    );

    self.device.destroyImageView(self.depth_image.image_view, null);
    self.vma_allocator.destroyImage(
        self.depth_image.image,
        self.depth_image.allocation,
    );

    for (self.test_meshes) |mesh_asset| {
        self.vma_allocator.destroyBuffer(
            mesh_asset.mesh.index_buffer.buffer,
            mesh_asset.mesh.index_buffer.allocation,
        );
        self.vma_allocator.destroyBuffer(
            mesh_asset.mesh.vertex_buffer.buffer,
            mesh_asset.mesh.vertex_buffer.allocation,
        );
        self.allocator.free(mesh_asset.surfaces);
    }
    self.allocator.free(self.test_meshes);

    self.device.destroyFence(self.imm_fence, null);

    self.device.destroyCommandPool(self.imm_command_pool, null);
    for (self.frames) |*frame| {
        self.device.destroyCommandPool(frame.command_pool, null);
        self.device.destroyFence(frame.render_fence, null);
        self.device.destroySemaphore(frame.render_semaphore, null);
        self.device.destroySemaphore(frame.swapchain_semaphore, null);
    }

    self.destroySwapchain();
    self.instance.destroySurfaceKHR(self.surface, null);
    self.vma_allocator.destroy();
    self.device.destroy(null);
    self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, null) catch {};
    self.instance.destroy(null);

    self.allocator.free(self.frames);
}
