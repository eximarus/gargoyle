const std = @import("std");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");
const common = @import("common.zig");
const CString = common.CString;

const Swapchain = @This();

device: vk.Device,
swapchain: vk.SwapchainKHR,
image_count: u32 = 0,
image_format: c.VkFormat = c.VK_FORMAT_UNDEFINED,
color_space: c.VkColorSpaceKHR = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
image_usage_flags: c.VkImageUsageFlags = 0,
extent: c.VkExtent2D = .{ .width = 0, .height = 0 },
requested_min_image_count: u32 = 0,

present_mode: c.VkPresentModeKHR = c.VK_PRESENT_MODE_IMMEDIATE_KHR,
instance_version: u32 = c.VK_API_VERSION_1_0,
allocation_callbacks: ?*c.VkAllocationCallbacks = null,

const queue_index_maxhandle: u32 = 0xFFFF;

pub inline fn init(
    arena: std.mem.Allocator,
    physical_device: vk.PhysicalDevice,
    device: vk.Device,
    surface: vk.SurfaceKHR,
    info: *const struct {
        old_swapchain: ?union(enum) {
            vk_swapchain: vk.SwapchainKHR,
            swapchain: Swapchain,
        } = null,
        desired_extent: struct { width: u32, height: u32 } = .{
            .width = 256,
            .height = 256,
        },
        desired_formats: []const c.VkSurfaceFormatKHR = &.{},
        pNext_chain: []const *c.VkBaseOutStructure = &.{},
        create_flags: c.VkSwapchainCreateFlagBitsKHR = 0,
        instance_version: u32 = c.VK_API_VERSION_1_0,
        array_layer_count: u32 = 1,
        min_image_count: u32 = 0,
        required_min_image_count: u32 = 0,
        image_usage_flags: c.VkImageUsageFlags =
            c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

        graphics_queue_index: u32 = queue_index_maxhandle,
        present_queue_index: u32 = queue_index_maxhandle,
        pre_transform: c.VkSurfaceTransformFlagBitsKHR = 0,
        composite_alpha: c.VkCompositeAlphaFlagBitsKHR =
            if (@hasDecl(c, "__ANDROID__"))
                c.VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR
            else
                c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,

        desired_present_modes: []const c.VkPresentModeKHR = &.{},
        clipped: bool = true,
        allocation_callbacks: ?*c.VkAllocationCallbacks = null,
    },
) !Swapchain {
    if (surface == null) {
        return error.SurfaceHandleNotProvided;
    }

    var desired_formats = std.ArrayList(c.VkSurfaceFormatKHR).init(arena);
    try desired_formats.appendSlice(info.desired_formats);

    if (desired_formats.items.len == 0) {
        try desired_formats.append(.{
            .format = c.VK_FORMAT_B8G8R8A8_SRGB,
            .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        });
        try desired_formats.append(.{
            .format = c.VK_FORMAT_R8G8B8A8_SRGB,
            .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        });
    }

    var desired_present_modes = std.ArrayList(c.VkPresentModeKHR).init(arena);
    try desired_present_modes.appendSlice(info.desired_present_modes);

    if (desired_present_modes.items.len == 0) {
        try desired_present_modes.append(c.VK_PRESENT_MODE_MAILBOX_KHR);
        try desired_present_modes.append(c.VK_PRESENT_MODE_FIFO_KHR);
    }

    const surface_capabilities =
        try physical_device.getSurfaceCapabilitiesKHR(surface);

    var image_count = info.min_image_count;
    if (info.required_min_image_count >= 1) {
        if (info.required_min_image_count < surface_capabilities.minImageCount) {
            return error.RequiredMinImageCountTooLow;
        }
        image_count = info.required_min_image_count;
    } else if (info.min_image_count == 0) {
        image_count = surface_capabilities.minImageCount + 1;
    } else {
        image_count = info.min_image_count;
        if (image_count < surface_capabilities.minImageCount) {
            image_count = surface_capabilities.minImageCount;
        }
    }

    if (surface_capabilities.maxImageCount > 0 and
        image_count > surface_capabilities.maxImageCount)
    {
        image_count = surface_capabilities.maxImageCount;
    }

    const available_surface_formats =
        try physical_device.getSurfaceFormatsKHR(surface, arena);

    const surface_format = try findBestSurfaceFormat(
        available_surface_formats,
        desired_formats.items,
    );

    const extent = findExtent(
        &surface_capabilities,
        info.desired_extent.width,
        info.desired_extent.height,
    );

    var image_array_layers = info.array_layer_count;
    if (surface_capabilities.maxImageArrayLayers < info.array_layer_count) {
        image_array_layers = surface_capabilities.maxImageArrayLayers;
    }
    if (info.array_layer_count == 0) {
        image_array_layers = 1;
    }

    const available_present_modes =
        try physical_device.getSurfacePresentModesKHR(surface, arena);

    const present_mode = findPresentMode(
        available_present_modes,
        desired_present_modes.items,
    );

    const is_unextended_present_mode = switch (present_mode) {
        c.VK_PRESENT_MODE_IMMEDIATE_KHR,
        c.VK_PRESENT_MODE_MAILBOX_KHR,
        c.VK_PRESENT_MODE_FIFO_KHR,
        c.VK_PRESENT_MODE_FIFO_RELAXED_KHR,
        => true,
        else => false,
    };

    if (is_unextended_present_mode and
        info.image_usage_flags & surface_capabilities.supportedUsageFlags !=
        info.image_usage_flags)
    {
        return error.RequiredUsageNotSupported;
    }

    var pre_transform = info.pre_transform;
    if (info.pre_transform == 0) {
        pre_transform = surface_capabilities.currentTransform;
    }

    var swapchain_create_info = c.VkSwapchainCreateInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .flags = info.create_flags,
        .surface = surface,
        .minImageCount = image_count,
        .imageFormat = surface_format.format,
        .imageColorSpace = surface_format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = image_array_layers,
        .imageUsage = info.image_usage_flags,
        .preTransform = pre_transform,
        .compositeAlpha = info.composite_alpha,
        .presentMode = present_mode,
        .clipped = if (info.clipped) 1 else 0,
    };

    for (info.pNext_chain) |node| {
        std.debug.assert(node.sType != c.VK_STRUCTURE_TYPE_APPLICATION_INFO);
    }

    swapchain_create_info.pNext = null;
    if (info.pNext_chain.len > 0) {
        for (info.pNext_chain[0 .. info.pNext_chain.len - 1], 0..) |next, i| {
            next.pNext = info.pNext_chain[i + 1];
        }
        swapchain_create_info.pNext = info.pNext_chain[0];
    }

    if (info.old_swapchain) |value| {
        swapchain_create_info.oldSwapchain = switch (value) {
            .swapchain => |s| s.swapchain,
            .vk_swapchain => |s| s,
        };
    }

    const queue_family_indices = [_]u32{
        info.graphics_queue_index,
        info.present_queue_index,
    };

    if (info.graphics_queue_index != info.present_queue_index) {
        swapchain_create_info.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        swapchain_create_info.queueFamilyIndexCount = 2;
        swapchain_create_info.pQueueFamilyIndices = &queue_family_indices;
    } else {
        swapchain_create_info.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
    }

    var self: Swapchain = undefined;
    self.swapchain = try device.createSwapchainKHR(&swapchain_create_info, null);
    self.device = device;
    self.image_format = surface_format.format;
    self.color_space = surface_format.colorSpace;
    self.image_usage_flags = info.image_usage_flags;
    self.extent = extent;
    self.requested_min_image_count = image_count;
    self.present_mode = present_mode;
    self.instance_version = info.instance_version;
    self.allocation_callbacks = info.allocation_callbacks;
    self.image_count = try self.device.getSwapchainImageCount(self.swapchain);

    return self;
}

pub inline fn getImages(
    self: Swapchain,
    allocator: std.mem.Allocator,
) ![]vk.Image {
    return self.device.getSwapchainImagesKHR(self.swapchain, allocator);
}

pub inline fn getImagesBuffered(
    self: Swapchain,
    list: *std.ArrayList(vk.Image),
) !void {
    list.clearRetainingCapacity();
    return self.device.getSwapchainImagesKHRBuffered(self.swapchain, list);
}

pub inline fn getImageViews(
    self: Swapchain,
    allocator: std.mem.Allocator,
    pNext: ?*anyopaque,
) ![]vk.ImageView {
    const swapchain_images = try self.getImages(allocator);

    var already_contains_image_view_usage = false;
    if (pNext) |value| {
        for (&std.mem.span(value)) |*next| {
            const base = @as(*const c.VkBaseInStructure, @ptrCast(next));
            if (base.sType == c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO) {
                already_contains_image_view_usage = true;
                break;
            }
            next.* = base.pNext;
        }
    }

    var desired_flags: c.VkImageViewUsageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_USAGE_CREATE_INFO,
        .pNext = pNext,
        .usage = self.image_usage_flags,
    };

    const views = try allocator.alloc(vk.ImageView, swapchain_images.len);
    for (swapchain_images, views) |image, *view| {
        var create_info: c.VkImageViewCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,

            .image = image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = self.image_format,
            .components = .{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        if (self.instance_version >= c.VK_API_VERSION_1_1 and !already_contains_image_view_usage) {
            create_info.pNext = &desired_flags;
        } else {
            create_info.pNext = pNext;
        }

        view.* = try vk.ImageView.create(self.device, &create_info, self.allocation_callbacks);
    }
    return views;
}

pub inline fn getImageViewsBuffered(
    self: Swapchain,
    images: []vk.Image,
    list: *std.ArrayList(vk.ImageView),
    pNext: ?*anyopaque,
) !void {
    list.clearRetainingCapacity();
    var already_contains_image_view_usage = false;
    if (pNext) |value| {
        for (&std.mem.span(value)) |*next| {
            const base = @as(*const c.VkBaseInStructure, @ptrCast(next));
            if (base.sType == c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO) {
                already_contains_image_view_usage = true;
                break;
            }
            next.* = base.pNext;
        }
    }

    var desired_flags: c.VkImageViewUsageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_USAGE_CREATE_INFO,
        .pNext = pNext,
        .usage = self.image_usage_flags,
    };

    try list.ensureUnusedCapacity(images.len);
    for (images) |image| {
        var create_info: c.VkImageViewCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,

            .image = image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = self.image_format,
            .components = .{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        if (self.instance_version >= c.VK_API_VERSION_1_1 and !already_contains_image_view_usage) {
            create_info.pNext = &desired_flags;
        } else {
            create_info.pNext = pNext;
        }

        try list.append(try self.device.createImageView(
            &create_info,
            self.allocation_callbacks,
        ));
    }
}

pub inline fn destroy(self: *Swapchain) void {
    self.swapchain.destroy(self.device);
}

fn findBestSurfaceFormat(
    available_formats: []const c.VkSurfaceFormatKHR,
    desired_formats: []const c.VkSurfaceFormatKHR,
) !c.VkSurfaceFormatKHR {
    if (findDesiredSurfaceFormat(available_formats, desired_formats)) |value| {
        return value;
    } else |_| {
        return available_formats[0];
    }
}

fn findDesiredSurfaceFormat(
    available_formats: []const c.VkSurfaceFormatKHR,
    desired_formats: []const c.VkSurfaceFormatKHR,
) !c.VkSurfaceFormatKHR {
    for (desired_formats) |desired_format| {
        for (available_formats) |available_format| {
            if (desired_format.format == available_format.format and
                desired_format.colorSpace == available_format.colorSpace)
            {
                return desired_format;
            }
        }
    }
    return error.NoSuitableDesiredFormat;
}

fn findExtent(
    capabilities: *const c.VkSurfaceCapabilitiesKHR,
    desired_width: u32,
    desired_height: u32,
) c.VkExtent2D {
    if (capabilities.currentExtent.width != c.UINT32_MAX) {
        return capabilities.currentExtent;
    }

    var actualExtent = c.VkExtent2D{
        .width = desired_width,
        .height = desired_height,
    };
    actualExtent.width =
        @max(capabilities.minImageExtent.width, @min(
        capabilities.maxImageExtent.width,
        actualExtent.width,
    ));
    actualExtent.height =
        @max(capabilities.minImageExtent.height, @min(
        capabilities.maxImageExtent.height,
        actualExtent.height,
    ));

    return actualExtent;
}

fn findPresentMode(
    available_present_modes: []const c.VkPresentModeKHR,
    desired_present_modes: []const c.VkPresentModeKHR,
) c.VkPresentModeKHR {
    for (desired_present_modes) |desired| {
        for (available_present_modes) |available| {
            if (desired == available) {
                return desired;
            }
        }
    }
    return c.VK_PRESENT_MODE_FIFO_KHR;
}
