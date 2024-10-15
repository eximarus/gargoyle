const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");

const required_device_extensions: []const c.String = &.{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,

    c.VK_KHR_DYNAMIC_RENDERING_LOCAL_READ_EXTENSION_NAME,
    c.VK_EXT_SHADER_OBJECT_EXTENSION_NAME,
    c.VK_EXT_DESCRIPTOR_BUFFER_EXTENSION_NAME,

    c.VK_KHR_COPY_COMMANDS_2_EXTENSION_NAME,
    c.VK_EXT_MESH_SHADER_EXTENSION_NAME,
};

const optional_device_extensions: []const c.String = &.{
    // ray tracing
    // c.VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    // c.VK_KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME,
    // c.VK_KHR_RAY_QUERY_EXTENSION_NAME,
    // c.VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
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
    };

    var features13 = c.VkPhysicalDeviceVulkan13Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
        .pNext = &features12,
        .dynamicRendering = c.VK_TRUE,
        .synchronization2 = c.VK_TRUE,
    };

    var dynamic_rendering_local_read = c.VkPhysicalDeviceDynamicRenderingLocalReadFeaturesKHR{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_LOCAL_READ_FEATURES_KHR,
        .pNext = &features13,
        .dynamicRenderingLocalRead = c.VK_TRUE,
    };

    var shader_obj = c.VkPhysicalDeviceShaderObjectFeaturesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT,
        .pNext = &dynamic_rendering_local_read,
        .shaderObject = c.VK_TRUE,
    };

    var descriptor_buffer = c.VkPhysicalDeviceDescriptorBufferFeaturesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT,
        .pNext = &shader_obj,
        .descriptorBuffer = c.VK_TRUE,
    };

    var mesh_shader = c.VkPhysicalDeviceMeshShaderFeaturesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT,
        .pNext = &descriptor_buffer,
        .meshShader = c.VK_TRUE,
        .taskShader = c.VK_TRUE,
    };

    const layers = if (vk.enable_validation_layers) vk.validation_layers else &[_]c.String{};
    var queue_priority: f32 = 1.0;
    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &mesh_shader,
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
        .pEnabledFeatures = &c.VkPhysicalDeviceFeatures{},
    };

    var device: c.VkDevice = undefined;
    try vk.check(vk.createDevice(physical_device, &device_info, null, &device));
    vk.loadDeviceFunctions(device);
    return device;
}
