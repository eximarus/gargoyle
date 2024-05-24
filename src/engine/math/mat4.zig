const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;

pub const Mat4 = extern struct {
    data: [4 * 4]f32,

    pub inline fn identity() Mat4 {
        var mat = std.mem.zeroes(Mat4);
        mat.data[0] = 1.0;
        mat.data[5] = 1.0;
        mat.data[10] = 1.0;
        mat.data[15] = 1.0;
        return mat;
    }

    // row-major
    pub inline fn mul(left: Mat4, right: Mat4) Mat4 {
        @setFloatMode(.optimized);
        var out_matrix = identity();

        const a = left.data;
        const b = right.data;

        inline for (0..4) |col| {
            const va = @Vector(4, f32){
                a[col * 4 + 0],
                a[col * 4 + 1],
                a[col * 4 + 2],
                a[col * 4 + 3],
            };
            inline for (0..4) |row| {
                const vb = @Vector(4, f32){
                    b[0 * 4 + row],
                    b[1 * 4 + row],
                    b[2 * 4 + row],
                    b[3 * 4 + row],
                };

                out_matrix.data[col * 4 + row] =
                    @reduce(.Add, va * vb);
            }
        }
        return out_matrix;
    }

    test mul {
        const a = Mat4{
            .data = .{
                0.1, 0.2, 0.3, 0.4,
                0.5, 0.6, 0.7, 0.8,
                0.9, 1.0, 1.1, 1.2,
                1.3, 1.4, 1.5, 1.6,
            },
        };
        const b = Mat4{
            .data = .{
                1.7, 1.8, 1.9, 2.0,
                2.1, 2.2, 2.3, 2.4,
                2.5, 2.6, 2.7, 2.8,
                2.9, 3.0, 3.1, 3.2,
            },
        };

        const c = a.mul(b).data;
        try std.testing.expectApproxEqAbs(c[0], 2.5, 0.0001);
        try std.testing.expectApproxEqAbs(c[1], 2.6, 0.0001);
        try std.testing.expectApproxEqAbs(c[2], 2.7, 0.0001);
        try std.testing.expectApproxEqAbs(c[3], 2.8, 0.0001);

        try std.testing.expectApproxEqAbs(c[4], 6.18, 0.0001);
        try std.testing.expectApproxEqAbs(c[5], 6.44, 0.0001);
        try std.testing.expectApproxEqAbs(c[6], 6.7, 0.0001);
        try std.testing.expectApproxEqAbs(c[7], 6.96, 0.0001);

        try std.testing.expectApproxEqAbs(c[8], 9.86, 0.0001);
        try std.testing.expectApproxEqAbs(c[9], 10.28, 0.0001);
        try std.testing.expectApproxEqAbs(c[10], 10.7, 0.0001);
        try std.testing.expectApproxEqAbs(c[11], 11.12, 0.0001);

        try std.testing.expectApproxEqAbs(c[12], 13.54, 0.0001);
        try std.testing.expectApproxEqAbs(c[13], 14.12, 0.0001);
        try std.testing.expectApproxEqAbs(c[14], 14.7, 0.0001);
        try std.testing.expectApproxEqAbs(c[15], 15.28, 0.0001);
    }

    // pub inline fn perspective(
    //     fov_radians: f32,
    //     aspect_ratio: f32,
    //     near_clip: f32,
    //     far_clip: f32,
    // ) Mat4 {
    //     const half_tan_fov = std.math.tan(fov_radians * 0.5);
    //     var out_matrix: Mat4 = std.mem.zeroes(Mat4);
    //     out_matrix.data[0] = 1.0 / (aspect_ratio * half_tan_fov);
    //     out_matrix.data[5] = 1.0 / half_tan_fov;
    //     out_matrix.data[10] = -((far_clip + near_clip) / (far_clip - near_clip));
    //     out_matrix.data[11] = -1.0;
    //     out_matrix.data[14] =
    //         -((2.0 * far_clip * near_clip) / (far_clip - near_clip));
    //     return out_matrix;
    // }

    pub inline fn perspective(
        fov_radians: f32,
        aspect_ratio: f32,
        near_clip: f32,
        far_clip: f32,
    ) Mat4 {
        const f = 1.0 / @tan(fov_radians * 0.5);
        var out_matrix: Mat4 = identity();
        out_matrix.data[0] = f / aspect_ratio;
        out_matrix.data[5] = f;
        out_matrix.data[10] = (near_clip + far_clip) / (near_clip - far_clip);
        out_matrix.data[11] = -1.0;
        out_matrix.data[14] = 2.0 * far_clip * near_clip / (near_clip - far_clip);
        out_matrix.data[15] = 0.0;
        return out_matrix;
    }

    pub inline fn translation(position: Vec3) Mat4 {
        var out_matrix = identity();
        out_matrix.data[12] = position.x;
        out_matrix.data[13] = position.y;
        out_matrix.data[14] = position.z;
        return out_matrix;
    }
};

test {
    std.testing.refAllDecls(@This());
}
