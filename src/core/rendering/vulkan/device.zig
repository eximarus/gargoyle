const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const pickPhysicalDevice = @import("physical_device.zig").pick;

const common = @import("common.zig");

const required_device_extensions: []const c.String = &.{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    c.VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
    c.VK_EXT_SHADER_OBJECT_EXTENSION_NAME,
    c.VK_KHR_SYNCHRONIZATION_2_EXTENSION_NAME,
    c.VK_KHR_COPY_COMMANDS_2_EXTENSION_NAME,
    c.VK_EXT_MESH_SHADER_EXTENSION_NAME,
};

const optional_device_extensions: []const c.String = &.{};

pub fn create(
    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,
    arena: std.mem.Allocator,
) !struct {
    gpu: c.VkPhysicalDevice,
    graphics_queue_family: u32,
    device: c.VkDevice,
} {
    const r = try pickPhysicalDevice(arena, instance, surface);
    const physical_device = r.gpu;
    const graphics_queue_family = r.graphics_queue_family;

    var device_ext_count: u32 = undefined;
    try vk.check(vk.enumerateDeviceExtensionProperties(physical_device, null, &device_ext_count, null));
    const device_extensions = try arena.alloc(c.VkExtensionProperties, device_ext_count);
    try vk.check(vk.enumerateDeviceExtensionProperties(physical_device, null, &device_ext_count, device_extensions.ptr));

    try common.validateExtensions(device_extensions, required_device_extensions);
    var features11 = c.VkPhysicalDeviceVulkan11Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
        .variablePointers = c.VK_TRUE,
        .variablePointersStorageBuffer = c.VK_TRUE,
    };

    var features12 = c.VkPhysicalDeviceVulkan12Features{
        .pNext = &features11,
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        .bufferDeviceAddress = c.VK_TRUE,
        .descriptorIndexing = c.VK_TRUE,
    };

    var shader_obj = c.VkPhysicalDeviceShaderObjectFeaturesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT,
        .pNext = &features12,
        .shaderObject = c.VK_TRUE,
    };

    var synchronization2 = c.VkPhysicalDeviceSynchronization2FeaturesKHR{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES_KHR,
        .pNext = &shader_obj,
        .synchronization2 = c.VK_TRUE,
    };

    var mesh_shader = c.VkPhysicalDeviceMeshShaderFeaturesEXT{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT,
        .pNext = &synchronization2,
        .meshShader = c.VK_TRUE,
        .taskShader = c.VK_TRUE,
    };

    var dynamic_rendering = c.VkPhysicalDeviceDynamicRenderingFeaturesKHR{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES_KHR,
        .pNext = &mesh_shader,
        .dynamicRendering = c.VK_TRUE,
    };

    const layers = if (vk.enable_validation_layers) vk.validation_layers else &[_]c.String{};
    var queue_priority: f32 = 1.0;
    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &dynamic_rendering,
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
    return .{
        .gpu = physical_device,
        .graphics_queue_family = graphics_queue_family,
        .device = device,
    };
}
