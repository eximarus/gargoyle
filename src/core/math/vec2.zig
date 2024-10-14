const std = @import("std");

pub const vec2 = Vec2.new;
pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub inline fn new(x: f32, y: f32) Vec2 {
        return Vec2{ .x = x, .y = y };
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

    pub inline fn approxEq(self: Vec2, other: Vec2, tolerance: f32) bool {
        if (!std.math.approxEqAbs(f32, self.x, other.x, tolerance)) {
            return false;
        }
        if (!std.math.approxEqAbs(f32, self.y, other.y, tolerance)) {
            return false;
        }
        return true;
    }

    pub inline fn dist(a: Vec2, b: Vec2) f32 {
        return a.sub(b).mag();
    }
};
