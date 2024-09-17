const std = @import("std");

const vk = @import("../renderer/vulkan/vulkan.zig");

const CString = [*:0]const u8;

pub const WindowsWindow = struct {
    // hinstance: HINSTANCE,
    // hwnd: HWND,
};

pub const WaylandWindow = struct {
    // display: wl_display,
    // surface: wl_surface,
};

pub const AndroidWindow = struct {
    // window: ANativeWindow
};

// pub const IOSWindow = struct {
//     // view: ?*anyopaque, // either a CAMetalLayer or a UIView
// };

pub const Window = struct {
    pub inline fn init(title: [*:0]const u8) !Window {
        _ = title;
        return Window{};
    }

    pub fn getVulkanExtensions(
        self: Window,
        allocator: std.mem.Allocator,
    ) ![]const CString {
        _ = self;
        _ = allocator;
        return &.{""};
    }

    pub fn createVulkanSurface(
        self: Window,
        instance: vk.Instance,
    ) !vk.SurfaceKHR {
        _ = self;
        _ = instance;
        return @ptrCast(vk.c.VK_NULL_HANDLE);
    }

    pub fn deinit(self: *Window) void {
        _ = self;
    }
};
