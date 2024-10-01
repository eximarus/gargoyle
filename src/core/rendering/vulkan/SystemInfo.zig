const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const common = @import("common.zig");
const log = std.log.scoped(.vulkan);

pub const validation_layer_name = "VK_LAYER_KHRONOS_validation";

// TODO rename to hardware capabilities
const SystemInfo = @This();

available_layers: []c.VkLayerProperties,
available_extensions: std.ArrayList(c.VkExtensionProperties),

pub inline fn init(arena: std.mem.Allocator) !SystemInfo {
    var self: SystemInfo = undefined;
    self.available_extensions =
        std.ArrayList(c.VkExtensionProperties).init(arena);

    var prop_count: u32 = undefined;
    try vk.check(vk.enumerateInstanceExtensionProperties(null, &prop_count, null));
    try self.available_extensions.ensureUnusedCapacity(prop_count);

    try vk.check(vk.enumerateInstanceExtensionProperties(
        null,
        &prop_count,
        self.available_extensions.unusedCapacitySlice().ptr,
    ));
    self.available_extensions.items.len += prop_count;

    var layer_count: u32 = undefined;
    try vk.check(vk.enumerateInstanceLayerProperties(&layer_count, null));
    self.available_layers = try arena.alloc(c.VkLayerProperties, layer_count);
    try vk.check(vk.enumerateInstanceLayerProperties(&layer_count, self.available_layers.ptr));

    for (self.available_layers) |layer| {
        const layer_name: c.String = @ptrCast(&layer.layerName);
        vk.check(vk.enumerateInstanceExtensionProperties(layer_name, &prop_count, null)) catch |err| {
            log.warn("unable to enumerate instance extension properties for layer: {s}. err: {}", .{ layer_name, err });
            continue;
        };
        self.available_extensions.ensureUnusedCapacity(prop_count) catch |err| {
            log.warn("unable to ensure unused capacity for available_extensions at layer: {s}. err: {}", .{ layer_name, err });
            continue;
        };
        vk.check(vk.enumerateInstanceExtensionProperties(
            null,
            &prop_count,
            self.available_extensions.unusedCapacitySlice().ptr,
        )) catch |err| {
            log.warn("unable to enumerate instance extension properties for layer: {s}. err: {}", .{ layer_name, err });
            continue;
        };
        self.available_extensions.items.len += prop_count;
    }

    return self;
}

pub inline fn isExtensionSupported(
    self: *const SystemInfo,
    ext_name: c.String,
) bool {
    return common.isExtensionAvailable(
        self.available_extensions.items,
        ext_name,
    );
}

pub inline fn isLayerSupported(
    self: *const SystemInfo,
    layer_name: c.String,
) bool {
    return common.isLayerAvailable(self.available_layers.items, layer_name);
}
