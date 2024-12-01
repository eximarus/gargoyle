const std = @import("std");
const Vec4 = @import("vec4.zig").Vec4;
const Vec2 = @import("vec2.zig").Vec2;
const Mat3 = @import("mat3.zig").Mat3;

pub const vec3 = Vec3.new;
pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub inline fn splat(scalar: f32) Vec3 {
        return Vec3{ .x = scalar, .y = scalar, .z = scalar };
    }

    pub inline fn one() Vec3 {
        return new(1.0, 1.0, 1.0);
    }

    pub inline fn zero() Vec3 {
        return new(0.0, 0.0, 0.0);
    }

    pub inline fn up() Vec3 {
        return new(0.0, 1.0, 0.0);
    }

    pub inline fn down() Vec3 {
        return new(0.0, -1.0, 0.0);
    }

    pub inline fn left() Vec3 {
        return new(-1.0, 0.0, 0.0);
    }

    pub inline fn right() Vec3 {
        return new(1.0, 0.0, 0.0);
    }

    pub inline fn forward() Vec3 {
        return new(0.0, 0.0, 1.0);
    }

    pub inline fn backward() Vec3 {
        return new(0.0, 0.0, -1.0);
    }

    pub inline fn toVec4(self: Vec3) Vec4 {
        return Vec4.new(self.x, self.y, self.z, 1.0);
    }

    pub inline fn add(a: Vec3, b: Vec3) Vec3 {
        return new(a.x + b.x, a.y + b.y, a.z + b.z);
    }

    pub inline fn sub(a: Vec3, b: Vec3) Vec3 {
        return new(a.x - b.x, a.y - b.y, a.z - b.z);
    }

    // pub inline fn mul(a: Vec3, b: Vec3) Vec3 {
    //     return new(a.x * b.x, a.y * b.y, a.z * b.z);
    // }

    pub inline fn mulf(a: Vec3, b: f32) Vec3 {
        return new(a.x * b, a.y * b, a.z * b);
    }

    pub inline fn mulM(a: Vec3, b: Mat3) Vec3 {
        return new(
            b[0] * a.x + b[3] * a.y + b[6] * a.z,
            b[1] * a.x + b[4] * a.y + b[7] * a.z,
            b[2] * a.x + b[5] * a.y + b[8] * a.z,
        );
    }

    pub inline fn div(a: Vec3, b: Vec3) Vec3 {
        return new(a.x / b.x, a.y / b.y, a.z / b.z);
    }

    pub inline fn divf(a: Vec3, b: f32) Vec3 {
        return new(a.x / b, a.y / b, a.z / b);
    }

    pub inline fn dot(a: Vec3, b: Vec3) f32 {
        return (a.x * b.x) +
            (a.y * b.y) +
            (a.z * b.z);
    }

    pub inline fn magSqr(self: Vec3) f32 {
        return self.dot(self);
    }

    pub inline fn mag(self: Vec3) f32 {
        return @sqrt(self.magSqr());
    }

    pub inline fn norm(self: Vec3) Vec3 {
        return self.mulf(1.0 / self.mag());
    }

    pub inline fn cross(a: Vec3, b: Vec3) Vec3 {
        return new(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x,
        );
    }

    pub inline fn min(a: Vec3, b: Vec3) Vec3 {
        return new(@min(a.x, b.x), @min(a.y, b.y), @min(a.z, b.z));
    }

    pub inline fn max(a: Vec3, b: Vec3) Vec3 {
        return new(@max(a.x, b.x), @max(a.y, b.y), @max(a.z, b.z));
    }
};
