const std = @import("std");
const rendering = @import("./rendering/root.zig");

const Options = @This();

fixed_timestep_ns: u64 = @ceil((1.0 / 60.0) * std.time.ns_per_s),
render: rendering.Options = .{},
