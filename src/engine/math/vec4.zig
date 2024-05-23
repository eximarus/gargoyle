const std = @import("std");

pub const vec4 = Vec4.new;

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub inline fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return Vec4{ .x = x, .y = y, .z = z, .w = w };
    }
};
