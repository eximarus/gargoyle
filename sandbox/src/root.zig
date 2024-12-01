const std = @import("std");
const gg = @import("gargoyle");
const time = gg.time;
const gltf = gg.loading.gltf;

const log = std.log.scoped(.app);

const Context = struct {
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    thread_pool: std.Thread.Pool,
    window: gg.platform.Window,
    renderer: gg.rendering.Renderer,

    status: gg.rt.Status = gg.rt.Status.Foreground,
    quit: bool = false,

    test_meshes: []gg.rendering.resources.Mesh,
    test_images: []gg.rendering.resources.Texture2D,
};

const StartSystem = *const fn (Context) anyerror!void;
const UpdateSystem = *const fn (Context, f32) anyerror!void;

const fixed_timestep = 1.0 / 60.0;

pub const App = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    arena: std.heap.ArenaAllocator,
    fixed_delta: f32 = 0,

    ctx: Context,
    start_systems: []const StartSystem,
    update_systems: []const UpdateSystem,
    fixed_update_systems: []const UpdateSystem,
    render_systems: []const UpdateSystem,

    pub fn start(window: gg.platform.Window) !*App {
        std.log.info("sandbox start\n", .{});

        var self = try std.heap.c_allocator.create(App);
        self.* = App{
            .gpa = undefined,
            .arena = undefined,
            .ctx = undefined,
        };

        self.gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_allocator = self.gpa.allocator();

        self.arena = std.heap.ArenaAllocator.init(gpa_allocator);
        const arena_allocator = self.arena.allocator();

        const thread_count = (std.Thread.getCpuCount() catch 1) - 1;
        if (thread_count < 1) {
            return error.ThreadsUnavailable;
        }

        self.ctx = Context{
            .gpa = gpa_allocator,
            .arena = arena_allocator,
            .window = window,
        };

        try self.ctx.thread_pool.init(.{
            .allocator = gpa_allocator,
            .n_jobs = thread_count,
        });

        self.renderer = try gg.rendering.Renderer.init(
            gpa_allocator,
            arena_allocator,
            window,
            .{},
        );

        for (self.start_systems) |system| {
            try system(&self.ctx);
        }

        return self;
    }

    pub fn update(self: *App, dt: f32) !gg.rt.UpdateResult {
        self.fixed_delta += dt;

        while (self.fixed_delta >= fixed_timestep) {
            executeSystems(self.ctx, fixed_timestep, self.fixed_update_systems);
            self.fixed_delta -= fixed_timestep;
        }

        executeSystems(self.ctx, dt, self.update_systems);

        if (self.status == .background) {
            time.sleep(100 * time.ns_per_ms);
            return .@"continue";
        }

        executeSystems(self.ctx, dt, self.render_systems);

        if (self.status == .visible) {
            time.sleep(1.0 / 30.0 * time.ns_per_ms - dt);
        }

        _ = self.arena.reset(.{ .retain_with_limit = 1 * 1024 * 1024 }); // TODO adjust

        if (self.ctx.quit) {
            return .quit;
        }
        return .@"continue";
    }

    fn executeSystems(ctx: *Context, dt: f32, systems: []const UpdateSystem) void {
        for (systems) |system| {
            system(ctx, dt) catch |err| {
                log.err("caught error during system start: {}", .{err});
                if (@errorReturnTrace()) |t| {
                    std.debug.dumpStackTrace(t.*);
                }
            };
        }
    }

    pub fn onStatusChanged(self: *App, status: gg.rt.Status) void {
        self.ctx.status = status;
        std.log.info("sandbox status changed: {}\n", .{status});
    }

    pub fn onReload(_: *App) void {
        std.log.info("sandbox reload\n", .{});
    }

    pub fn onLowMemory(_: *App) void {
        std.log.info("sandbox low memory\n", .{});
    }

    pub fn shutdown(self: *App) void {
        std.log.info("sandbox shutdown\n", .{});
        self.ctx.thread_pool.deinit();
    }
};
