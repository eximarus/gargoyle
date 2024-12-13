const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;
const f32x4 = @Vector(4, f32);
const i32x4 = @Vector(4, i32);
const u32x4 = @Vector(4, u32);

pub const Quat = extern struct {
    a: f32,
    b: f32,
    c: f32,
    d: f32,

    pub inline fn new(a: f32, b: f32, c: f32, d: f32) Quat {
        return Quat{ .a = a, .b = b, .c = c, .d = d };
    }

    pub inline fn identity() Quat {
        return new(1.0, 0, 0, 0);
    }

    pub inline fn add(left: Quat, right: Quat) Quat {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);
        return @bitCast(l + r);
    }

    pub inline fn sub(left: Quat, right: Quat) Quat {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);
        return @bitCast(l - r);
    }

    pub inline fn mulf(left: Quat, scalar: f32) Quat {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @splat(scalar);
        return @bitCast(l * r);
    }

    pub inline fn divf(left: Quat, scalar: f32) Quat {
        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @splat(scalar);
        return @bitCast(l / r);
    }

    pub inline fn mul(left: Quat, right: Quat) Quat {
        @setFloatMode(.optimized);

        const l: f32x4 = @bitCast(left);
        const r: f32x4 = @bitCast(right);

        return @bitCast(
            mulCol(l, r, 0, @splat(0), u32x4{ 0, 1, 2, 3 }) +
                mulCol(l, r, 1, u32x4{ 0x80000000, 0, 0x80000000, 0 }, u32x4{ 1, 0, 3, 2 }) +
                mulCol(l, r, 2, u32x4{ 0x80000000, 0, 0, 0x80000000 }, u32x4{ 2, 3, 0, 1 }) +
                mulCol(l, r, 3, u32x4{ 0x80000000, 0x80000000, 0, 0 }, u32x4{ 3, 2, 1, 0 }),
        );
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

        try std.testing.expectApproxEqAbs(-12.0, res.a, 0.0001);
        try std.testing.expectApproxEqAbs(6.0, res.b, 0.0001);
        try std.testing.expectApproxEqAbs(24.0, res.c, 0.0001);
        try std.testing.expectApproxEqAbs(12.0, res.d, 0.0001);
    }

    pub inline fn norm(q: Quat) Quat {
        const v4: Vec4 = @bitCast(q);
        return @bitCast(v4.norm());
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
        const q = Quat.euler(45, 90, 180);

        try std.testing.expectApproxEqAbs(-0.65328, q.b, 0.00001);
        try std.testing.expectApproxEqAbs(0.27060, q.c, 0.00001);
        try std.testing.expectApproxEqAbs(0.65328, q.d, 0.00001);
        try std.testing.expectApproxEqAbs(0.27060, q.a, 0.00001);
    }
};

test {
    std.testing.refAllDecls(@This());
}
