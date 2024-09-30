const std = @import("std");

const Options = @This();

vsync: bool = true,
tripple_buffering: bool = false,

fps_cap: u16 = std.math.maxInt(u16),
max_fg_fps: u16 = std.math.maxInt(u16),
max_bg_fps: u16 = std.math.maxInt(u16),
target_fps: u16 = std.math.maxInt(u16),
