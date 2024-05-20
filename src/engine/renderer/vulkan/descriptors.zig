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
            .descriptorPool = self.pool.handle,
            .descriptorSetCount = 1,
            .pSetLayouts = &layout.handle,
        });
    }
};
// UID-VkShaderModuleCreateInfo-pCode-07912(ERROR / SPEC): msgNum: 979894520 - Validation Error: [ VUID-VkShaderModuleCreateInfo-pCode-07912 ] | MessageID = 0x3a6800f8 | vkCreateShaderModule(): pCreateInfo->pCode doesn't point to a SPIR-V module. The Vulkan spec states: If the VK_NV_glsl_shader extension is not enabled, pCode must be a pointer to SPIR-V code (https://vulkan.lunarg.com/doc/view/1.3.283.0/linux/1.3-extensions/vkspec.html#VUID-VkShaderModuleCreateInfo-pCode-07912)
//     Objects: 0
// VUID-VkShaderModuleCreateInfo-pCode-08737(ERROR / SPEC): msgNum: -1520283006 - Validation Error: [ VUID-VkShaderModuleCreateInfo-pCode-08737 ] | MessageID = 0xa5625282 | vkCreateShaderModule(): pCreateInfo->pCode (spirv-val produced an error):
// Invalid SPIR-V magic number. The Vulkan spec states: If pCode is a pointer to SPIR-V code, pCode must adhere to the validation rules described by the Validation Rules within a Module section of the SPIR-V Environment appendix (https://vulkan.lunarg.com/doc/view/1.3.283.0/linux/1.3-extensions/vkspec.html#VUID-VkShaderModuleCreateInfo-pCode-08737)
//     Objects: 0
