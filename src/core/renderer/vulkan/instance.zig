const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const vk = @import("vulkan.zig");
const config = @import("config");
const common = @import("common.zig");
const SystemInfo = @import("SystemInfo.zig");
const platform = @import("platform");
const log = std.log.scoped(.vulkan);

const app_ver = std.SemanticVersion.parse(config.app_ver) catch unreachable;

const Out = struct {
    c.VkInstance,
    c.VkDebugUtilsMessengerEXT,
};

const validation_layers: []const c.String = &.{
    "VK_LAYER_KHRONOS_validation",
};
const enable_validation_layers = builtin.mode == .Debug;

const required_instance_extensions: []const c.String = &.{
    platform.vk.surface_ext,
    c.VK_KHR_SURFACE_EXTENSION_NAME,
    c.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
};

pub fn create(arena: std.mem.Allocator) !Out {
    var app_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = @ptrCast(config.app_name),
        .applicationVersion = c.VK_MAKE_VERSION(app_ver.major, app_ver.minor, app_ver.patch),
        .pEngineName = "gargoyle",
        .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .apiVersion = c.VK_MAKE_VERSION(1, 2, 197), // TODO choose appropriate version
    };

    var extensions = std.ArrayList(c.String).init(arena);
    try extensions.appendSlice(required_instance_extensions);
    if (enable_validation_layers) {
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    var flags: c.VkInstanceCreateFlags = 0;
    if (@hasDecl(c, "VK_KHR_portability_enumeration")) {
        try extensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);
        flags |= c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;
    }

    const layers = if (enable_validation_layers) validation_layers else &[_]c.String{};
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

    const self = Out{
        instance,
        null,
    };

    // try vk.check(vk.createDebugUtilsMessengerEXT(
    //     self[0],
    //     &.{
    //         .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
    //         .pNext = null,
    //         .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
    //             c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
    //         .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
    //             c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
    //             c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
    //         .pfnUserCallback = defaultDebugCallback,
    //     },
    //     null,
    //     &self[1],
    // ));

    return self;
}

fn defaultDebugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_type: c.VkDebugUtilsMessageTypeFlagsEXT,
    cb_data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque, // user_data
) callconv(.C) c.VkBool32 {
    const message = cb_data.*.pMessage;
    const mt = messageTypeToString(message_type);
    if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT != 0) {
        log.err(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    } else if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT != 0) {
        log.warn(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    } else if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT != 0) {
        log.info(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    } else {
        log.debug(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    }

    return c.VK_FALSE;
}

fn messageTypeToString(s: c.VkDebugUtilsMessageTypeFlagsEXT) []const u8 {
    return switch (s) {
        7 => "General | Validation | Performance",
        6 => "Validation | Performance",
        5 => "General | Performance",
        4 => "Performance",
        3 => "General | Validation",
        2 => "Validation",
        1 => "General",
        else => "Unknown",
    };
}
