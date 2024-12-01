const std = @import("std");

pub const Mat2 = extern struct {
    data: [2 * 2]f32,

    pub inline fn identity() Mat2 {
        var mat = std.mem.zeroes(Mat2);
        mat.data[0] = 1.0;
        mat.data[3] = 1.0;
        return mat;
    }

    pub inline fn mul(left_mat: Mat2, right_mat: Mat2) Mat2 {
        @setFloatMode(.optimized);

        const left = left_mat.data;
        const right = right_mat.data;

        var out_matrix: Mat2 = undefined;
        out_matrix.data[0] = left[0] * right[0] + left[2] * right[1];
        out_matrix.data[1] = left[1] * right[0] + left[3] * right[1];
        out_matrix.data[2] = left[0] * right[2] + left[2] * right[3];
        out_matrix.data[3] = left[1] * right[2] + left[3] * right[3];

        return out_matrix;
    }

    test mul {
        const m1 = Mat2{ .data = [_]f32{ 1, 3, 2, 4 } };
        const m2 = Mat2{ .data = [_]f32{ 5, 7, 6, 8 } };

        const m3 = m1.mul(m2);
        try std.testing.expectEqualSlices(f32, &.{ 19, 43, 22, 50 }, &m3.data);
    }
};

test {
    std.testing.refAllDecls(@This());
}
