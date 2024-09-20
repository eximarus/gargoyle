const std = @import("std");
const config = @import("config");
const c = @import("c");
const platform = @import("platform");

const vk = @import("vulkan.zig");
const vkinit = @import("vkinit.zig");
const vkdraw = @import("vkdraw.zig");
const common = @import("common.zig");
const descriptors = @import("descriptors.zig");
const pipelines = @import("pipelines.zig");
const math = @import("../../math/math.zig");
const types = @import("types.zig");
const loader = @import("loader.zig");

const Config = @import("../../core/AppConfig.zig").RenderConfig;
const Swapchain = @import("Swapchain.zig");
const inst = @import("instance.zig");
const PhysicalDevice = @import("PhysicalDevice.zig");

const CString = common.CString;
const Window = platform.Window;

const required_device_extensions: []const CString = &.{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    c.VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
    c.VK_KHR_SYNCHRONIZATION_2_EXTENSION_NAME,
    c.VK_KHR_COPY_COMMANDS_2_EXTENSION_NAME,
    c.VK_EXT_SHADER_OBJECT_EXTENSION_NAME,
    c.VK_EXT_MESH_SHADER_EXTENSION_NAME,
};

const optional_device_extensions: []const CString = &.{
    // these dont work in wsl
    // ray tracing
    c.VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    c.VK_KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME,
    // required for VK_KHR_acceleration_structure
    c.VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
};

const VulkanRenderer = @This();

const Frame = struct {
    command_pool: vk.CommandPool,
    command_buffer: vk.CommandBuffer,
    render_fence: vk.Fence,
    swapchain_semaphore: vk.Semaphore,
    render_semaphore: vk.Semaphore,
};

gpa: std.mem.Allocator,
arena: std.mem.Allocator,

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
frames: []Frame,
frame_overlap: usize = 2,

global_descriptor_pool: vk.DescriptorPool,

depth_image: types.Image,
draw_image: types.Image,
draw_extent: c.VkExtent2D,
draw_image_descriptors: vk.DescriptorSet,
draw_image_descriptor_layout: vk.DescriptorSetLayout,

imm_fence: vk.Fence,
imm_command_buffer: vk.CommandBuffer,
imm_command_pool: vk.CommandPool,

mesh_pipeline_layout: vk.PipelineLayout,
mesh_pipeline: vk.Pipeline,
test_meshes: []types.Mesh,

pub fn init(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    window: Window,
    options: Config,
) !VulkanRenderer {
    try vk.check(vk.init());

    var self: VulkanRenderer = undefined;
    self.gpa = gpa;
    self.arena = arena;
    self.frame_number = 0;
    self.graphics_queue_family = null;
    self.frame_overlap = if (options.tripple_buffering) 3 else 2;
    self.frames = try gpa.alloc(Frame, self.frame_overlap);

    const instance, const debug_messenger, _ = try inst.create(arena, &.{
        .app_name = "gargoyle_app",
        .request_validation_layers = true,
        .required_api_ver = c.VK_MAKE_VERSION(1, 2, 197),
        .extensions = &.{ platform.vk.surface_ext, "VK_KHR_surface" },
        .use_debug_messenger = true,
    });
    self.instance = instance;
    self.debug_messenger = debug_messenger;

    const result, const surface = platform.vk.createSurface(window, self.instance.handle());
    try vk.check(vk.result(result));

    self.surface = @ptrCast(surface);
    try self.createVkDevice();
    self.graphics_queue = try self.device.getQueue(self.graphics_queue_family.?, 0);

    self.swapchain_images = std.ArrayList(vk.Image).init(gpa);
    self.swapchain_image_views = std.ArrayList(vk.ImageView).init(gpa);
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

    self.draw_image.image = try self.device.createImage(
        &vkinit.imageCreateInfo(
            self.draw_image.image_format,
            draw_image_usages,
            draw_image_extent,
        ),
        null,
    );

    const req = self.device.getImageMemoryRequirements(self.draw_image.image);

    self.draw_image.memory = try self.device.allocateMemory(&c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = req.size,
        .memoryTypeIndex = try self.findMemoryType(
            req.memoryTypeBits,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ),
    }, null);

    try self.device.bindImageMemory(self.draw_image.image, self.draw_image.memory, 0);

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

    self.depth_image.image = try self.device.createImage(
        &vkinit.imageCreateInfo(
            self.depth_image.image_format,
            depth_image_usages,
            draw_image_extent,
        ),
        null,
    );

    const depth_req = self.device.getImageMemoryRequirements(self.depth_image.image);

    self.depth_image.memory = try self.device.allocateMemory(&c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = req.size,
        .memoryTypeIndex = try self.findMemoryType(
            depth_req.memoryTypeBits,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ),
    }, null);

    try self.device.bindImageMemory(self.depth_image.image, self.depth_image.memory, 0);

    self.depth_image.image_view = try self.device.createImageView(
        &vkinit.imageViewCreateInfo(
            self.depth_image.image_format,
            self.depth_image.image,
            c.VK_IMAGE_ASPECT_DEPTH_BIT,
        ),
        null,
    );

    try self.initCommands();
    try self.initSync();
    try self.initDescriptors();
    try self.initPipelines();

    try self.initDefaultData();
    return self;
}

fn initDefaultData(self: *VulkanRenderer) !void {
    self.test_meshes = try self.gpa.alloc(types.Mesh, 1);
    self.test_meshes[0] = try self.uploadMesh(
        &.{ 3, 1, 0, 3, 2, 1 },
        &.{
            types.Vertex{
                .position = .{ .x = 0.5, .y = 0.5, .z = 0 },
                .color = .{ .r = 1, .g = 0, .b = 0, .a = 1 },
            },
            types.Vertex{
                .position = .{ .x = 0.5, .y = -0.5, .z = 0 },
                .color = .{ .r = 0, .g = 1, .b = 0, .a = 1 },
            },

            types.Vertex{
                .position = .{ .x = -0.5, .y = -0.5, .z = 0 },
                .color = .{ .r = 0, .g = 0, .b = 1, .a = 1 },
            },

            types.Vertex{
                .position = .{ .x = -0.5, .y = 0.5, .z = 0 },
                .color = .{ .r = 1, .g = 0, .b = 0, .a = 1 },
            },
        },
    );
    // self.test_meshes = try loader.loadGltfMeshes(self, "basicmesh.glb");
}

fn createVkDevice(self: *VulkanRenderer) !void {
    const gpus = try self.instance.enumeratePhysicalDevices(self.arena);
    for (gpus) |gpu| {
        self.gpu = gpu;
        const queue_family_properties =
            try gpu.getQueueFamilyProperties(self.arena);
        for (queue_family_properties, 0..) |prop, i| {
            const index: u32 = @intCast(i);
            const supports_present =
                try gpu.getSurfaceSupportKHR(index, self.surface);
            const graphics_bit = prop.queueFlags &
                c.VK_QUEUE_GRAPHICS_BIT != 0;
            if (graphics_bit and supports_present) {
                self.graphics_queue_family = index;

                // var rt_props = c.VkPhysicalDeviceRayTracingPipelinePropertiesKHR{
                //     .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR,
                // };
                //
                // var accel_props = c.VkPhysicalDeviceAccelerationStructurePropertiesKHR{
                //     .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR,
                //     .pNext = &rt_props,
                // };

                if (gpu.getProperties2(null).deviceType ==
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
        try self.gpu.enumerateDeviceExtensionProperties(self.arena);

    try common.validateExtensions(device_extensions, required_device_extensions);
    var features11 = c.VkPhysicalDeviceVulkan11Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
    };

    var features12 = c.VkPhysicalDeviceVulkan12Features{
        .pNext = &features11,
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        .bufferDeviceAddress = c.VK_TRUE,
        .descriptorIndexing = c.VK_TRUE,
    };

    var shader_obj = c.VkPhysicalDeviceShaderObjectFeaturesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT,
        .pNext = &features12,
        .shaderObject = c.VK_TRUE,
    };

    var synchronization2 = c.VkPhysicalDeviceSynchronization2FeaturesKHR{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES_KHR,
        .pNext = &shader_obj,
        .synchronization2 = c.VK_TRUE,
    };

    var mesh_shader = c.VkPhysicalDeviceMeshShaderFeaturesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT,
        .pNext = &synchronization2,
        .meshShader = c.VK_TRUE,
        .taskShader = c.VK_TRUE,
    };

    var dynamic_rendering = c.VkPhysicalDeviceDynamicRenderingFeaturesKHR{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES_KHR,
        .pNext = &mesh_shader,
        .dynamicRendering = c.VK_TRUE,
    };

    var queue_priority: f32 = 1.0;
    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &dynamic_rendering,
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

inline fn getCurrentFrame(self: *VulkanRenderer) *Frame {
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

fn createBuffer(
    self: *VulkanRenderer,
    alloc_size: usize,
    usage: c.VkBufferUsageFlags,
    memory_properties: c.VkMemoryPropertyFlags,
    next: ?*anyopaque,
) !types.Buffer {
    var new_buffer: types.Buffer = undefined;
    new_buffer.size = alloc_size;

    new_buffer.buffer = try self.device.createBuffer(
        &c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = @intCast(alloc_size),
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        },
        null,
    );

    const req = self.device.getBufferMemoryRequirements(new_buffer.buffer);

    new_buffer.memory = try self.device.allocateMemory(&c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = next,
        .allocationSize = req.size,
        .memoryTypeIndex = try self.findMemoryType(
            req.memoryTypeBits,
            memory_properties,
        ),
    }, null);

    try self.device.bindBufferMemory(new_buffer.buffer, new_buffer.memory, 0);
    return new_buffer;
}

fn findMemoryType(self: *VulkanRenderer, type_filter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    const mem_props = self.gpu.getMemoryProperties();

    for (0..mem_props.memoryTypeCount) |i| {
        if (type_filter & (@as(u32, 1) << @intCast(i)) != 0 and (mem_props.memoryTypes[i].propertyFlags & properties) == properties) {
            return @intCast(i);
        }
    }

    return error.SuitableMemoryTypeNotFound;
}

pub fn render(self: *VulkanRenderer, app: anytype) !void {
    _ = app;
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
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        @constCast(&c.VkMemoryAllocateFlagsInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO,
            .flags = c.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT,
        }),
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
    var data: [*]u8 = @ptrCast(try self.device.mapMemory(staging.memory, 0, vb_size + ib_size, 0));
    @memcpy(data, std.mem.sliceAsBytes(vertices));
    @memcpy(data[vb_size..], std.mem.sliceAsBytes(indices));
    self.device.unmapMemory(staging.memory);

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

    self.device.destroyBuffer(staging.buffer, null);
    self.device.freeMemory(staging.memory, null);

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

    self.device.destroyDescriptorSetLayout(self.draw_image_descriptor_layout, null);
    self.device.destroyDescriptorPool(self.global_descriptor_pool, null);

    self.device.destroyPipelineLayout(self.mesh_pipeline_layout, null);
    self.device.destroyPipeline(self.mesh_pipeline, null);

    self.device.destroyImageView(self.draw_image.image_view, null);
    self.device.destroyImage(self.draw_image.image, null);
    self.device.freeMemory(self.draw_image.memory, null);

    self.device.destroyImageView(self.depth_image.image_view, null);
    self.device.destroyImage(self.depth_image.image, null);
    self.device.freeMemory(self.depth_image.memory, null);

    for (self.test_meshes) |mesh_asset| {
        self.device.destroyBuffer(mesh_asset.index_buffer.buffer, null);
        self.device.freeMemory(mesh_asset.index_buffer.memory, null);

        self.device.destroyBuffer(mesh_asset.vertex_buffer.buffer, null);
        self.device.freeMemory(mesh_asset.vertex_buffer.memory, null);
    }
    self.gpa.free(self.test_meshes);

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
    self.device.destroy(null);
    self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, null) catch {};
    self.instance.destroy(null);

    self.gpa.free(self.frames);
}
