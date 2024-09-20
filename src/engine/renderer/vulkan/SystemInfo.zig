const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const common = @import("common.zig");

const CString = common.CString;

pub const validation_layer_name = "VK_LAYER_KHRONOS_validation";

const SystemInfo = @This();

available_layers: []const c.VkLayerProperties,
available_extensions: std.ArrayList(c.VkExtensionProperties),
validation_layers_available: bool = false,
debug_utils_available: bool = false,

pub inline fn init(allocator: std.mem.Allocator) !SystemInfo {
    var self: SystemInfo = undefined;
    self.available_extensions =
        std.ArrayList(c.VkExtensionProperties).init(allocator);
    try self.available_extensions.appendSlice(
        try vk.enumerateInstanceExtensionProperties(allocator, null),
    );

    self.available_layers = try vk.enumerateInstanceLayerProperties(allocator);

    for (self.available_layers) |layer| {
        const layer_name: CString = @ptrCast(&layer.layerName);
        if (std.mem.eql(u8, std.mem.span(layer_name), validation_layer_name)) {
            self.validation_layers_available = true;
        }

        const layer_extensions = vk.enumerateInstanceExtensionProperties(
            allocator,
            layer_name,
        );
        if (layer_extensions) |value| {
            try self.available_extensions.appendSlice(value);
        } else |_| {}
    }

    for (self.available_extensions.items) |ext| {
        const ext_name: CString = @ptrCast(&ext.extensionName);

        if (std.mem.eql(
            u8,
            std.mem.span(ext_name),
            c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
        )) {
            self.debug_utils_available = true;
        }
    }
    return self;
}

pub inline fn isExtensionSupported(
    self: *const SystemInfo,
    ext_name: CString,
) bool {
    return common.isExtensionAvailable(
        self.available_extensions.items,
        ext_name,
    );
}

pub inline fn isLayerSupported(
    self: *const SystemInfo,
    layer_name: CString,
) bool {
    return common.isLayerAvailable(self.available_layers.items, layer_name);
}
