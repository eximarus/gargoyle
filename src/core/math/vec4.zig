const std = @import("std");
const Mat4 = @import("mat4.zig").Mat4;
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

    pub inline fn mulM(a: Vec4, b: Mat4) Vec4 {
        @setFloatMode(.optimized);

        var result = b.columns[0] * @as(f32x4, @splat(a.elements.x));
        result += b.columns[1] * @as(f32x4, @splat(a.elements.y));
        result += b.columns[2] * @as(f32x4, @splat(a.elements.z));
        result += b.columns[3] * @as(f32x4, @splat(a.elements.w));

        return Vec4{ .simd = result };
    }

    test mulM {
        const a = Vec4{
            .simd = f32x4{ 1, 2, 3, 4 },
        };

        const b = Mat4{
            .columns = .{
                f32x4{ 1, 5, 9, 13 },
                f32x4{ 2, 6, 10, 14 },
                f32x4{ 3, 7, 11, 15 },
                f32x4{ 4, 8, 12, 16 },
            },
        };

        try std.testing.expectEqual(
            (Vec4{ .elements = .{
                .x = 30,
                .y = 70,
                .z = 110,
                .w = 150,
            } }).elements,
            a.mulM(b).elements,
        );
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
