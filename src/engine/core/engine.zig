const std = @import("std");
const App = @import("app_types.zig").App;
const AppConfig = @import("app_config.zig").AppConfig;

const time = @import("time.zig");
const events = @import("events.zig");
const Window = @import("window.zig").Window;
const Renderer = @import("../renderer/renderer.zig").Renderer;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: Window,
    renderer: Renderer,
    timer: time.Timer,
    fixed_timestep_ns: u64,
    sub_step_count: i32 = 4,
    fixed_delta: u64 = 0,
    minimized: bool = false,
    quit: bool = false,

    pub inline fn init(
        allocator: std.mem.Allocator,
        cfg: *const AppConfig,
    ) !Engine {
        const window = try Window.init(&cfg.window);

        return Engine{
            .allocator = allocator,
            .window = window,
            .renderer = try Renderer.init(allocator, window, cfg.render),
            .timer = try time.Timer.start(),
            .fixed_timestep_ns = cfg.physics.fixed_timestep_ns,
        };
    }

    pub inline fn next(self: *Engine, app: *App) bool {
        const dt_ns = self.timer.lap();
        const dt = time.nanosToSeconds(dt_ns);

        const fixed_timestep = self.fixed_timestep_ns;
        const fixed_dt = time.nanosToSeconds(fixed_timestep);
        self.fixed_delta += dt_ns;

        events.poll(self.eventHandler());

        // todo interpolate physics for vsync?
        while (self.fixed_delta >= fixed_timestep) {
            _ = app.fixedUpdate(fixed_dt);
            self.fixed_delta -= fixed_timestep;
        }

        _ = app.update(dt);
        if (self.minimized) {
            std.time.sleep(100 * time.ns_per_ms);
            return true;
        }

        self.renderer.render(app) catch |err| {
            std.log.err("gargoyle render error: {}\n", .{err});
        };
        return !self.quit;
    }

    pub inline fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.window.deinit();
    }

    fn eventHandler(self: *Engine) events.EventHandler {
        return .{
            .ptr = self,
            .vtable = &.{
                .onWindowMinimized = onWindowMinimized,
                .onWindowRestored = onWindowRestored,
                .onQuit = onQuit,
                .onWindowResize = onWindowResize,
            },
        };
    }

    fn onWindowMinimized(ctx: *anyopaque) void {
        const self: *Engine = @ptrCast(@alignCast(ctx));
        self.minimized = true;
    }
    fn onWindowRestored(ctx: *anyopaque) void {
        const self: *Engine = @ptrCast(@alignCast(ctx));
        self.minimized = false;
    }
    fn onQuit(ctx: *anyopaque) void {
        const self: *Engine = @ptrCast(@alignCast(ctx));
        self.quit = true;
    }
    fn onWindowResize(ctx: *anyopaque, width: u32, height: u32) void {
        const self: *Engine = @ptrCast(@alignCast(ctx));
        self.renderer.onWindowResize(width, height);
    }
};
