const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");

const queue_index_maxhandle: u32 = 0xFFFF;
const image_format: c.VkFormat = c.VK_FORMAT_B8G8R8A8_UNORM;
const image_usage_flags: c.VkImageUsageFlags = c.VK_IMAGE_USAGE_TRANSFER_DST_BIT |
    c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

pub fn create(
    arena: std.mem.Allocator,
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    surface: c.VkSurfaceKHR,
    info: struct {
        old_swapchain: ?c.VkSwapchainKHR = null,
        vsync: bool = true,
        width: u32,
        height: u32,
    },
) !struct {
    swapchain: c.VkSwapchainKHR,
    extent: c.VkExtent2D,
} {
    var surface_capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try vk.check(vk.getPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &surface_capabilities));

    var image_count = surface_capabilities.minImageCount + 1;
    if (surface_capabilities.maxImageCount > 0 and
        image_count > surface_capabilities.maxImageCount)
    {
        image_count = surface_capabilities.maxImageCount;
    }

    var format_count: u32 = undefined;
    try vk.check(vk.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null));
    const available_surface_formats = try arena.alloc(c.VkSurfaceFormatKHR, format_count);
    try vk.check(vk.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, available_surface_formats.ptr));

    const surface_format = try findBestSurfaceFormat(
        available_surface_formats,
        &.{
            c.VkSurfaceFormatKHR{
                .format = image_format,
                .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            },
        },
    );

    const extent = findExtent(
        surface_capabilities,
        info.width,
        info.height,
    );

    var present_mode: c.VkPresentModeKHR = c.VK_PRESENT_MODE_FIFO_KHR;
    if (!info.vsync) {
        var present_mode_count: u32 = undefined;
        try vk.check(vk.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, null));
        const available_present_modes = try arena.alloc(c.VkPresentModeKHR, present_mode_count);
        try vk.check(vk.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, available_present_modes.ptr));

        for (available_present_modes) |available| {
            if (available == c.VK_PRESENT_MODE_IMMEDIATE_KHR) {
                present_mode = c.VK_PRESENT_MODE_IMMEDIATE_KHR;
                break;
            }
        }
    }

    if (image_usage_flags & surface_capabilities.supportedUsageFlags != image_usage_flags) {
        return error.RequiredUsageNotSupported;
    }

    var swapchain: c.VkSwapchainKHR = undefined;
    try vk.check(vk.createSwapchainKHR(
        device,
        &c.VkSwapchainCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,
            .minImageCount = image_count,
            .imageFormat = surface_format.format,
            .imageColorSpace = surface_format.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = image_usage_flags,
            .preTransform = surface_capabilities.currentTransform,
            .compositeAlpha = if (@hasDecl(c, "__ANDROID__"))
                c.VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR
            else
                c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,

            .presentMode = present_mode,
            .clipped = c.VK_TRUE,
            .oldSwapchain = if (info.old_swapchain) |sc| sc else null,
        },
        null,
        &swapchain,
    ));

    return .{
        .extent = extent,
        .swapchain = swapchain,
    };
}

pub inline fn getImageViewsBuffered(
    device: c.VkDevice,
    images: []c.VkImage,
    list: *std.ArrayList(c.VkImageView),
) !void {
    list.clearRetainingCapacity();

    var desired_flags: c.VkImageViewUsageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_USAGE_CREATE_INFO,
        .usage = image_usage_flags,
    };

    try list.ensureUnusedCapacity(images.len);
    for (images) |image| {
        var create_info: c.VkImageViewCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = &desired_flags,
            .image = image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = image_format,
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

        var image_view: c.VkImageView = undefined;
        try vk.check(vk.createImageView(
            device,
            &create_info,
            null,
            &image_view,
        ));
        try list.append(image_view);
    }
}

pub fn getImagesBuffered(
    device: c.VkDevice,
    swapchain: c.VkSwapchainKHR,
    list: *std.ArrayList(c.VkImage),
) !void {
    list.clearRetainingCapacity();
    var image_count: u32 = undefined;
    try vk.check(vk.getSwapchainImagesKHR(device, swapchain, &image_count, null));
    try list.ensureUnusedCapacity(image_count);
    try vk.check(vk.getSwapchainImagesKHR(device, swapchain, &image_count, list.unusedCapacitySlice().ptr));
    list.items.len += image_count;
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
    capabilities: c.VkSurfaceCapabilitiesKHR,
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
