const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;
const f32x4 = @Vector(4, f32);
const i32x4 = @Vector(4, i32);
const u32x4 = @Vector(4, u32);

pub const Quat = extern union {
    const Elements = extern struct {
        w: f32,
        x: f32,
        y: f32,
        z: f32,
    };
    elements: Elements,
    simd: f32x4,

    pub inline fn new(w: f32, x: f32, y: f32, z: f32) Quat {
        return Quat{ .elements = .{ .w = w, .x = x, .y = y, .z = z } };
    }

    pub inline fn identity() Quat {
        return new(1.0, 0, 0, 0);
    }

    pub inline fn norm(q: Quat) Quat {
        const v4: Vec4 = @bitCast(q);
        return @bitCast(v4.norm());
    }

    pub inline fn add(left: Quat, right: Quat) Quat {
        return Quat{ .simd = left.simd + right.simd };
    }

    pub inline fn sub(left: Quat, right: Quat) Quat {
        return Quat{ .simd = left.simd - right.simd };
    }

    pub inline fn mulf(left: Quat, scalar: f32) Quat {
        return Quat{ .simd = left.simd * @as(f32x4, @splat(scalar)) };
    }

    pub inline fn divf(left: Quat, scalar: f32) Quat {
        return Quat{ .simd = left.simd / @as(f32x4, @splat(scalar)) };
    }

    pub inline fn mul(left: Quat, right: Quat) Quat {
        return Quat{
            .simd = mulCol(left.simd, right.simd, 0, @splat(0), u32x4{ 0, 1, 2, 3 }) +
                mulCol(left.simd, right.simd, 1, u32x4{ 0x80000000, 0, 0x80000000, 0 }, u32x4{ 1, 0, 3, 2 }) +
                mulCol(left.simd, right.simd, 2, u32x4{ 0x80000000, 0, 0, 0x80000000 }, u32x4{ 2, 3, 0, 1 }) +
                mulCol(left.simd, right.simd, 3, u32x4{ 0x80000000, 0x80000000, 0, 0 }, u32x4{ 3, 2, 1, 0 }),
        };
    }

    inline fn mulCol(left: f32x4, right: f32x4, i: u32, xor: u32x4, mask: u32x4) f32x4 {
        const r1: f32x4 = @bitCast(@shuffle(u32, @as(u32x4, @bitCast(left)), undefined, @as(u32x4, @splat(i))) ^ xor);
        const r2: f32x4 = @shuffle(f32, right, undefined, mask);
        return r1 * r2;
    }

    test mul {
        const q0 = new(1.0, 2.0, 3.0, 4.0);
        const q1 = new(4.0, 3.0, 2.0, 1.0);
        const res = q0.mul(q1);

        try std.testing.expectApproxEqAbs(-12.0, res.elements.w, 0.0001);
        try std.testing.expectApproxEqAbs(6.0, res.elements.x, 0.0001);
        try std.testing.expectApproxEqAbs(24.0, res.elements.y, 0.0001);
        try std.testing.expectApproxEqAbs(12.0, res.elements.z, 0.0001);
    }

    pub inline fn fromAxisAngle(axis: Vec3, angle: f32) Quat {
        const sin_rot = @sin(angle * 0.5);
        const xyz = axis.norm().mulf(sin_rot);

        return new(
            @cos(angle * 0.5),
            xyz.x,
            xyz.y,
            xyz.z,
        );
    }

    pub inline fn euler(x: f32, y: f32, z: f32) Quat {
        const half_x = 0.5 * x * std.math.rad_per_deg;
        const half_y = 0.5 * y * std.math.rad_per_deg;
        const half_z = 0.5 * z * std.math.rad_per_deg;

        const cx = @cos(half_x);
        const sx = @sin(half_x);

        const cz = @cos(half_z);
        const sz = @sin(half_z);

        const cy = @cos(half_y);
        const sy = @sin(half_y);

        return new(
            cx * cy * cz + sx * sy * sz,
            sx * cy * cz - cx * sy * sz,
            cx * sy * cz + sx * cy * sz,
            cx * cy * sz - sx * sy * cz,
        );
    }

    test euler {
        const q = Quat.euler(45, 90, 180).elements;

        try std.testing.expectApproxEqAbs(-0.65328, q.x, 0.00001);
        try std.testing.expectApproxEqAbs(0.27060, q.y, 0.00001);
        try std.testing.expectApproxEqAbs(0.65328, q.z, 0.00001);
        try std.testing.expectApproxEqAbs(0.27060, q.w, 0.00001);
    }
};

test {
    std.testing.refAllDecls(@This());
}
