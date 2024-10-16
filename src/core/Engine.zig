const std = @import("std");
const time = @import("time.zig");
const Options = @import("Options.zig");
const Window = @import("platform").Window;
const Renderer = @import("rendering/root.zig").Renderer;
const app = @import("app");
const log = std.log.scoped(.engine);

const Engine = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
window: Window,
app_ptr: *app.App,
renderer: Renderer,
timer: time.Timer,
fixed_timestep_ns: u64,
fixed_delta: u64 = 0,
minimized: bool = false,
quit: bool = false,

pub fn create(window: Window) !*Engine {
    const options = if (@hasDecl(app, "gg_options"))
        app.gg_options
    else
        Options{};

    const gpa_allocator = gpa.allocator();
    const self = try gpa_allocator.create(Engine);
    self.* = Engine{
        .gpa = gpa_allocator,
        .window = window,
        .arena = std.heap.ArenaAllocator.init(gpa_allocator),
        .timer = time.Timer.start() catch unreachable,
        .fixed_timestep_ns = options.fixed_timestep_ns,
        .app_ptr = undefined,
        .renderer = undefined,
    };

    const arena_allocator = self.arena.allocator();
    self.renderer = try Renderer.init(gpa_allocator, arena_allocator, window, options.render);
    self.app_ptr = try app.create(gpa_allocator, arena_allocator);
    return self;
}

pub fn update(self: *Engine) u32 {
    const dt_ns = self.timer.lap();
    const dt = time.nanosToSeconds(dt_ns);

    const fixed_timestep = self.fixed_timestep_ns;
    const fixed_dt = time.nanosToSeconds(fixed_timestep);
    self.fixed_delta += dt_ns;

    while (self.fixed_delta >= fixed_timestep) {
        app.fixedUpdate(self.app_ptr, fixed_dt) catch |err| {
            log.err("caught app error during fixed update: {}", .{err});
            if (@errorReturnTrace()) |t| {
                std.debug.dumpStackTrace(t.*);
            }
        };
        self.fixed_delta -= fixed_timestep;
    }

    app.update(self.app_ptr, dt) catch |err| {
        log.err("caught app error during update: {}", .{err});
        if (@errorReturnTrace()) |t| {
            std.debug.dumpStackTrace(t.*);
        }
    };

    if (self.minimized) {
        std.time.sleep(100 * time.ns_per_ms);
        return 0;
    }

    self.renderer.render() catch |err| {
        log.err("caught render error: {}", .{err});
        if (@errorReturnTrace()) |t| {
            std.debug.dumpStackTrace(t.*);
        }
    };

    _ = self.arena.reset(.{ .retain_with_limit = 1024 * 1024 }); // TODO adjust

    if (self.quit) {
        return 1;
    }
    return 0;
}

pub fn shutdown(self: *Engine) void {
    app.shutdown(self.app_ptr);
}
