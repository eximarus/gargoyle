const std = @import("std");

pub const RenderConfig = extern struct {
    vsync: bool = true,
    tripple_buffering: bool = false,

    fps_cap: u16 = std.math.maxInt(u16),
    max_fg_fps: u16 = std.math.maxInt(u16),
    max_bg_fps: u16 = std.math.maxInt(u16),
    target_fps: u16 = std.math.maxInt(u16),
};

pub const PhysicsConfig = extern struct {
    fixed_timestep_ns: u64 = @ceil((1.0 / 60.0) * std.time.ns_per_s),
    sub_step_count: i32 = 4,
};

pub const AppConfig = extern struct {
    title: [*:0]const u8 = "gargoyle",
    physics: PhysicsConfig = .{},
    render: RenderConfig = .{},
};
