const std = @import("std");

pub const vec3 = Vec3.new;
pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }
};
