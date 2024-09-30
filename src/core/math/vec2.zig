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

    pub inline fn add(self: Vec2, other: Vec2) Vec2 {
        return new(self.x + other.x, self.y + other.y);
    }

    pub inline fn sub(self: Vec2, other: Vec2) Vec2 {
        return new(self.x - other.x, self.y - other.y);
    }

    pub inline fn mul(self: Vec2, other: Vec2) Vec2 {
        return new(self.x * other.x, self.y * other.y);
    }

    pub inline fn div(self: Vec2, other: Vec2) Vec2 {
        return new(self.x / other.x, self.y / other.y);
    }

    pub inline fn magSq(self: Vec2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub inline fn mag(self: Vec2) f32 {
        return std.math.sqrt(self.magSq());
    }

    pub inline fn normalize(self: *Vec2) void {
        const m = self.mag();
        self.x /= m;
        self.y /= m;
    }

    pub inline fn normalized(self: Vec2) Vec2 {
        var v = self;
        v.normalize();
        return v;
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

    pub inline fn dist(self: Vec2, other: Vec2) f32 {
        return self.sub(other).mag();
    }
};
