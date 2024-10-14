const std = @import("std");
const c = @import("c");
const core = @import("../../root.zig");
const time = core.time;
const math = core.math;

const vk = @import("vulkan.zig");
const common = @import("common.zig");
const resources = @import("resources.zig");
const GraphicsShader = @import("shader.zig").GraphicsShader;
const types = @import("types.zig");
const VulkanRenderer = @import("VulkanRenderer.zig");

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
    shader: GraphicsShader,
    push_constants: types.PushConstants,
    index_buffer: resources.Buffer,
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
                    .depth = 1.0,
                },
            },
        },
    });

    shader.bind(cmd);
    const viewport_height: f32 = @floatFromInt(draw_extent.height);

    // vertex input state
    vk.cmdSetVertexInputEXT(cmd, 0, &.{}, 0, &.{});

    // input assembly state
    vk.cmdSetPrimitiveTopologyEXT(cmd, c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
    vk.cmdSetPrimitiveRestartEnableEXT(cmd, c.VK_FALSE);

    // viewport state
    vk.cmdSetViewportWithCountEXT(cmd, 1, &c.VkViewport{
        .x = 0,
        .y = viewport_height,
        .width = @floatFromInt(draw_extent.width),
        .height = -viewport_height,
        .minDepth = 0.0,
        .maxDepth = 1.0,
    });
    vk.cmdSetScissorWithCountEXT(cmd, 1, &c.VkRect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{
            .width = draw_extent.width,
            .height = draw_extent.height,
        },
    });

    // vk.cmdBindDescriptorSets

    // rasterization state
    vk.cmdSetPolygonModeEXT(cmd, c.VK_POLYGON_MODE_FILL);
    vk.cmdSetLineWidth(cmd, 1.0);
    vk.cmdSetCullModeEXT(cmd, c.VK_CULL_MODE_BACK_BIT);
    vk.cmdSetFrontFaceEXT(cmd, c.VK_FRONT_FACE_CLOCKWISE);
    vk.cmdSetDepthBiasEnableEXT(cmd, c.VK_FALSE);
    vk.cmdSetRasterizerDiscardEnableEXT(cmd, c.VK_FALSE);

    // multisample state
    vk.cmdSetSampleMaskEXT(cmd, c.VK_SAMPLE_COUNT_1_BIT, &[1]c.VkSampleMask{0xffffffff});
    vk.cmdSetRasterizationSamplesEXT(cmd, c.VK_SAMPLE_COUNT_1_BIT);

    vk.cmdSetAlphaToCoverageEnableEXT(cmd, c.VK_FALSE);
    vk.cmdSetAlphaToOneEnableEXT(cmd, c.VK_FALSE);

    // color blend state
    vk.cmdSetLogicOpEnableEXT(cmd, c.VK_FALSE);
    vk.cmdSetLogicOpEXT(cmd, c.VK_LOGIC_OP_COPY);
    vk.cmdSetColorWriteMaskEXT(
        cmd,
        0,
        1,
        &[1]c.VkColorComponentFlagBits{c.VK_COLOR_COMPONENT_R_BIT |
            c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT |
            c.VK_COLOR_COMPONENT_A_BIT},
    );
    vk.cmdSetColorBlendEnableEXT(cmd, 0, 1, &[1]c.VkBool32{c.VK_FALSE});
    vk.cmdSetColorBlendEquationEXT(cmd, 0, 1, &c.VkColorBlendEquationEXT{});

    // depth stencil state
    vk.cmdSetDepthTestEnableEXT(cmd, c.VK_TRUE);
    vk.cmdSetDepthWriteEnableEXT(cmd, c.VK_TRUE);
    vk.cmdSetDepthCompareOpEXT(cmd, c.VK_COMPARE_OP_LESS);
    vk.cmdSetDepthBoundsTestEnableEXT(cmd, c.VK_FALSE);
    vk.cmdSetStencilTestEnableEXT(cmd, c.VK_FALSE);
    vk.cmdSetStencilOpEXT(
        cmd,
        c.VK_STENCIL_FACE_FRONT_BIT,
        c.VK_STENCIL_OP_KEEP,
        c.VK_STENCIL_OP_KEEP,
        c.VK_STENCIL_OP_KEEP,
        c.VK_COMPARE_OP_NEVER,
    );
    vk.cmdSetStencilOpEXT(
        cmd,
        c.VK_STENCIL_FACE_BACK_BIT,
        c.VK_STENCIL_OP_KEEP,
        c.VK_STENCIL_OP_KEEP,
        c.VK_STENCIL_OP_KEEP,
        c.VK_COMPARE_OP_NEVER,
    );
    vk.cmdSetDepthBounds(cmd, 0.0, 1.0);

    vk.cmdPushConstants(
        cmd,
        shader.layout,
        c.VK_SHADER_STAGE_VERTEX_BIT,
        0,
        @sizeOf(types.PushConstants),
        &push_constants,
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
    vk.cmdBlitImage2KHR(cmd, &.{
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
