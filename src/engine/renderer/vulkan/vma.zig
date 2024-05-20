const c = @import("../../c.zig");
const vk = @import("vulkan.zig");

pub inline fn createAllocator(info: *const struct {
    flags: c.VmaAllocatorCreateFlags,
    physical_device: vk.PhysicalDevice,
    device: vk.Device,
    preferred_large_heap_block_size: c.VkDeviceSize = 0,
    allocation_callbacks: ?*const c.VkAllocationCallbacks = null,
    device_memory_callbacks: ?*const c.VmaDeviceMemoryCallbacks = null,
    instance: vk.Instance,
}) !c.VmaAllocator {
    var vma_allocator: c.VmaAllocator = undefined;
    try vk.check(vk.result(c.vmaCreateAllocator(&.{
        .flags = info.flags,
        .physicalDevice = info.physical_device.handle,
        .device = info.device.handle,
        .preferredLargeHeapBlockSize = info.preferred_large_heap_block_size,
        .pAllocationCallbacks = info.allocation_callbacks,
        .pDeviceMemoryCallbacks = info.device_memory_callbacks,
        .instance = info.instance.handle,
        .pVulkanFunctions = &.{
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
        },
    }, &vma_allocator)));
    return vma_allocator;
}
