const std = @import("std");
const config = @import("config");
const c = @import("c");
const platform = @import("platform");
const vk = @import("vulkan.zig");
const common = @import("common.zig");

const required_device_extensions: []const common.CString = &.{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    c.VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
    c.VK_KHR_SYNCHRONIZATION_2_EXTENSION_NAME,
    c.VK_KHR_COPY_COMMANDS_2_EXTENSION_NAME,
    c.VK_EXT_SHADER_OBJECT_EXTENSION_NAME,
    c.VK_EXT_MESH_SHADER_EXTENSION_NAME,
};

const optional_device_extensions: []const common.CString = &.{
    // these dont work in wsl
    // ray tracing
    c.VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    c.VK_KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME,
    // required for VK_KHR_acceleration_structure
    c.VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
};

const Out = struct { vk.PhysicalDevice, u32, vk.Device };

pub fn create(
    instance: vk.Instance,
    surface: vk.SurfaceKHR,
    arena: std.mem.Allocator,
) !Out {
    var physical_device: vk.PhysicalDevice = undefined;
    var graphics_queue_family: ?u32 = null;

    const gpus = try instance.enumeratePhysicalDevices(arena);
    for (gpus) |gpu| {
        physical_device = gpu;
        const queue_family_properties =
            try gpu.getQueueFamilyProperties(arena);
        for (queue_family_properties, 0..) |prop, i| {
            const index: u32 = @intCast(i);
            const supports_present =
                try gpu.getSurfaceSupportKHR(index, surface);
            const graphics_bit = prop.queueFlags &
                c.VK_QUEUE_GRAPHICS_BIT != 0;
            if (graphics_bit and supports_present) {
                graphics_queue_family = index;

                // var rt_props = c.VkPhysicalDeviceRayTracingPipelinePropertiesKHR{
                //     .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR,
                // };
                //
                // var accel_props = c.VkPhysicalDeviceAccelerationStructurePropertiesKHR{
                //     .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR,
                //     .pNext = &rt_props,
                // };

                if (gpu.getProperties2(null).deviceType ==
                    c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
                {
                    break;
                }
            }
        }
    }
    if (graphics_queue_family == null) {
        std.log.err("Did not find suitable queue which supports graphics, compute and presentation.\n", .{});
        return error.NoDeviceFound;
    }
    const device_extensions =
        try physical_device.enumerateDeviceExtensionProperties(arena);

    try common.validateExtensions(device_extensions, required_device_extensions);
    var features11 = c.VkPhysicalDeviceVulkan11Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
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

    var queue_priority: f32 = 1.0;
    const device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &dynamic_rendering,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = graphics_queue_family.?,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        },
        .enabledExtensionCount = @intCast(required_device_extensions.len),
        .ppEnabledExtensionNames = @ptrCast(required_device_extensions.ptr),
        .pEnabledFeatures = &.{},
    };
    const device = try physical_device.createDevice(&device_info, null);
    return Out{ physical_device, graphics_queue_family.?, device };
}
