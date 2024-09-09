const std = @import("std");
const time = @import("../../core/time.zig");
const config = @import("config");
const vk = @import("vulkan.zig");
const c = vk.c;
const vkinit = @import("vkinit.zig");
const imgui = @import("imgui.zig");
const common = @import("common.zig");
const descriptors = @import("descriptors.zig");
const pipelines = @import("pipelines.zig");
const types = @import("types.zig");
const math = @import("../../math/math.zig");
const VulkanRenderer = @import("VulkanRenderer.zig");

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
    imgui.ImGui_ImplVulkan_RenderDrawData(imgui.c.igGetDrawData(), cmd.handle(), null);
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

var frame: u32 = 0;

pub fn geometry(self: *VulkanRenderer, cmd: vk.CommandBuffer) void {
    cmd.beginRendering(
        &vkinit.renderingInfo(
            self.draw_extent,
            &vkinit.attachmentInfo(
                self.draw_image.image_view,
                null,
                c.VK_IMAGE_LAYOUT_GENERAL,
            ),
            &vkinit.depthAttachmentInfo(
                self.depth_image.image_view,
                c.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL,
            ),
        ),
    );

    cmd.bindPipeline(c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.mesh_pipeline);
    const viewport_height: f32 = @floatFromInt(self.draw_extent.height);
    cmd.setViewport(0, &.{
        c.VkViewport{
            .x = 0,
            .y = viewport_height,
            .width = @floatFromInt(self.draw_extent.width),
            .height = -viewport_height,
            .minDepth = 0.0,
            .maxDepth = 1.0,
        },
    });

    cmd.setScissor(0, &.{
        c.VkRect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{
                .width = self.draw_extent.width,
                .height = self.draw_extent.height,
            },
        },
    });

    const model = math.Mat4.scaling(math.vec3(1.5, 1.5, 1.5)).mul(
        math.Mat4.rotation(math.Quat.fromAxisAngle(math.vec3(0, 0, 1), math.degToRad(45))),
    ).mul(math.Mat4.translation(math.vec3(0.0, 0.0, 0.0)));

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

    const mesh_asset = self.test_meshes[2];
    var push_constants = types.DrawPushConstants{
        .world_matrix = projection.mul(view.mul(model)),
        .vertex_buffer = mesh_asset.mesh.vb_addr,
    };

    cmd.pushConstants(
        self.mesh_pipeline_layout,
        c.VK_SHADER_STAGE_VERTEX_BIT,
        0,
        @sizeOf(types.DrawPushConstants),
        &push_constants,
    );

    cmd.bindIndexBuffer(mesh_asset.mesh.index_buffer.buffer, 0, c.VK_INDEX_TYPE_UINT32);
    const surface = mesh_asset.surfaces[0];
    cmd.drawIndexed(surface.count, 1, surface.start_index, 0, 0);
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
        .sType = c.VK_STRUCTURE_TYPE_BLIT_IMAGE_INFO_2_KHR,
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
