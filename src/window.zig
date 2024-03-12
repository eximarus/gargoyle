const std = @import("std");
const glfw = @import("mach-glfw");
const wgpu = @import("mach-gpu");
const builtin = @import("builtin");
const Renderer = @import("renderer/renderer.zig").Renderer;

const config = @import("config");

pub fn init(title: [:0]const u8) !glfw.Window {
    if (!glfw.init(.{})) {
        const err = glfw.getError().?;
        std.log.err("failed to initialize GLFW: {?s}", .{err.description});
        return err.error_code;
    }

    errdefer glfw.terminate();

    var hints = glfw.Window.Hints{
        .doublebuffer = true,
    };

    const dbg = builtin.mode == .Debug;
    if (!dbg) {
        hints.decorated = false;
    }

    if (config.graphics_api == .opengl) {
        hints.context_version_major = 4;
        hints.context_version_minor = 4;
        hints.opengl_profile = .opengl_core_profile;
        hints.opengl_forward_compat = true;
        hints.client_api = .opengl_api;
    } else {
        hints.client_api = .no_api;
    }

    const monitor = if (dbg) null else glfw.Monitor.getPrimary();
    const mode = if (monitor) |value| glfw.Monitor.getVideoMode(value) else null;
    const size = if (mode) |value| .{
        .width = value.width,
        .height = value.height,
    } else .{
        .width = 1280,
        .height = 720,
    };

    var glfw_window = glfw.Window.create(size.width, size.height, title, null, null, hints) orelse {
        const err = glfw.getError().?;
        std.log.err("failed to create GLFW window: {?s}", .{err.description});
        return err.error_code;
    };
    errdefer glfw_window.destroy();

    if (config.graphics_api == .opengl) {
        glfw.makeContextCurrent(glfw_window);
        // glfw.swapInterval(1);
    }

    // glfw_window.setUserPointer(pointer: ?*anyopaque)

    glfw_window.setFramebufferSizeCallback((struct {
        fn callback(_window: glfw.Window, width: u32, height: u32) void {
            _ = _window;
            _ = width;
            _ = height;
        }
    }).callback);

    return glfw_window;
}

pub fn deinit(glfw_window: *const glfw.Window) void {
    glfw_window.destroy();
    glfw.terminate();
}
