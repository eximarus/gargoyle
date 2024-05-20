const std = @import("std");

pub const WindowConfig = @import("window_types.zig").Config;

pub const RenderConfig = extern struct {
    vsync: bool = true,
};

pub const PhysicsConfig = extern struct {
    fixed_timestep_ns: u64 = @ceil((1.0 / 60.0) * std.time.ns_per_s),
    sub_step_count: i32 = 4,
};

pub const AppConfig = extern struct {
    window: WindowConfig = .{ .title = "gargoyle" },
    physics: PhysicsConfig = .{},
    render: RenderConfig = .{},
};
