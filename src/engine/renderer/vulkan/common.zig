const std = @import("std");
const vk = @import("vulkan.zig");
const c = vk.c;
pub const CString = vk.CString;

pub fn isLayerAvailable(
    available: []const c.VkLayerProperties,
    layer_to_validate: CString,
) bool {
    for (available) |props| {
        const layer_name: CString =
            @ptrCast(&props.layerName);
        if (std.mem.eql(
            u8,
            std.mem.span(layer_name),
            std.mem.span(layer_to_validate),
        )) {
            return true;
        }
    }
    return false;
}

pub fn validateLayers(
    available: []const c.VkLayerProperties,
    required: []const CString,
) !void {
    for (required) |layer| {
        if (!isLayerAvailable(available, layer)) {
            std.log.err("Required vulkan layer not supported: {s}\n", .{layer});
            return error.VulkanLayerNotSupported;
        }
    }
}

pub fn isExtensionAvailable(
    available: []const c.VkExtensionProperties,
    ext_to_validate: CString,
) bool {
    for (available) |props| {
        const ext_name: CString =
            @ptrCast(&props.extensionName);
        if (std.mem.eql(
            u8,
            std.mem.span(ext_name),
            std.mem.span(ext_to_validate),
        )) {
            return true;
        }
    }
    return false;
}

pub fn validateExtensions(
    available: []const c.VkExtensionProperties,
    required: []const CString,
) !void {
    for (required) |ext| {
        if (!isExtensionAvailable(available, ext)) {
            std.log.err("Required vulkan extension not supported: {s}\n", .{ext});
            return error.VulkanExtensionNotSupported;
        }
    }
}
