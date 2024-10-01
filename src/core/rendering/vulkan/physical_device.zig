const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");

pub fn pick(
    arena: std.mem.Allocator,
    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,
) !struct {
    gpu: c.VkPhysicalDevice,
    graphics_queue_family: u32,
} {
    var gpu_count: u32 = undefined;
    try vk.check(vk.enumeratePhysicalDevices(instance, &gpu_count, null));
    std.debug.assert(gpu_count != 0);

    const gpus = try arena.alloc(c.VkPhysicalDevice, gpu_count);
    try vk.check(vk.enumeratePhysicalDevices(instance, &gpu_count, gpus.ptr));

    var map = std.AutoArrayHashMap(u32, c.VkPhysicalDevice).init(arena);
    for (gpus) |gpu| {
        const score = rateDeviceSuitability(gpu);
        if (score > 0) {
            try map.put(score, gpu);
        }
    }

    if (map.count() == 0) {
        std.debug.panic("No suitable physical device found", .{});
    }

    const C = struct {
        keys: []u32,

        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            return ctx.keys[b_index] < ctx.keys[a_index];
        }
    };
    map.sort(C{ .keys = map.keys() });

    var physical_device: c.VkPhysicalDevice = undefined;
    var graphics_queue_family: ?u32 = null;
    for (map.values()) |gpu| {
        physical_device = gpu;
        var prop_count: u32 = undefined;
        vk.getPhysicalDeviceQueueFamilyProperties(gpu, &prop_count, null);
        const queue_family_properties = try arena.alloc(c.VkQueueFamilyProperties, prop_count);
        vk.getPhysicalDeviceQueueFamilyProperties(gpu, &prop_count, queue_family_properties.ptr);

        for (queue_family_properties, 0..) |prop, i| {
            const index: u32 = @intCast(i);
            var supports_present: c.VkBool32 = undefined;
            try vk.check(vk.getPhysicalDeviceSurfaceSupportKHR(gpu, index, surface, &supports_present));
            const graphics_bit = prop.queueFlags &
                c.VK_QUEUE_GRAPHICS_BIT != 0;
            if (graphics_bit and supports_present == c.VK_TRUE) {
                graphics_queue_family = index;
                break;
            }
        }
    }

    return .{
        .gpu = physical_device,
        .graphics_queue_family = graphics_queue_family orelse {
            std.log.err("Did not find suitable queue which supports graphics, compute and presentation.\n", .{});
            return error.NoDeviceFound;
        },
    };
}

fn rateDeviceSuitability(device: c.VkPhysicalDevice) u32 {
    var features = c.VkPhysicalDeviceFeatures2{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
    };
    vk.getPhysicalDeviceFeatures2(device, &features);

    if (features.features.geometryShader == 0) {
        return 0;
    }

    var props = c.VkPhysicalDeviceProperties2{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
    };
    vk.getPhysicalDeviceProperties2(device, &props);

    var score: u32 = 0;
    if (props.properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
        score += 1000;
    }

    score += props.properties.limits.maxImageDimension2D;
    return score;
}
