const std = @import("std");
const g = @import("gargoyle");
const AppConfig = g.AppConfig;

pub const App = struct {
    // engine: *gargoyle.Engine,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator) anyerror!App {
        return App{
            .allocator = allocator,
            // .engine = engine,
        };
    }

    pub fn init(self: *App, out_config: *AppConfig) anyerror!void {
        _ = self;
        out_config.* = AppConfig{};
        out_config.window.title = "sandbox";
        out_config.window.mode = .windowed;
        out_config.window.size = @constCast(&.{
            .width = 1700,
            .height = 900,
        });

        std.log.info("sandbox init\n", .{});
    }

    pub fn update(self: *App, dt: f32) anyerror!void {
        _ = self;
        _ = dt;
        // std.log.info("sandbox update: {d}\n", .{dt});
    }

    pub fn fixedUpdate(self: *App, dt: f32) anyerror!void {
        _ = self;
        _ = dt;
        // std.log.info("sandbox fixedUpdate: {d}\n", .{dt});
    }

    pub fn reload(self: *App) anyerror!void {
        _ = self;
        std.log.info("sandbox reload\n", .{});
    }

    pub fn onGui(self: *App) anyerror!void {
        _ = self;
        // std.log.info("sandbox onGui\n", .{});
    }

    pub fn deinit(self: *App) void {
        _ = self;
        std.log.info("sandbox deinit\n", .{});
    }
};
