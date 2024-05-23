const std = @import("std");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");

pub const Allocation = c.VmaAllocation;
pub const Pool = c.VmaPool;
pub const DefragmentationContext = c.VmaDefragmentationContext;
pub const VirtualAllocation = c.VmaVirtualAllocation;

pub inline fn getVulkanFunctions() c.VmaVulkanFunctions {
    return .{
        // 1.0
        .vkGetInstanceProcAddr = c.vkGetInstanceProcAddr,
        .vkGetDeviceProcAddr = c.vkGetDeviceProcAddr,
        .vkGetPhysicalDeviceProperties = c.vkGetPhysicalDeviceProperties,
        .vkGetPhysicalDeviceMemoryProperties = c.vkGetPhysicalDeviceMemoryProperties,
        .vkAllocateMemory = c.vkAllocateMemory,
        .vkFreeMemory = c.vkFreeMemory,
        .vkMapMemory = c.vkMapMemory,
        .vkUnmapMemory = c.vkUnmapMemory,
        .vkFlushMappedMemoryRanges = c.vkFlushMappedMemoryRanges,
        .vkInvalidateMappedMemoryRanges = c.vkInvalidateMappedMemoryRanges,
        .vkBindBufferMemory = c.vkBindBufferMemory,
        .vkBindImageMemory = c.vkBindImageMemory,
        .vkGetBufferMemoryRequirements = c.vkGetBufferMemoryRequirements,
        .vkGetImageMemoryRequirements = c.vkGetImageMemoryRequirements,
        .vkCreateBuffer = c.vkCreateBuffer,
        .vkDestroyBuffer = c.vkDestroyBuffer,
        .vkCreateImage = c.vkCreateImage,
        .vkDestroyImage = c.vkDestroyImage,
        .vkCmdCopyBuffer = c.vkCmdCopyBuffer,

        // 1.1
        .vkGetBufferMemoryRequirements2KHR = c.vkGetBufferMemoryRequirements2,
        .vkGetImageMemoryRequirements2KHR = c.vkGetImageMemoryRequirements2,
        .vkBindBufferMemory2KHR = c.vkBindBufferMemory2,
        .vkBindImageMemory2KHR = c.vkBindImageMemory2,
        .vkGetPhysicalDeviceMemoryProperties2KHR = c.vkGetPhysicalDeviceMemoryProperties2,

        // 1.3
        .vkGetDeviceBufferMemoryRequirements = c.vkGetDeviceBufferMemoryRequirements,
        .vkGetDeviceImageMemoryRequirements = c.vkGetDeviceImageMemoryRequirements,
    };
}

pub inline fn createAllocator(info: *const c.VmaAllocatorCreateInfo) !Allocator {
    var vma_allocator: Allocator = undefined;
    try vk.check(vk.result(c.vmaCreateAllocator(info, @ptrCast(&vma_allocator))));
    return vma_allocator;
}

pub const Allocator = *align(@alignOf(c.VmaAllocator)) opaque {
    pub inline fn handle(self: Allocator) c.VmaAllocator {
        return @ptrCast(self);
    }

    pub inline fn createImage(
        self: Allocator,
        image_create_info: *const c.VkImageCreateInfo,
        allocation_create_info: *const c.VmaAllocationCreateInfo,
        allocation_info: ?*c.VmaAllocationInfo,
    ) !struct { vk.Image, Allocation } {
        var image: vk.Image = undefined;
        var allocation: Allocation = undefined;
        try vk.check(vk.result(c.vmaCreateImage(
            self.handle(),
            image_create_info,
            allocation_create_info,
            &image,
            &allocation,
            allocation_info,
        )));
        return .{ image, allocation };
    }

    pub inline fn destroyImage(
        self: Allocator,
        image: vk.Image,
        allocation: Allocation,
    ) void {
        c.vmaDestroyImage(
            self.handle(),
            image,
            allocation,
        );
    }

    pub inline fn createBuffer(
        self: Allocator,
        buffer_create_info: *const c.VkBufferCreateInfo,
        allocation_create_info: *const c.VmaAllocationCreateInfo,
        allocation_info: ?*c.VmaAllocationInfo,
    ) !struct { vk.Buffer, Allocation } {
        var buffer: vk.Buffer = undefined;
        var allocation: Allocation = undefined;

        try vk.check(vk.result(c.vmaCreateBuffer(
            self.handle(),
            buffer_create_info,
            allocation_create_info,
            &buffer,
            &allocation,
            allocation_info,
        )));
        return .{ buffer, allocation };
    }

    pub inline fn destroyBuffer(
        self: Allocator,
        buffer: vk.Buffer,
        allocation: Allocation,
    ) void {
        c.vmaDestroyBuffer(self.handle(), buffer, allocation);
    }

    pub inline fn mapMemory(self: Allocator, allocation: Allocation) !*anyopaque {
        var data: ?*anyopaque = undefined;

        try vk.check(vk.result(c.vmaMapMemory(
            self.handle(),
            allocation,
            &data,
        )));

        return data orelse error.VmaMappedToNull;
    }

    pub inline fn unmapMemory(self: Allocator, allocation: Allocation) void {
        c.vmaUnmapMemory(self.handle(), allocation);
    }

    pub inline fn destroy(self: Allocator) void {
        c.vmaDestroyAllocator(self.handle());
    }
};

pub const VirtualBlock = *align(@alignOf(c.VmaVirtualBlock)) opaque {};
