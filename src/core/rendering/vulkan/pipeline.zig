const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const types = @import("types.zig");

pub const Pipeline = struct {
    pipline: c.VkPipeline,
    pipeline_layout: c.VkPipelineLayout,
    descriptor_set_layouts: []const c.VkDescriptorSetLayout,
    bind_point: c.VkPipelineBindPoint,
};

fn createDescriptorSetLayoutBindless(
    device: c.VkDevice,
    bindings: []c.VkDescriptorSetLayoutBinding,
) !c.VkDescriptorSetLayout {
    var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;
    try vk.check(vk.createDescriptorSetLayout(
        device,
        &c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = &c.VkDescriptorSetLayoutBindingFlagsCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
                .bindingCount = 1,
                .pBindingFlags = &c.VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT |
                    c.VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT |
                    c.VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT,
            },
            .flags = c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT,
            .bindingCount = bindings.len,
            .pBindings = bindings.ptr,
        },
        null,
        &descriptor_set_layout,
    ));
    return descriptor_set_layout;
}

fn createDescriptorSetLayout(
    device: c.VkDevice,
    bindings: []c.VkDescriptorSetLayoutBinding,
) !c.VkDescriptorSetLayout {
    var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;
    try vk.check(vk.createDescriptorSetLayout(
        device,
        &c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .bindingCount = bindings.len,
            .pBindings = bindings.ptr,
        },
        null,
        &descriptor_set_layout,
    ));
    return descriptor_set_layout;
}

pub fn create(
    comptime path: []const u8,
    arena: std.mem.Allocator,
    device: c.VkDevice,
    options: struct {
        vs_main: c.String = "vsMain",
        fs_main: c.String = "fsMain",
        comp_main: c.String = "compMain",
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
        c.VkShaderModuleCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = @intCast(size),
            .pCode = @ptrCast(shader_code.ptr),
        },
        null,
        &module,
    ));

    const comp_stage = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_COMPUTE_BIT,
        .module = module,
        .pName = options.comp_main,
    };

    const vs_stage = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = module,
        .pName = options.vs_main,
    };

    const fs_stage = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = module,
        .pName = options.fs_main,
    };

    var descriptor_set_layout = try createDescriptorSetLayoutBindless(
        device,
        &[_]c.VkDescriptorSetLayoutBinding{
            c.VkDescriptorSetLayoutBinding{
                .binding = 0,
                .descriptorCount = std.math.maxInt(u16),
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
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

    return Pipeline{};
}
