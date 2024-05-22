const std = @import("std");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");

pub const DescriptorLayoutBuilder = struct {
    bindings: std.ArrayList(c.VkDescriptorSetLayoutBinding),

    pub fn addBinding(
        self: *DescriptorLayoutBuilder,
        binding: u32,
        desc_type: c.VkDescriptorType,
    ) !void {
        try self.bindings.append(c.VkDescriptorSetLayoutBinding{
            .binding = binding,
            .descriptorCount = 1,
            .descriptorType = desc_type,
        });
    }

    pub fn clear(self: *DescriptorLayoutBuilder) void {
        self.bindings.clearRetainingCapacity();
    }

    pub fn build(
        self: *DescriptorLayoutBuilder,
        device: vk.Device,
        shader_stages: c.VkShaderStageFlags,
        next: ?*const anyopaque,
        flags: c.VkDescriptorSetLayoutCreateFlags,
    ) !vk.DescriptorSetLayout {
        for (self.bindings.items) |*b| {
            b.stageFlags |= shader_stages;
        }

        return device.createDescriptorSetLayout(&.{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = next,
            .pBindings = @ptrCast(self.bindings.items.ptr),
            .bindingCount = @intCast(self.bindings.items.len),
            .flags = flags,
        }, null);
    }
};

pub const DescriptorAllocator = struct {
    pub const PoolSizeRatio = struct {
        desc_type: c.VkDescriptorType,
        ratio: f32,
    };

    pool: vk.DescriptorPool,

    pub fn initPool(
        self: *DescriptorAllocator,
        device: vk.Device,
        max_sets: u32,
        pool_ratios: []const PoolSizeRatio,
        allocator: std.mem.Allocator,
    ) !void {
        const pool_sizes = try allocator.alloc(c.VkDescriptorPoolSize, pool_ratios.len);
        defer allocator.free(pool_sizes);

        for (pool_ratios, pool_sizes) |ratio, *size| {
            size.* = .{
                .type = ratio.desc_type,
                .descriptorCount = @intFromFloat(
                    ratio.ratio * @as(f32, @floatFromInt(max_sets)),
                ),
            };
        }

        self.pool = try device.createDescriptorPool(&.{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .flags = 0,
            .maxSets = max_sets,
            .poolSizeCount = @intCast(pool_sizes.len),
            .pPoolSizes = @ptrCast(pool_sizes.ptr),
        }, null);
    }

    pub fn clearDescriptors(self: DescriptorAllocator, device: vk.Device) void {
        _ = device.resetDescriptorPool(self.pool, 0) catch {};
    }

    pub fn destroyPool(self: DescriptorAllocator, device: vk.Device) void {
        device.destroyDescriptorPool(self.pool, null);
    }

    pub fn allocate(
        self: DescriptorAllocator,
        device: vk.Device,
        layout: vk.DescriptorSetLayout,
    ) !vk.DescriptorSet {
        return device.allocateDescriptorSet(&.{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool = self.pool,
            .descriptorSetCount = 1,
            .pSetLayouts = &layout,
        });
    }
};
