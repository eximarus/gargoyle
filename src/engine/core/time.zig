const time = @import("std").time;
pub usingnamespace time;

pub inline fn nanosToSeconds(ns: u64) f32 {
    return @as(f32, @floatCast(@as(f64, @floatFromInt(ns)) /
        @as(f64, @floatFromInt(time.ns_per_s))));
}

pub inline fn nanosToMillis(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) /
        @as(f64, @floatFromInt(time.ns_per_ms));
}
