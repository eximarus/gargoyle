const std = @import("std");
const gg = @import("gargoyle");
const time = gg.time;
const gltf = gg.loading.gltf;

const log = std.log.scoped(.app);
// std.simd.interlace()
// std.simd.deinterlace

pub const Meshes = gg.Archetype(gg.rendering.resources.Mesh);

pub const StaticEntities = gg.Archetype(struct {
    pos: gg.math.Vec3,
    rot: gg.math.Quat,
    scale: gg.math.Vec3,

    // TODO id system for resources
    mesh: *gg.rendering.resources.Mesh = undefined,
    material: *gg.rendering.resources.Material = undefined,
});

pub const PhysicsEntities = gg.Archetype(struct {
    // hot
    pos_x: f32 = 0,
    pos_y: f32 = 0,
    pos_z: f32 = 0,

    rot_a: f32 = 1,
    rot_b: f32 = 0,
    rot_c: f32 = 0,
    rot_d: f32 = 0,

    scale_x: f32 = 1,
    scale_y: f32 = 1,
    scale_z: f32 = 1,

    vel_x: f32 = 0,
    vel_y: f32 = 0,
    vel_z: f32 = 0,

    parent: ?PhysicsEntities.Id = null,
    children: std.ArrayList(PhysicsEntities.Id),

    // TODO id system for resources
    mesh: *gg.rendering.resources.Mesh = undefined,
    material: *gg.rendering.resources.Material = undefined,
});

// pub const Enemy = struct {
//     // use references if transforms are not accessed often
//     // if transforms are acccessed often embed transform data into archetype
//     node: SimulatedMeshNode.Id,
//     health: f32,
//     //...
// };

const Context = struct {
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    thread_pool: std.Thread.Pool,
    window: gg.platform.Window,
    renderer: gg.rendering.Renderer,
    static_meshes: StaticEntities,

    status: gg.rt.Status = gg.rt.Status.foreground,
    quit: bool = false,

    // test_meshes: []gg.rendering.resources.Mesh,
    // test_images: []gg.rendering.resources.Texture2D,
};

fn render(ctx: *Context, t: f32, dt: f32) !void {
    // const id = try ctx.static_meshes.create(StaticEntities.Elem{
    //     .pos = gg.math.vec3(dt, dt, t),
    //     .rot = gg.math.Quat.identity(),
    //     .scale = gg.math.Vec3.one(),
    // });
    // const e = ctx.static_meshes.get(id);
    // std.log.info("{}", .{e.pos});

    _ = t;
    _ = dt;
    try ctx.renderer.render();
}

const fixed_timestep = 1.0 / 60.0;

pub const App = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    arena: std.heap.ArenaAllocator,

    t: f32 = 0.0,
    ctx: Context,

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
            .renderer = try gg.rendering.Renderer.init(
                gpa_allocator,
                arena_allocator,
                window,
                .{},
            ),
            .thread_pool = undefined,
            .static_meshes = StaticEntities.init(gpa_allocator),
        };

        try self.ctx.thread_pool.init(.{
            .allocator = gpa_allocator,
            .n_jobs = @intCast(thread_count),
        });

        return self;
    }

    pub fn update(self: *App, dt: f32) !gg.rt.UpdateResult {
        self.t += dt;

        if (self.ctx.status == .invisible) {
            time.sleep(100 * time.ns_per_ms);
            return .@"continue";
        }

        render(&self.ctx, self.t, dt) catch |err| {
            log.err("{}", .{err});
            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }
        };

        if (self.ctx.status == .visible) {
            time.sleep(@intFromFloat((1.0 / 30.0 - dt) * time.ns_per_ms));
        }

        _ = self.arena.reset(.{ .retain_with_limit = 1 * 1024 * 1024 }); // TODO adjust

        if (self.ctx.quit) {
            return .quit;
        }
        return .@"continue";
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
