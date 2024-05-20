const std = @import("std");
const config = @import("config");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");
const vma = @import("vma.zig");
const common = @import("common.zig");
const Config = @import("../../core/app_config.zig").RenderConfig;
const CString = common.CString;
const Window = @import("../../core/window.zig").Window;
const Swapchain = @import("Swapchain.zig");
const Instance = @import("Instance.zig");
const PhysicalDevice = @import("PhysicalDevice.zig");

const VulkanRenderer = @This();
const frame_overlap = 2; // TODO app level variable

const FrameData = struct {
    command_pool: vk.CommandPool,
    command_buffer: vk.CommandBuffer,
    swapchain_semaphore: vk.Semaphore,
    render_semaphore: vk.Semaphore,
    render_fence: vk.Fence,
};
const AllocatedImage = struct {
    image: vk.Image,
    image_view: vk.ImageView,
    allocation: c.VmaAllocation,
    image_extent: c.VkExtent3D,
    image_format: c.VkFormat,
};

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

frame_number: i32 = 0,
frames: [frame_overlap]FrameData,

vma_allocator: c.VmaAllocator,

draw_image: AllocatedImage,
draw_extent: c.VkExtent2D,

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
    self.frame_number = 0;
    self.graphics_queue_family = null;

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
        .instance = self.instance,
        .physical_device = self.gpu,
        .device = self.device,
        .flags = c.VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT,
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

    _ = c.vmaCreateImage(
        self.vma_allocator,
        &imageCreateInfo(
            self.draw_image.image_format,
            draw_image_usages,
            draw_image_extent,
        ),
        &.{
            .usage = c.VMA_MEMORY_USAGE_GPU_ONLY,
            .requiredFlags = c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        },
        &self.draw_image.image.handle,
        &self.draw_image.allocation,
        null,
    );

    self.draw_image.image_view = try self.device.createImageView(
        &imageViewCreateInfo(
            self.draw_image.image_format,
            self.draw_image.image,
            c.VK_IMAGE_ASPECT_COLOR_BIT,
        ),
        null,
    );

    try self.initCommands();
    try self.initSync();

    return self;
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
    return &self.frames[@intCast(@rem(self.frame_number, frame_overlap))];
}

fn initCommands(self: *VulkanRenderer) !void {
    const command_pool_info = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = self.graphics_queue_family.?,
    };
    for (&self.frames) |*frame| {
        frame.command_pool = try self.device.createCommandPool(
            &command_pool_info,
            null,
        );

        frame.command_buffer = try self.device.allocateCommandBuffers(&.{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = frame.command_pool.handle,
            .commandBufferCount = 1,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        });
    }
}

inline fn fenceCreateInfo(flags: c.VkFenceCreateFlags) c.VkFenceCreateInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = flags,
    };
}

inline fn semaphoreCreateInfo(
    flags: c.VkSemaphoreCreateFlags,
) c.VkSemaphoreCreateInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .flags = flags,
    };
}

fn initSync(self: *VulkanRenderer) !void {
    const fence_create_info = fenceCreateInfo(c.VK_FENCE_CREATE_SIGNALED_BIT);
    const sempahore_create_info = semaphoreCreateInfo(0);

    for (&self.frames) |*frame| {
        frame.render_fence = try self.device.createFence(&fence_create_info, null);
        frame.swapchain_semaphore = try self.device.createSemaphore(&sempahore_create_info, null);
        frame.render_semaphore = try self.device.createSemaphore(&sempahore_create_info, null);
    }
}

inline fn imageSubresourceRange(
    aspectMask: c.VkImageAspectFlags,
) c.VkImageSubresourceRange {
    return .{
        .aspectMask = aspectMask,
        .baseMipLevel = 0,
        .levelCount = c.VK_REMAINING_MIP_LEVELS,
        .baseArrayLayer = 0,
        .layerCount = c.VK_REMAINING_ARRAY_LAYERS,
    };
}

fn transitionImage(
    cmd: vk.CommandBuffer,
    image: vk.Image,
    current_layout: c.VkImageLayout,
    new_layout: c.VkImageLayout,
) void {
    cmd.pipelineBarrier2(&.{
        .sType = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
        .imageMemoryBarrierCount = 1,
        .pImageMemoryBarriers = &.{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
            .srcStageMask = c.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
            .srcAccessMask = c.VK_ACCESS_2_MEMORY_WRITE_BIT,
            .dstStageMask = c.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
            .dstAccessMask = c.VK_ACCESS_2_MEMORY_WRITE_BIT |
                c.VK_ACCESS_2_MEMORY_READ_BIT,

            .oldLayout = current_layout,
            .newLayout = new_layout,

            .subresourceRange = imageSubresourceRange(
                if (new_layout == c.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL)
                    c.VK_IMAGE_ASPECT_DEPTH_BIT
                else
                    c.VK_IMAGE_ASPECT_COLOR_BIT,
            ),
            .image = image.handle,
        },
    });
}

pub fn render(self: *VulkanRenderer) !void {
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

    try vk.check(frame.command_buffer.reset(0));
    try vk.check(frame.command_buffer.begin(&.{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    }));

    const next_image = self.swapchain_images.items[swapchain_image_index];
    transitionImage(
        frame.command_buffer,
        next_image,
        c.VK_IMAGE_LAYOUT_UNDEFINED,
        c.VK_IMAGE_LAYOUT_GENERAL,
    );

    frame.command_buffer.clearColorImage(
        next_image,
        c.VK_IMAGE_LAYOUT_GENERAL,
        &.{
            .float32 = .{
                100.0 / 255.0,
                149.0 / 255.0,
                237.0 / 255.0,
                0.0,
            },
        },
        &.{imageSubresourceRange(c.VK_IMAGE_ASPECT_COLOR_BIT)},
    );

    transitionImage(
        frame.command_buffer,
        next_image,
        c.VK_IMAGE_LAYOUT_GENERAL,
        c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    );

    try vk.check(frame.command_buffer.end());

    const cmd_info = commandBufferSubmitInfo(frame.command_buffer);
    const wait_info = sempahoreSubmitInfo(
        frame.swapchain_semaphore,
        c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
    );

    const signal_info = sempahoreSubmitInfo(
        frame.render_semaphore,
        c.VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT,
    );

    const submit = submitInfo(&.{cmd_info}, &.{signal_info}, &.{wait_info});
    try vk.check(self.graphics_queue.submit2(&.{submit}, frame.render_fence));

    try vk.check(self.graphics_queue.presentKHR(&.{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pSwapchains = &self.swapchain.handle,
        .swapchainCount = 1,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &frame.render_semaphore.handle,
        .pImageIndices = &swapchain_image_index,
    }));

    self.frame_number += 1;
}

inline fn imageCreateInfo(
    format: c.VkFormat,
    usage_flags: c.VkImageUsageFlags,
    extent: c.VkExtent3D,
) c.VkImageCreateInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = c.VK_IMAGE_TYPE_2D,
        .format = format,
        .extent = extent,
        .mipLevels = 1,
        .arrayLayers = 1,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .tiling = c.VK_IMAGE_TILING_OPTIMAL,
        .usage = usage_flags,
    };
}

inline fn imageViewCreateInfo(
    format: c.VkFormat,
    image: vk.Image,
    aspect_flags: c.VkImageAspectFlags,
) c.VkImageViewCreateInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .image = image.handle,
        .format = format,
        .subresourceRange = .{
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
            .aspectMask = aspect_flags,
        },
    };
}

inline fn commandBufferSubmitInfo(
    cmd: vk.CommandBuffer,
) c.VkCommandBufferSubmitInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
        .commandBuffer = cmd.handle,
        .deviceMask = 0,
    };
}

inline fn sempahoreSubmitInfo(
    semaphore: vk.Semaphore,
    stage_mask: c.VkPipelineStageFlags2,
) c.VkSemaphoreSubmitInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
        .semaphore = semaphore.handle,
        .stageMask = stage_mask,
        .deviceIndex = 0,
        .value = 1,
    };
}

inline fn submitInfo(
    cmd_buffer_infos: []const c.VkCommandBufferSubmitInfo,
    signal_semaphore_infos: []const c.VkSemaphoreSubmitInfo,
    wait_semaphore_infos: []const c.VkSemaphoreSubmitInfo,
) c.VkSubmitInfo2 {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO_2,
        .waitSemaphoreInfoCount = @intCast(wait_semaphore_infos.len),
        .pWaitSemaphoreInfos = @ptrCast(wait_semaphore_infos.ptr),
        .signalSemaphoreInfoCount = @intCast(signal_semaphore_infos.len),
        .pSignalSemaphoreInfos = @ptrCast(signal_semaphore_infos.ptr),
        .commandBufferInfoCount = @intCast(cmd_buffer_infos.len),
        .pCommandBufferInfos = @ptrCast(cmd_buffer_infos.ptr),
    };
}

pub fn onWindowResize(self: *VulkanRenderer, width: u32, height: u32) void {
    _ = self;
    _ = width;
    _ = height;
}

fn destroySwapchain(self: *VulkanRenderer) void {
    self.device.destroySwapchainKHR(&self.swapchain, null);
    for (self.swapchain_image_views.items) |*image_view| {
        self.device.destroyImageView(image_view, null);
    }
    self.swapchain_image_views.deinit();
    self.swapchain_images.deinit();
}

pub fn deinit(self: *VulkanRenderer) void {
    _ = self.device.waitIdle() catch {};

    self.device.destroyImageView(&self.draw_image.image_view, null);
    _ = c.vmaDestroyImage(
        self.vma_allocator,
        self.draw_image.image.handle,
        self.draw_image.allocation,
    );

    for (&self.frames) |*frame| {
        self.device.destroyCommandPool(&frame.command_pool, null);
        self.device.destroyFence(&frame.render_fence, null);
        self.device.destroySemaphore(&frame.render_semaphore, null);
        self.device.destroySemaphore(&frame.swapchain_semaphore, null);
    }

    self.destroySwapchain();
    self.instance.destroySurfaceKHR(&self.surface, null);
    c.vmaDestroyAllocator(self.vma_allocator);
    self.device.destroy(null);
    self.instance.destroyDebugUtilsMessengerEXT(&self.debug_messenger, null) catch {};
    self.instance.destroy(null);
}
