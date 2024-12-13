const std = @import("std");
const Mat4 = @import("mat4.zig").Mat4;
const f32x4 = @Vector(4, f32);
const i32x4 = @Vector(4, i32);

pub const vec4 = Vec4.new;

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub inline fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return Vec4{ .x = x, .y = y, .z = z, .w = w };
    }

    pub inline fn identity() Vec4 {
        return new(0.0, 0.0, 0.0, 1.0);
    }

    pub inline fn add(left: Vec4, right: Vec4) Vec4 {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);
        return @bitCast(l + r);
    }

    pub inline fn sub(left: Vec4, right: Vec4) Vec4 {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);
        return @bitCast(l - r);
    }

    pub inline fn mul(left: Vec4, right: Vec4) Vec4 {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);
        return @bitCast(l * r);
    }

    pub inline fn mulf(left: Vec4, right: f32) Vec4 {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @splat(right);
        return @bitCast(l * r);
    }

    pub inline fn mulM(a: Vec4, b: Mat4) Vec4 {
        @setFloatMode(.optimized);
        const m: [4]f32x4 = @bitCast(b);

        var result = m[0] * @as(f32x4, @splat(a.x));
        result += m[1] * @as(f32x4, @splat(a.y));
        result += m[2] * @as(f32x4, @splat(a.z));
        result += m[3] * @as(f32x4, @splat(a.w));

        return @bitCast(result);
    }

    test mulM {
        const a = new(1, 2, 3, 4);
        const b = Mat4{
            // zig fmt: off
            .a11 =  1, .a12 =  2, .a13 =  3, .a14 = 4, 
            .a21 =  5, .a22 =  6, .a23 =  7, .a24 = 8, 
            .a31 =  9, .a32 = 10, .a33 = 11, .a34 = 12, 
            .a41 = 13, .a42 = 14, .a43 = 15, .a44 = 16,
            // zig fmt: on
        };

        try std.testing.expectEqual(
            new(30, 70, 110, 150),
            a.mulM(b),
        );
    }

    pub inline fn div(left: Vec4, right: Vec4) Vec4 {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);
        return @bitCast(l / r);
    }

    pub inline fn divf(left: Vec4, right: f32) Vec4 {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @splat(right);
        return @bitCast(l / r);
    }

    pub inline fn dot(left: Vec4, right: Vec4) f32 {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);
        return @reduce(.Add, l * r);
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
