const std = @import("std");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");

pub inline fn imageCreateInfo(
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

pub inline fn imageViewCreateInfo(
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

pub inline fn commandBufferSubmitInfo(
    cmd: vk.CommandBuffer,
) c.VkCommandBufferSubmitInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
        .commandBuffer = cmd.handle,
        .deviceMask = 0,
    };
}

pub inline fn sempahoreSubmitInfo(
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

pub inline fn submitInfo(
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

pub inline fn attachmentInfo(
    view: vk.ImageView,
    clear: ?*const c.VkClearValue,
    layout: c.VkImageLayout,
) c.VkRenderingAttachmentInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
        .imageView = view.handle,
        .imageLayout = layout,
        .loadOp = if (clear) |_| c.VK_ATTACHMENT_LOAD_OP_CLEAR else c.VK_ATTACHMENT_LOAD_OP_LOAD,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .clearValue = if (clear) |value| value else std.mem.zeroes(c.VkClearValue),
    };
}

pub inline fn fenceCreateInfo(flags: c.VkFenceCreateFlags) c.VkFenceCreateInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = flags,
    };
}

pub inline fn semaphoreCreateInfo(
    flags: c.VkSemaphoreCreateFlags,
) c.VkSemaphoreCreateInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .flags = flags,
    };
}

pub inline fn imageSubresourceRange(
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

pub inline fn renderingInfo(
    render_extent: c.VkExtent2D,
    color_attachment: *const c.VkRenderingAttachmentInfo,
    depth_attachment: ?*const c.VkRenderingAttachmentInfo,
) c.VkRenderingInfo {
    return .{
        .sType = c.VK_STRUCTURE_TYPE_RENDERING_INFO,
        .renderArea = c.VkRect2D{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = render_extent,
        },
        .layerCount = 1,
        .colorAttachmentCount = 1,
        .pColorAttachments = color_attachment,
        .pDepthAttachment = depth_attachment,
    };
}
