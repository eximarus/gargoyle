const std = @import("std");
const g = @import("gargoyle");
const AppConfig = g.AppConfig;

pub const App = struct {
    gpa: std.mem.Allocator,

    pub fn create(gpa: std.mem.Allocator) anyerror!*App {
        const app = try gpa.create(App);
        app.* = App{
            .gpa = gpa,
        };
        return app;
    }

    pub fn configure() g.AppConfig {
        return g.AppConfig{};
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

    pub fn shutdown(self: *App) void {
        _ = self;
        std.log.info("sandbox shutdown\n", .{});
    }
};
