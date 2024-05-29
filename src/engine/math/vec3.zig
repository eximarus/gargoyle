const std = @import("std");

pub const vec3 = Vec3.new;
pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub inline fn one() Vec3 {
        return new(1.0, 1.0, 1.0);
    }

    pub inline fn zero() Vec3 {
        return new(0.0, 0.0, 0.0);
    }

    pub inline fn magSqr(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub inline fn mag(self: Vec3) f32 {
        return @sqrt(self.magSqr());
    }

    pub inline fn normalize(self: *Vec3) void {
        const len = self.mag();
        self.x /= len;
        self.y /= len;
        self.z /= len;
    }

    pub inline fn normalized(self: Vec3) Vec3 {
        var n = self;
        n.normalize();
        return n;
    }

    pub inline fn add(a: Vec3, b: Vec3) Vec3 {
        return new(a.x + b.x, a.y + b.y, a.z + b.z);
    }

    pub inline fn sub(a: Vec3, b: Vec3) Vec3 {
        return new(a.x - b.x, a.y - b.y, a.z - b.z);
    }

    pub inline fn mul(a: Vec3, b: Vec3) Vec3 {
        return new(a.x * b.x, a.y * b.y, a.z * b.z);
    }

    pub inline fn mulf(a: Vec3, b: f32) Vec3 {
        return new(a.x * b, a.y * b, a.z * b);
    }

    pub inline fn dot(a: Vec3, b: Vec3) f32 {
        return (a.x * b.x) +
            (a.y * b.y) +
            (a.z * b.z);
    }

    pub inline fn cross(a: Vec3, b: Vec3) Vec3 {
        return new(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x,
        );
    }
};