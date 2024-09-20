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
    device: vk.Device,
    shader_stages: c.VkShaderStageFlags,
    next: ?*const anyopaque,
    flags: c.VkDescriptorSetLayoutCreateFlags,
    bindings: []c.VkDescriptorSetLayoutBinding,
) !vk.DescriptorSetLayout {
    for (bindings) |*b| {
        b.stageFlags |= shader_stages;
    }

    return device.createDescriptorSetLayout(&.{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = next,
        .pBindings = @ptrCast(bindings.ptr),
        .bindingCount = @intCast(bindings.len),
        .flags = flags,
    }, null);
}

pub fn createPool(
    device: vk.Device,
    max_sets: u32,
    comptime pool_size_count: comptime_int,
    pool_ratios: *const [pool_size_count]struct {
        desc_type: c.VkDescriptorType,
        ratio: f32,
    },
) !vk.DescriptorPool {
    var pool_sizes: [pool_size_count]c.VkDescriptorPoolSize = undefined;
    for (pool_ratios, &pool_sizes) |ratio, *size| {
        size.* = .{
            .type = ratio.desc_type,
            .descriptorCount = @intFromFloat(
                ratio.ratio * @as(f32, @floatFromInt(max_sets)),
            ),
        };
    }

    return device.createDescriptorPool(&.{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = 0,
        .maxSets = max_sets,
        .poolSizeCount = @intCast(pool_sizes.len),
        .pPoolSizes = &pool_sizes,
    }, null);
}

pub fn allocate(
    pool: vk.DescriptorPool,
    device: vk.Device,
    layout: vk.DescriptorSetLayout,
) !vk.DescriptorSet {
    return device.allocateDescriptorSet(&.{
        .descriptorPool = pool,
        .layout = layout,
    });
}
