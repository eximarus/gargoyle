const c = @import("c");
const std = @import("std");
const Window = @import("window.zig").Window;

pub const lib_path = "libvulkan.so.1";

pub const surface_ext: [*:0]const u8 = "VK_KHR_xcb_surface";

fn PFN(comptime T: type) type {
    return @typeInfo(T).Optional.child;
}

var vkCreateXcbSurfaceKHR: PFN(c.PFN_vkCreateXcbSurfaceKHR) = undefined;

pub fn init(
    vkGetInstanceProcAddr: PFN(c.PFN_vkGetInstanceProcAddr),
    instance: c.VkInstance,
) !void {
    vkCreateXcbSurfaceKHR =
        @ptrCast(vkGetInstanceProcAddr(instance, "vkCreateXcbSurfaceKHR") orelse {
        std.debug.panic("vkCreateXcbSurfaceKHR not found", .{});
    });
}

pub fn createSurface(
    window: Window,
    instance: c.VkInstance,
) struct { c.VkResult, c.VkSurfaceKHR } {
    var surface: c.VkSurfaceKHR = undefined;
    const result = vkCreateXcbSurfaceKHR(
        instance,
        &c.VkXcbSurfaceCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
            .connection = window.connection,
            .window = window.window,
        },
        null,
        @ptrCast(&surface),
    );
    return .{ result, surface };
}
