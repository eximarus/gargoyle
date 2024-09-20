const std = @import("std");
const time = @import("time.zig");
const AppConfig = @import("AppConfig.zig");
const Window = @import("platform").Window;
const Renderer = @import("../renderer/renderer.zig").Renderer;
const log = std.log.scoped(.engine);

const Engine = @This();

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
window: Window,
renderer: Renderer,
timer: time.Timer,
fixed_timestep_ns: u64,
fixed_delta: u64 = 0,
minimized: bool = false,
quit: bool = false,

pub inline fn init(
    gpa: std.mem.Allocator,
    window: Window,
    cfg: *const AppConfig,
) !Engine {
    var self: Engine = undefined;
    self.fixed_delta = 0;
    self.minimized = false;
    self.quit = false;
    self.gpa = gpa;
    self.arena = std.heap.ArenaAllocator.init(gpa);
    self.window = window;
    self.renderer = try Renderer.init(gpa, self.arena.allocator(), window, cfg.render);
    self.timer = try time.Timer.start();
    self.fixed_timestep_ns = cfg.physics.fixed_timestep_ns;
    return self;
}

pub inline fn update(self: *Engine, app: anytype) u32 {
    const dt_ns = self.timer.lap();
    const dt = time.nanosToSeconds(dt_ns);

    const fixed_timestep = self.fixed_timestep_ns;
    const fixed_dt = time.nanosToSeconds(fixed_timestep);
    self.fixed_delta += dt_ns;

    // todo interpolate physics for vsync?
    while (self.fixed_delta >= fixed_timestep) {
        app.fixedUpdate(fixed_dt) catch |err| {
            log.err("caught app error during fixed update: {}\n", .{err});
        };
        self.fixed_delta -= fixed_timestep;
    }

    app.update(dt) catch |err| {
        log.err("caught app error during update: {}\n", .{err});
    };

    if (self.minimized) {
        std.time.sleep(100 * time.ns_per_ms);
        return 0;
    }

    self.renderer.render(app) catch |err| {
        log.err("render error: {}\n", .{err});
    };

    _ = self.arena.reset(.{ .retain_with_limit = 1024 * 1024 });

    if (self.quit) {
        return 1;
    }
    return 0;
}

pub inline fn shutdown(self: *Engine) void {
    self.renderer.deinit();
}
