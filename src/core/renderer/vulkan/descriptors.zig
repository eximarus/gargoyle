const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");

pub fn layoutBinding(
    binding: u32,
    desc_type: c.VkDescriptorType,
) c.VkDescriptorSetLayoutBinding {
    return .{
        .binding = binding,
        .descriptorCount = 1,
        .descriptorType = desc_type,
    };
}

pub fn createLayout(
    device: c.VkDevice,
    shader_stages: c.VkShaderStageFlags,
    next: ?*const anyopaque,
    flags: c.VkDescriptorSetLayoutCreateFlags,
    bindings: []c.VkDescriptorSetLayoutBinding,
) !c.VkDescriptorSetLayout {
    for (bindings) |*b| {
        b.stageFlags |= shader_stages;
    }

    var layout: c.VkDescriptorSetLayout = undefined;
    try vk.check(vk.createDescriptorSetLayout(
        device,
        &.{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = next,
            .pBindings = @ptrCast(bindings.ptr),
            .bindingCount = @intCast(bindings.len),
            .flags = flags,
        },
        null,
        &layout,
    ));
    return layout;
}

pub fn createPool(
    device: c.VkDevice,
    max_sets: u32,
    comptime pool_size_count: comptime_int,
    pool_ratios: *const [pool_size_count]struct {
        desc_type: c.VkDescriptorType,
        ratio: f32,
    },
) !c.VkDescriptorPool {
    var pool_sizes: [pool_size_count]c.VkDescriptorPoolSize = undefined;
    for (pool_ratios, &pool_sizes) |ratio, *size| {
        size.* = .{
            .type = ratio.desc_type,
            .descriptorCount = @intFromFloat(
                ratio.ratio * @as(f32, @floatFromInt(max_sets)),
            ),
        };
    }

    var pool: c.VkDescriptorPool = undefined;
    try vk.check(vk.createDescriptorPool(device, &.{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = 0,
        .maxSets = max_sets,
        .poolSizeCount = @intCast(pool_sizes.len),
        .pPoolSizes = &pool_sizes,
    }, null, &pool));
    return pool;
}

pub fn allocate(
    pool: c.VkDescriptorPool,
    device: c.VkDevice,
    layout: c.VkDescriptorSetLayout,
) !c.VkDescriptorSet {
    var set: c.VkDescriptorSet = undefined;
    try vk.check(vk.allocateDescriptorSets(device, &.{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = pool,
        .descriptorSetCount = 1,
        .pSetLayouts = &layout,
    }, &set));
    return set;
}
