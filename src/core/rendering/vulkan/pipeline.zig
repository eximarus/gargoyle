const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const types = @import("types.zig");

pub const BlendParameters = struct {
    src_factor: c.VkBlendFactor,
    dst_factor: c.VkBlendFactor,
    op: c.VkBlendOp,
};

pub const Pipeline = struct {
    pipline: c.VkPipeline,
    layout: c.VkPipelineLayout,
    descriptor_set_layouts: []const c.VkDescriptorSetLayout,
    bind_point: c.VkPipelineBindPoint,
};

inline fn createDescriptorSetLayoutBindless(
    device: c.VkDevice,
    bindings: []const c.VkDescriptorSetLayoutBinding,
) !c.VkDescriptorSetLayout {
    var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;

    try vk.check(vk.createDescriptorSetLayout(
        device,
        &c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = &c.VkDescriptorSetLayoutBindingFlagsCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
                .bindingCount = 1,
                .pBindingFlags = @ptrCast(&(c.VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT |
                    c.VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT |
                    c.VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT)),
            },
            .flags = c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT,
            .bindingCount = @intCast(bindings.len),
            .pBindings = bindings.ptr,
        },
        null,
        &descriptor_set_layout,
    ));
    return descriptor_set_layout;
}

pub fn createGraphics(
    comptime path: []const u8,
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    device: c.VkDevice,
    color_attachment_format: c.VkFormat,
    depth_format: c.VkFormat,
    options: struct {
        vs_main: c.String = "vsMain",
        fs_main: c.String = "fsMain",
    },
) !Pipeline {
    const f = try std.fs.cwd().openFile(path, .{});
    defer f.close();

    const size = try f.getEndPos();
    const buf = try arena.alloc(u8, size);

    _ = try f.readAll(buf);

    const shader_code = std.mem.bytesAsSlice(
        u32,
        @as([]align(@alignOf(u32)) const u8, @alignCast(buf)),
    );

    const pc_range = c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(types.PushConstants),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };

    var module: c.VkShaderModule = undefined;
    try vk.check(vk.createShaderModule(
        device,
        &c.VkShaderModuleCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = @intCast(size),
            .pCode = @ptrCast(shader_code.ptr),
        },
        null,
        &module,
    ));

    var descriptor_set_layout = try createDescriptorSetLayoutBindless(
        device,
        &[_]c.VkDescriptorSetLayoutBinding{
            c.VkDescriptorSetLayoutBinding{
                .binding = 0,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = vk.max_bindless_resources,
                .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            },
        },
    );

    var layout: c.VkPipelineLayout = undefined;
    try vk.check(vk.createPipelineLayout(device, &c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &pc_range,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
    }, null, &layout));

    var handle: c.VkPipeline = undefined;
    try vk.check(vk.createGraphicsPipelines(device, null, 1, &c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .pNext = &c.VkPipelineRenderingCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &color_attachment_format,
            .depthAttachmentFormat = depth_format,
        },
        .stageCount = 2,
        .pStages = &[2]c.VkPipelineShaderStageCreateInfo{
            c.VkPipelineShaderStageCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                .module = module,
                .pName = options.vs_main,
            },
            c.VkPipelineShaderStageCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                .module = module,
                .pName = options.fs_main,
            },
        },
        .pVertexInputState = &c.VkPipelineVertexInputStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        },
        .pInputAssemblyState = &c.VkPipelineInputAssemblyStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .primitiveRestartEnable = c.VK_FALSE,
        },
        .pViewportState = &c.VkPipelineViewportStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .scissorCount = 1,
        },
        .pRasterizationState = &c.VkPipelineRasterizationStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .lineWidth = 1.0,
            .cullMode = c.VK_CULL_MODE_BACK_BIT,
            .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        },
        .pMultisampleState = &c.VkPipelineMultisampleStateCreateInfo{
            // disabled
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = c.VK_FALSE,
            .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        },
        .pColorBlendState = &c.VkPipelineColorBlendStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = c.VK_FALSE,
            .logicOp = c.VK_LOGIC_OP_COPY,
            .attachmentCount = 1,
            .pAttachments = &c.VkPipelineColorBlendAttachmentState{
                .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
                    c.VK_COLOR_COMPONENT_G_BIT |
                    c.VK_COLOR_COMPONENT_B_BIT |
                    c.VK_COLOR_COMPONENT_A_BIT,
            },
        },
        .pDepthStencilState = &c.VkPipelineDepthStencilStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .depthBoundsTestEnable = c.VK_FALSE,
            .stencilTestEnable = c.VK_FALSE,
            .front = .{},
            .back = .{},
            .minDepthBounds = 0.0,
            .maxDepthBounds = 1.0,
        },
        .layout = layout,
        .pDynamicState = &c.VkPipelineDynamicStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = 9,
            .pDynamicStates = &[9]c.VkDynamicState{
                c.VK_DYNAMIC_STATE_VIEWPORT,
                c.VK_DYNAMIC_STATE_SCISSOR,
                c.VK_DYNAMIC_STATE_PRIMITIVE_TOPOLOGY,
                c.VK_DYNAMIC_STATE_DEPTH_TEST_ENABLE,
                c.VK_DYNAMIC_STATE_DEPTH_WRITE_ENABLE,
                c.VK_DYNAMIC_STATE_DEPTH_COMPARE_OP,
                c.VK_DYNAMIC_STATE_POLYGON_MODE_EXT,
                c.VK_DYNAMIC_STATE_COLOR_BLEND_ENABLE_EXT,
                c.VK_DYNAMIC_STATE_COLOR_BLEND_EQUATION_EXT,
            },
        },
    }, null, &handle));

    const descriptor_set_layouts = try gpa.alloc(c.VkDescriptorSetLayout, 1);
    descriptor_set_layouts[0] = descriptor_set_layout;

    return Pipeline{
        .pipline = handle,
        .bind_point = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .layout = layout,
        .descriptor_set_layouts = descriptor_set_layouts,
    };
}
