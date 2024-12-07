const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");

const required_device_extensions: []const c.String = &.{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

const optional_device_extensions: []const c.String = &.{
    // ray tracing
    // c.VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    // c.VK_KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME,
    // c.VK_KHR_RAY_QUERY_EXTENSION_NAME,
    // c.VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
    //
    // c.VK_EXT_MESH_SHADER_EXTENSION_NAME,
    // c.VK_KHR_FRAGMENT_SHADING_RATE_EXTENSION_NAME
};

pub fn create(
    physical_device: c.VkPhysicalDevice,
    graphics_queue_family: u32,
) !c.VkDevice {
    var features11 = c.VkPhysicalDeviceVulkan11Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
        .variablePointers = c.VK_TRUE,
        .variablePointersStorageBuffer = c.VK_TRUE,
    };

    var features12 = c.VkPhysicalDeviceVulkan12Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        .pNext = &features11,
        .bufferDeviceAddress = c.VK_TRUE,
        .descriptorIndexing = c.VK_TRUE,
        .descriptorBindingPartiallyBound = c.VK_TRUE,
        .runtimeDescriptorArray = c.VK_TRUE,
        .descriptorBindingVariableDescriptorCount = c.VK_TRUE,
        .drawIndirectCount = c.VK_TRUE,

        .descriptorBindingSampledImageUpdateAfterBind = c.VK_TRUE,
    };

    var features13 = c.VkPhysicalDeviceVulkan13Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
        .pNext = &features12,
        .dynamicRendering = c.VK_TRUE,
        .synchronization2 = c.VK_TRUE,
    };

    const layers = if (vk.enable_validation_layers) vk.validation_layers else &[_]c.String{};
    var queue_priority: f32 = 1.0;
    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &features13,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = graphics_queue_family,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        },
        .enabledExtensionCount = @intCast(required_device_extensions.len),
        .ppEnabledExtensionNames = @ptrCast(required_device_extensions.ptr),
        .enabledLayerCount = @intCast(layers.len),
        .ppEnabledLayerNames = @ptrCast(layers.ptr),
        .pEnabledFeatures = &c.VkPhysicalDeviceFeatures{
            .multiDrawIndirect = c.VK_TRUE,
            .drawIndirectFirstInstance = c.VK_TRUE,
        },
    };

    var device: c.VkDevice = undefined;
    try vk.check(vk.createDevice(physical_device, &device_info, null, &device));
    vk.loadDeviceFunctions(device);
    return device;
}
