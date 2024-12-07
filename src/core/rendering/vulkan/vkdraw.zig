const std = @import("std");
const c = @import("c");

const vk = @import("vulkan.zig");
const resources = @import("resources.zig");
const Pipeline = @import("pipeline.zig").Pipeline;
const types = @import("types.zig");

pub inline fn transitionImage(
    cmd: c.VkCommandBuffer,
    image: c.VkImage,
    current_layout: c.VkImageLayout,
    new_layout: c.VkImageLayout,
) void {
    vk.cmdPipelineBarrier2(cmd, &.{
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
            .subresourceRange = c.VkImageSubresourceRange{
                .aspectMask = if (new_layout == c.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL)
                    c.VK_IMAGE_ASPECT_DEPTH_BIT
                else
                    c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = c.VK_REMAINING_MIP_LEVELS,
                .baseArrayLayer = 0,
                .layerCount = c.VK_REMAINING_ARRAY_LAYERS,
            },
            .image = image,
        },
    });
}

// TODO have this in game code or at least partially
pub fn graphics(
    cmd: c.VkCommandBuffer,
    draw_extent: c.VkExtent2D,
    draw_image: resources.Image,
    depth_image: resources.Image,
    pipeline: Pipeline,
    push_constants: types.PushConstants,
    index_buffer: resources.Buffer,
    descriptor_set: c.VkDescriptorSet,
) void {
    vk.cmdBeginRendering(cmd, &c.VkRenderingInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDERING_INFO_KHR,
        .renderArea = c.VkRect2D{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = draw_extent,
        },
        .layerCount = 1,
        .colorAttachmentCount = 1,
        .pColorAttachments = &c.VkRenderingAttachmentInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
            .imageView = draw_image.view,
            .imageLayout = c.VK_IMAGE_LAYOUT_GENERAL,
            .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
            .clearValue = c.VkClearValue{
                .color = c.VkClearColorValue{
                    // TODO dont clear, draw skybox
                    .float32 = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
                },
            },
        },
        .pDepthAttachment = &c.VkRenderingAttachmentInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
            .imageView = depth_image.view,
            .imageLayout = c.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL,
            .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
            .clearValue = .{
                .depthStencil = .{
                    .depth = 0.0,
                    .stencil = 0,
                },
            },
        },
    });

    vk.cmdBindPipeline(cmd, pipeline.bind_point, pipeline.pipline);

    const viewport_height: f32 = @floatFromInt(draw_extent.height);

    vk.cmdSetViewport(cmd, 0, 1, &c.VkViewport{
        .x = 0,
        .y = viewport_height,
        .width = @floatFromInt(draw_extent.width),
        .height = -viewport_height,
        .minDepth = 1.0,
        .maxDepth = 0.0,
    });

    vk.cmdSetScissor(cmd, 0, 1, &c.VkRect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{
            .width = draw_extent.width,
            .height = draw_extent.height,
        },
    });

    vk.cmdPushConstants(
        cmd,
        pipeline.layout,
        c.VK_SHADER_STAGE_VERTEX_BIT,
        0,
        @sizeOf(types.PushConstants),
        &push_constants,
    );

    vk.cmdBindDescriptorSets(
        cmd,
        c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        pipeline.layout,
        0,
        1,
        &descriptor_set,
        0,
        null,
    );

    vk.cmdBindIndexBuffer(cmd, index_buffer.buffer, 0, c.VK_INDEX_TYPE_UINT32);
    vk.cmdDrawIndexed(cmd, @intCast(index_buffer.size / @sizeOf(u32)), 1, 0, 0, 0);
    vk.cmdEndRendering(cmd);
}

pub inline fn copyImageToImage(
    cmd: c.VkCommandBuffer,
    src: c.VkImage,
    dst: c.VkImage,
    src_size: c.VkExtent2D,
    dst_size: c.VkExtent2D,
) void {
    vk.cmdBlitImage2(cmd, &.{
        .sType = c.VK_STRUCTURE_TYPE_BLIT_IMAGE_INFO_2,
        .dstImage = dst,
        .dstImageLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        .srcImage = src,
        .srcImageLayout = c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        .filter = c.VK_FILTER_LINEAR,
        .regionCount = 1,
        .pRegions = &c.VkImageBlit2{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_BLIT_2,
            .srcOffsets = .{
                .{},
                .{
                    .x = @bitCast(src_size.width),
                    .y = @bitCast(src_size.height),
                    .z = 1,
                },
            },
            .dstOffsets = .{
                .{},
                .{
                    .x = @bitCast(dst_size.width),
                    .y = @bitCast(dst_size.height),
                    .z = 1,
                },
            },
            .srcSubresource = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .layerCount = 1,
                .mipLevel = 0,
            },
            .dstSubresource = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .layerCount = 1,
                .mipLevel = 0,
            },
        },
    });
}
