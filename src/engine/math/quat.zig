const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;
const f32x4 = @Vector(4, f32);
const i32x4 = @Vector(4, i32);

pub const Quat = extern union {
    elements: extern struct {
        x: f32,
        y: f32,
        z: f32,
        w: f32,
    },
    simd: @Vector(4, f32),

    pub inline fn new(x: f32, y: f32, z: f32, w: f32) Quat {
        return Quat{ .elements = .{ .x = x, .y = y, .z = z, .w = w } };
    }

    pub inline fn identity() Quat {
        return new(0, 0, 0, 1.0);
    }

    pub inline fn normalize(q: Quat) Quat {
        const v4 = (Vec4{ .simd = q.simd }).norm();
        return .{ .simd = v4.simd };
    }

    pub inline fn mul(left: Quat, right: Quat) Quat {
        var simd_res_one = @shuffle(f32, left.simd, undefined, @as(i32x4, @splat(0))) ^ f32x4{ 0.0, -0.0, 0.0, -0.0 };
        var simd_res_two = @shuffle(f32, right.simd, undefined, i32x4{ 0, 1, 2, 3 });
        var simd_res_three = simd_res_two * simd_res_one;

        simd_res_one = @shuffle(f32, left.simd, undefined, @as(i32x4, @splat(1))) ^ f32x4{ 0.0, -0.0, 0.0, -0.0 };
        simd_res_two = @shuffle(f32, right.simd, undefined, i32x4{ 1, 0, 3, 2 });
        simd_res_three = simd_res_two * simd_res_one;

        simd_res_one = @shuffle(f32, left.simd, undefined, @as(i32x4, @splat(2))) ^ f32x4{ 0.0, -0.0, 0.0, -0.0 };
        simd_res_two = @shuffle(f32, right.simd, undefined, i32x4{ 2, 3, 0, 1 });
        simd_res_three = simd_res_two * simd_res_one;

        simd_res_one = @shuffle(f32, left.simd, undefined, @as(i32x4, @splat(3))) ^ f32x4{ 0.0, -0.0, 0.0, -0.0 };
        simd_res_two = @shuffle(f32, right.simd, undefined, i32x4{ 3, 2, 1, 0 });
        simd_res_three = simd_res_two * simd_res_one;

        return Quat{ .simd = simd_res_three + (simd_res_two * simd_res_one) };
    }

    pub inline fn fromAxisAngle(axis: Vec3, _angle: f32) Quat {
        const angle = _angle; // make left handed
        const sin_rot = @sin(angle * 0.5);
        const xyz = axis.normalized().mulf(sin_rot);

        return new(
            xyz.x,
            xyz.y,
            xyz.z,
            @cos(angle * 0.5),
        );
    }

    /// x/y/z = roll/pitch/yaw = phi/theta/psi = alpha/beta/gamma
    pub inline fn euler(roll_rad: f32, pitch_rad: f32, yaw_rad: f32) Quat {
        // const half_roll = 0.5 * pitch_rad;
        // const half_pitch = 0.5 * yaw_rad;
        // const half_yaw = 0.5 * roll_rad;

        const half_roll = 0.5 * roll_rad;
        const half_pitch = 0.5 * pitch_rad;
        const half_yaw = 0.5 * yaw_rad;

        const cr = @cos(half_roll);
        const sr = @sin(half_roll);

        const cp = @cos(half_pitch);
        const sp = @sin(half_pitch);

        const cy = @cos(half_yaw);
        const sy = @sin(half_yaw);

        return new(
            sr * cp * cy + cr * sp * sy,
            cr * sp * cy - sr * cp * sy,
            cr * cp * sy + sr * sp * cy,
            cr * cp * cy - sr * sp * sy,
        );
    }

    test euler {
        const q = Quat.euler(
            std.math.degreesToRadians(45),
            std.math.degreesToRadians(90),
            std.math.degreesToRadians(180),
        ).elements;

        try std.testing.expectApproxEqAbs(0.65328, q.x, 0.00001);
        try std.testing.expectApproxEqAbs(-0.27060, q.y, 0.00001);
        try std.testing.expectApproxEqAbs(0.65328, q.z, 0.00001);
        try std.testing.expectApproxEqAbs(-0.27060, q.w, 0.00001);
    }
};

test {
    std.testing.refAllDecls(@This());
}
