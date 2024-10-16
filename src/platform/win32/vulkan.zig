const std = @import("std");
const c = @import("c");
const Window = @import("window.zig").Window;

pub const lib_path = "vulkan-1.dll";

pub const surface_ext: [*:0]const u8 = "VK_KHR_win32_surface";

fn PFN(comptime T: type) type {
    return @typeInfo(T).Optional.child;
}

var vkCreateWin32SurfaceKHR: PFN(c.PFN_vkCreateWin32SurfaceKHR) = undefined;

pub fn init(
    vkGetInstanceProcAddr: PFN(c.PFN_vkGetInstanceProcAddr),
    instance: c.VkInstance,
) void {
    vkCreateWin32SurfaceKHR =
        @ptrCast(vkGetInstanceProcAddr(instance, "vkCreateWin32SurfaceKHR") orelse {
        std.debug.panic("vkCreateWin32SurfaceKHR not found", .{});
    });
}

pub fn createSurface(
    window: Window,
    instance: c.VkInstance,
    out_surface: *c.VkSurfaceKHR,
) c.VkResult {
    return vkCreateWin32SurfaceKHR(
        instance,
        &c.VkWin32SurfaceCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hinstance = window.hinstance,
            .hwnd = window.hwnd,
        },
        null,
        out_surface,
    );
}
