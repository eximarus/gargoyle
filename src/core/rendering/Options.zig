const std = @import("std");

const NBuffering = enum { none, double, triple };

const Options = @This();

vsync: bool = true,
n_buffering: NBuffering = .double,

fps_cap: u16 = std.math.maxInt(u16),
max_fg_fps: u16 = std.math.maxInt(u16),
max_bg_fps: u16 = std.math.maxInt(u16),
target_fps: u16 = std.math.maxInt(u16),
