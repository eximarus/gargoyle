const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const vk = @import("vulkan.zig");
const config = @import("config");
const platform = @import("platform");
const log = std.log.scoped(.vulkan);

const app_ver = std.SemanticVersion.parse(config.app_ver) catch unreachable;

const required_instance_extensions: []const c.String = &.{
    platform.vk.surface_ext,
    c.VK_KHR_SURFACE_EXTENSION_NAME,
};

pub fn create(arena: std.mem.Allocator) !c.VkInstance {
    var app_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = @ptrCast(config.app_name),
        .applicationVersion = c.VK_MAKE_VERSION(app_ver.major, app_ver.minor, app_ver.patch),
        .pEngineName = "gargoyle",
        .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .apiVersion = c.VK_MAKE_VERSION(1, 3, 276),
    };

    var extensions = std.ArrayList(c.String).init(arena);
    try extensions.appendSlice(required_instance_extensions);
    if (vk.enable_validation_layers) {
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    var flags: c.VkInstanceCreateFlags = 0;
    if (@hasDecl(c, "VK_KHR_portability_enumeration")) {
        try extensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);
        flags |= c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;
    }

    const layers = if (vk.enable_validation_layers) vk.validation_layers else &[_]c.String{};
    var instance_create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .flags = flags,
        .enabledExtensionCount = @intCast(extensions.items.len),
        .ppEnabledExtensionNames = @ptrCast(extensions.items.ptr),
        .enabledLayerCount = @intCast(layers.len),
        .ppEnabledLayerNames = @ptrCast(layers.ptr),
    };

    var instance: c.VkInstance = undefined;
    try vk.check(vk.createInstance(&instance_create_info, null, &instance));
    vk.loadInstanceFunctions(instance);
    return instance;
}
