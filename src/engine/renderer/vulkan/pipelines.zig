const std = @import("std");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");
const vkinit = @import("vkinit.zig");

pub fn loadShaderModule(
    comptime path: []const u8,
    device: vk.Device,
) !vk.ShaderModule {
    const shader_code = std.mem.bytesAsSlice(
        u32,
        @as([]align(@alignOf(u32)) const u8, @alignCast(@embedFile(path))),
    );

    return device.createShaderModule(&.{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = @intCast(shader_code.len * @sizeOf(u32)),
        .pCode = @ptrCast(shader_code.ptr),
    }, null);
}

pub inline fn pipeline(
    device: vk.Device,
    info: *const struct {
        shaders: struct {
            vertex_shader: vk.ShaderModule,
            fragment_shader: vk.ShaderModule,
        },
        pipeline_layout: vk.PipelineLayout,
        input_topology: c.VkPrimitiveTopology,
        polygon_mode: c.VkPolygonMode,
        cull_mode: struct {
            flags: c.VkCullModeFlags,
            front_face: c.VkFrontFace,
        },
        blending: enum { none, additive, alpha },
        color_attachment_format: c.VkFormat,
        depth_format: c.VkFormat,
        depth_test: ?struct {
            depth_write_enable: bool,
            op: c.VkCompareOp,
        },
    },
) !vk.Pipeline {
    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{
        vkinit.pipelineShaderStageCreateInfo(
            c.VK_SHADER_STAGE_VERTEX_BIT,
            info.shaders.vertex_shader,
            "main",
        ),
        vkinit.pipelineShaderStageCreateInfo(
            c.VK_SHADER_STAGE_FRAGMENT_BIT,
            info.shaders.fragment_shader,
            "main",
        ),
    };

    var color_blend_attachment = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
            c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT |
            c.VK_COLOR_COMPONENT_A_BIT,
    };

    switch (info.blending) {
        .none => {
            color_blend_attachment.blendEnable = c.VK_FALSE;
        },
        .additive => {
            color_blend_attachment.blendEnable = c.VK_TRUE;
            color_blend_attachment.srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE;
            color_blend_attachment.dstColorBlendFactor = c.VK_BLEND_FACTOR_DST_ALPHA;
            color_blend_attachment.colorBlendOp = c.VK_BLEND_OP_ADD;
            color_blend_attachment.srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE;
            color_blend_attachment.dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO;
            color_blend_attachment.alphaBlendOp = c.VK_BLEND_OP_ADD;
        },
        .alpha => {
            color_blend_attachment.blendEnable = c.VK_TRUE;
            color_blend_attachment.srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA;
            color_blend_attachment.dstColorBlendFactor = c.VK_BLEND_FACTOR_DST_ALPHA;
            color_blend_attachment.colorBlendOp = c.VK_BLEND_OP_ADD;
            color_blend_attachment.srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE;
            color_blend_attachment.dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO;
            color_blend_attachment.alphaBlendOp = c.VK_BLEND_OP_ADD;
        },
    }

    var depth_stencil = c.VkPipelineDepthStencilStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthBoundsTestEnable = c.VK_FALSE,
        .stencilTestEnable = c.VK_FALSE,
        .front = .{},
        .back = .{},
        .minDepthBounds = 0.0,
        .maxDepthBounds = 1.0,
    };

    if (info.depth_test) |depth_test| {
        depth_stencil.depthTestEnable = c.VK_TRUE;
        depth_stencil.depthWriteEnable = vk.vkBool32(depth_test.depth_write_enable);
        depth_stencil.depthCompareOp = depth_test.op;
    } else {
        depth_stencil.depthTestEnable = c.VK_FALSE;
        depth_stencil.depthWriteEnable = c.VK_FALSE;
        depth_stencil.depthCompareOp = c.VK_COMPARE_OP_NEVER;
    }

    return device.createGraphicsPipelines(null, &.{
        c.VkGraphicsPipelineCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .pNext = &c.VkPipelineRenderingCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
                .colorAttachmentCount = 1,
                .pColorAttachmentFormats = &info.color_attachment_format,
                .depthAttachmentFormat = info.depth_format,
            },
            .stageCount = @intCast(shader_stages.len),
            .pStages = &shader_stages,
            .pVertexInputState = &.{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            },
            .pInputAssemblyState = &.{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                .topology = info.input_topology,
                .primitiveRestartEnable = c.VK_FALSE,
            },
            .pViewportState = &.{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                .viewportCount = 1,
                .scissorCount = 1,
            },
            .pRasterizationState = &.{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                .polygonMode = info.polygon_mode,
                .lineWidth = 1.0,
                .cullMode = info.cull_mode.flags,
                .frontFace = info.cull_mode.front_face,
            },
            .pMultisampleState = &.{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                .sampleShadingEnable = c.VK_FALSE,
                .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
                .minSampleShading = 1.0,
                .alphaToCoverageEnable = c.VK_FALSE,
                .alphaToOneEnable = c.VK_FALSE,
            },
            .pColorBlendState = &.{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                .logicOpEnable = c.VK_FALSE,
                .logicOp = c.VK_LOGIC_OP_COPY,
                .attachmentCount = 1,
                .pAttachments = &color_blend_attachment,
            },
            .pDepthStencilState = &depth_stencil,
            .layout = info.pipeline_layout,
            .pDynamicState = &.{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                .dynamicStateCount = 2,
                .pDynamicStates = &[2]c.VkDynamicState{
                    c.VK_DYNAMIC_STATE_VIEWPORT,
                    c.VK_DYNAMIC_STATE_SCISSOR,
                },
            },
        },
    }, null);
}
