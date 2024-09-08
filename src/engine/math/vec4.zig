const std = @import("std");
const f32x4 = @Vector(4, f32);
const i32x4 = @Vector(4, i32);

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

    pub inline fn mul(left: Vec4, right: Vec4) Vec4 {
        var result: Vec4 = undefined;
        result.simd = left.simd * right.simd;
        return result;
    }

    pub inline fn dot(left: Vec4, right: Vec4) f32 {
        var simd_res_one = left.simd * right.simd;
        var simd_res_two = @shuffle(f32, simd_res_one, undefined, i32x4{ 2, 3, 0, 1 });

        simd_res_one += simd_res_two;
        simd_res_two = @shuffle(f32, simd_res_one, undefined, i32x4{ 0, 1, 2, 3 });
        simd_res_one += simd_res_two;

        return @reduce(.Min, simd_res_one);
    }

    pub inline fn mulf(left: Vec4, right: f32) Vec4 {
        return Vec4{ .simd = left.simd * @as(f32x4, @splat(right)) };
    }

    pub inline fn norm(self: Vec4) Vec4 {
        return self.mulf(1.0 / @sqrt(self.dot(self)));
    }
};
