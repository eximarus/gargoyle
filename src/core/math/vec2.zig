const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;

pub const vec2 = Vec2.new;
pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub inline fn new(x: f32, y: f32) Vec2 {
        return Vec2{ .x = x, .y = y };
    }

    pub inline fn splat(scalar: f32) Vec2 {
        return Vec2{ .x = scalar, .y = scalar };
    }

    pub inline fn zero() Vec2 {
        return new(0.0, 0.0);
    }

    pub inline fn one() Vec2 {
        return new(1.0, 1.0);
    }

    pub inline fn up() Vec2 {
        return new(0.0, 1.0);
    }

    pub inline fn down() Vec2 {
        return new(0.0, -1.0);
    }

    pub inline fn left() Vec2 {
        return new(-1.0, 0.0);
    }

    pub inline fn right() Vec2 {
        return new(1.0, 0.0);
    }

    pub inline fn toVec3(self: Vec2) Vec3 {
        return Vec3.new(self.x, self.y, 0.0);
    }

    pub inline fn add(a: Vec2, b: Vec2) Vec2 {
        return new(a.x + b.x, a.y + b.y);
    }

    pub inline fn sub(a: Vec2, b: Vec2) Vec2 {
        return new(a.x - b.x, a.y - b.y);
    }

    pub inline fn mul(a: Vec2, b: Vec2) Vec2 {
        return new(a.x * b.x, a.y * b.y);
    }

    pub inline fn mulf(a: Vec2, b: f32) Vec2 {
        return new(a.x * b, a.y * b);
    }

    pub inline fn div(a: Vec2, b: Vec2) Vec2 {
        return new(a.x / b.x, a.y / b.y);
    }

    pub inline fn divf(a: Vec2, b: f32) Vec2 {
        return new(a.x / b, a.y / b);
    }

    pub inline fn dot(a: Vec2, b: Vec2) f32 {
        return (a.x * b.x) + (a.y * b.y);
    }

    pub inline fn magSqr(self: Vec2) f32 {
        return self.dot(self);
    }

    pub inline fn mag(self: Vec2) f32 {
        return @sqrt(self.magSqr());
    }

    pub inline fn norm(self: Vec2) Vec2 {
        return self.mulf(1.0 / self.mag());
    }

    pub inline fn cross(a: Vec2, b: Vec2) f32 {
        return a.x * b.y - a.y * b.x;
    }
};
