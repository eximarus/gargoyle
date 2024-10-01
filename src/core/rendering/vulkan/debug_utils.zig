const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const vk = @import("vulkan.zig");
const log = std.log.scoped(.vulkan);

pub fn createMessenger(instance: c.VkInstance) !c.VkDebugUtilsMessengerEXT {
    var messenger: c.VkDebugUtilsMessengerEXT = undefined;
    try vk.check(vk.createDebugUtilsMessengerEXT(
        instance,
        &.{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT,
            .pfnUserCallback = debugCallback,
        },
        null,
        &messenger,
    ));
    return messenger;
}

fn debugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: c.VkDebugUtilsMessageTypeFlagsEXT, // message_type
    cb_data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque, // user_data
) callconv(.C) c.VkBool32 {
    const message = cb_data.*.pMessage;
    if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT != 0) {
        log.err("{s}", .{message});
    } else if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT != 0) {
        log.warn("{s}", .{message});
    } else if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT != 0) {
        log.info("{s}", .{message});
    } else {
        log.debug("{s}", .{message});
    }

    return c.VK_FALSE;
}
