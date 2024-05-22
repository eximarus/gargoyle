const std = @import("std");
const config = @import("config");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");
const vkinit = @import("vkinit.zig");
const vma = @import("vma.zig");
const imgui = @import("imgui.zig");
const common = @import("common.zig");
const descriptors = @import("descriptors.zig");
const pipelines = @import("pipelines.zig");
const VulkanRenderer = @import("VulkanRenderer.zig");
const math = @import("../../math/math.zig");
const CString = common.CString;

pub fn background(self: *VulkanRenderer, cmd: vk.CommandBuffer) void {
    cmd.clearColorImage(
        self.draw_image.image,
        c.VK_IMAGE_LAYOUT_GENERAL,
        &.{
            .float32 = .{
                100.0 / 255.0,
                149.0 / 255.0,
                237.0 / 255.0,
                0.0,
            },
        },
        &.{vkinit.imageSubresourceRange(c.VK_IMAGE_ASPECT_COLOR_BIT)},
    );

    const effect = self.background_effects.items[
        @intCast(self.current_background_effect)
    ];

    cmd.bindPipeline(
        c.VK_PIPELINE_BIND_POINT_COMPUTE,
        effect.pipeline,
    );
    cmd.bindDescriptorSets(
        c.VK_PIPELINE_BIND_POINT_COMPUTE,
        self.gradient_pipeline_layout,
        0,
        &.{self.draw_image_descriptors},
        &.{},
    );

    cmd.pushConstants(
        self.gradient_pipeline_layout,
        c.VK_SHADER_STAGE_COMPUTE_BIT,
        0,
        @sizeOf(VulkanRenderer.ComputePushConstants),
        &effect.data,
    );

    cmd.dispatch(
        @intFromFloat(@ceil(@as(f32, @floatFromInt(self.draw_extent.width)) / 16.0)),
        @intFromFloat(@ceil(@as(f32, @floatFromInt(self.draw_extent.height)) / 16.0)),
        1,
    );
}

pub fn gui(
    cmd: vk.CommandBuffer,
    target_image_view: vk.ImageView,
    target_extent: c.VkExtent2D,
) void {
    cmd.beginRendering(&vkinit.renderingInfo(
        target_extent,
        &vkinit.attachmentInfo(
            target_image_view,
            null,
            c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        ),
        null,
    ));
    imgui.ImGui_ImplVulkan_RenderDrawData(c.igGetDrawData(), cmd.handle(), null);
    cmd.endRendering();
}

pub inline fn transitionImage(
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

            .subresourceRange = vkinit.imageSubresourceRange(
                if (new_layout == c.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL)
                    c.VK_IMAGE_ASPECT_DEPTH_BIT
                else
                    c.VK_IMAGE_ASPECT_COLOR_BIT,
            ),
            .image = image,
        },
    });
}

pub fn geometry(self: *VulkanRenderer, cmd: vk.CommandBuffer) void {
    cmd.beginRendering(
        &vkinit.renderingInfo(self.draw_extent, &vkinit.attachmentInfo(
            self.draw_image.image_view,
            null,
            c.VK_IMAGE_LAYOUT_GENERAL,
        ), null),
    );

    cmd.bindPipeline(c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.triangle_pipeline);
    cmd.setViewport(0, &.{
        c.VkViewport{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(self.draw_extent.width),
            .height = @floatFromInt(self.draw_extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        },
    });

    cmd.setScissor(0, &.{
        c.VkRect2D{
            .offset = .{
                .x = 0,
                .y = 0,
            },
            .extent = .{
                .width = self.draw_extent.width,
                .height = self.draw_extent.height,
            },
        },
    });

    cmd.draw(3, 1, 0, 0);
    cmd.endRendering();
}

pub inline fn copyImageToImage(
    cmd: vk.CommandBuffer,
    src: vk.Image,
    dst: vk.Image,
    src_size: c.VkExtent2D,
    dst_size: c.VkExtent2D,
) void {
    cmd.blitImage2(&.{
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
