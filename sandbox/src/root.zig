const std = @import("std");
const gg = @import("gargoyle");

pub const gg_options: gg.Options = .{};

pub const App = struct {
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
};

pub fn create(gpa: std.mem.Allocator, arena: std.mem.Allocator) !*App {
    const app = try gpa.create(App);
    app.* = App{
        .gpa = gpa,
        .arena = arena,
    };
    return app;
}

pub fn update(self: *App, dt: f32) !void {
    _ = self;
    _ = dt;
    // std.log.info("sandbox update: {d}\n", .{dt});
}

pub fn fixedUpdate(self: *App, dt: f32) !void {
    _ = self;
    _ = dt;
    // std.log.info("sandbox fixedUpdate: {d}\n", .{dt});
}

pub fn shutdown(self: *App) void {
    _ = self;
    std.log.info("sandbox shutdown\n", .{});
}
