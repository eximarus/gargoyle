const std = @import("std");
const c = @import("../c.zig");
const vk = @import("../renderer/vulkan/vulkan.zig");
const window_types = @import("window_types.zig");
pub usingnamespace window_types;

const CString = [*:0]const u8;

pub const Window = struct {
    _sdl_window: ?*c.SDL_Window,

    pub inline fn init(options: *const window_types.Config) !Window {
        if (c.SDL_InitSubSystem(c.SDL_INIT_VIDEO) != 0) {
            std.log.err(
                "failed to initialize SDL Video Subsystem: {s}",
                .{c.SDL_GetError()},
            );
            return error.SDL_InitFailed;
        }

        const size = options.size orelse &window_types.Size{
            .width = 800,
            .height = 600,
        };

        // const window_size = options.window_mode.getWindowSizeOrNull() orelse blk: {
        //     var display_mode: sdl.SDL_DisplayMode = undefined;
        //     if (sdl.SDL_GetWindowDisplayMode(window, &display_mode) != 0) {
        //         return error.NoDisplayMode;
        //     }
        //
        //     break :blk sdl.WindowSize{
        //         .width = @intCast(display_mode.w),
        //         .height = @intCast(display_mode.h),
        //     };
        // };
        // _ = window_size;

        const sdl_window = c.SDL_CreateWindow(
            options.title,
            c.SDL_WINDOWPOS_UNDEFINED,
            c.SDL_WINDOWPOS_UNDEFINED,
            @intCast(size.width),
            @intCast(size.height),
            getFullscreenFlag(options.mode) | c.SDL_WINDOW_VULKAN,
        ) orelse {
            std.log.err("failed to create SDL window: {s}", .{c.SDL_GetError()});
            return error.SDL_CreateWindowFailed;
        };

        return Window{ ._sdl_window = sdl_window };
    }

    pub fn getVulkanExtensions(
        self: Window,
        allocator: std.mem.Allocator,
    ) ![]const CString {
        var extension_count: u32 = undefined;
        if (c.SDL_Vulkan_GetInstanceExtensions(
            self._sdl_window,
            &extension_count,
            null,
        ) != c.SDL_TRUE) {
            std.log.err(
                "failed to get SDL vulkan extensions: {s}",
                .{c.SDL_GetError()},
            );
            return error.SDL_Vulkan_GetInstanceExtensionsFailed;
        }

        const sdl_extensions = try allocator.alloc(
            CString,
            extension_count,
        );

        _ = c.SDL_Vulkan_GetInstanceExtensions(
            self._sdl_window,
            &extension_count,
            @ptrCast(sdl_extensions),
        );
        return sdl_extensions;
    }

    pub fn createVulkanSurface(
        self: Window,
        instance: vk.Instance,
    ) !vk.SurfaceKHR {
        var surface: vk.SurfaceKHR = undefined;
        if (c.SDL_Vulkan_CreateSurface(
            self._sdl_window,
            instance.handle(),
            &surface,
        ) != c.SDL_TRUE) {
            std.log.err(
                "failed to create SDL vulkan surface: {s}",
                .{c.SDL_GetError()},
            );
            return error.SDL_Vulkan_CreateSurfaceFailed;
        }
        return surface;
    }

    fn getFullscreenFlag(mode: window_types.Mode) c.Uint32 {
        return switch (mode) {
            .windowed => 0,
            .fullscreen => c.SDL_WINDOW_FULLSCREEN,
            .borderless_fullscreen => c.SDL_WINDOW_FULLSCREEN_DESKTOP,
        };
    }

    pub fn getSize(self: *const Window) window_types.Size {
        var size: window_types.Size = undefined;
        c.SDL_GetWindowSize(
            self._sdl_window,
            @ptrCast(&size.width),
            @ptrCast(&size.height),
        );
        return size;
    }

    pub fn setMode(self: *c.SDL_Window, mode: window_types.Mode) !void {
        switch (mode) {
            .windowed => |s| {
                c.SDL_SetWindowFullscreen(self, 0);
                c.SDL_SetWindowSize(
                    self,
                    @ptrCast(&s.width),
                    @ptrCast(&s.height),
                );
            },
            .fullscreen => {
                c.SDL_SetWindowFullscreen(self, c.SDL_WINDOW_FULLSCREEN);
            },
            .borderless_fullscreen => {
                c.SDL_SetWindowFullscreen(self, c.SDL_WINDOW_FULLSCREEN_DESKTOP);
            },
        }
    }

    pub fn deinit(self: *Window) void {
        c.SDL_DestroyWindow(self._sdl_window);
        self._sdl_window = null;
        c.SDL_QuitSubSystem(c.SDL_INIT_VIDEO);
    }
};
