const std = @import("std");
const f32x4 = @Vector(4, f32);

pub const vec4 = Vec4.new;

pub const Vec4 = extern union {
    elements: extern struct {
        x: f32,
        y: f32,
        z: f32,
        w: f32,
    },
    simd: f32x4,

    pub inline fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return Vec4{ .elements = .{ .x = x, .y = y, .z = z, .w = w } };
    }

    pub inline fn identity() Vec4 {
        return new(0.0, 0.0, 0.0, 1.0);
    }

    pub inline fn add(left: Vec4, right: Vec4) Vec4 {
        return Vec4{ .simd = left.simd + right.simd };
    }

    pub inline fn sub(left: Vec4, right: Vec4) Vec4 {
        return Vec4{ .simd = left.simd - right.simd };
    }

    pub inline fn mul(left: Vec4, right: Vec4) Vec4 {
        return Vec4{ .simd = left.simd * right.simd };
    }

    pub inline fn mulf(left: Vec4, right: f32) Vec4 {
        return Vec4{ .simd = left.simd * @as(f32x4, @splat(right)) };
    }

    pub inline fn div(left: Vec4, right: Vec4) Vec4 {
        return Vec4{ .simd = left.simd / right.simd };
    }

    pub inline fn divf(left: Vec4, right: f32) Vec4 {
        return Vec4{ .simd = left.simd / @as(f32x4, @splat(right)) };
    }

    pub inline fn dot(left: Vec4, right: Vec4) f32 {
        return @reduce(.Add, left.simd * right.simd);
    }

    pub inline fn magSqr(self: Vec4) f32 {
        return self.dot(self);
    }

    pub inline fn mag(self: Vec4) f32 {
        return @sqrt(self.magSqr());
    }

    pub inline fn norm(self: Vec4) Vec4 {
        return self.mulf(1.0 / self.mag());
    }
};

test {
    std.testing.refAllDecls(@This());
}
