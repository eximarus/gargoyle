const std = @import("std");

pub const Mat3 = extern union {
    data: [3 * 3]f32,

    pub inline fn identity() Mat3 {
        var mat = std.mem.zeroes(Mat3);
        mat.data[0] = 1.0;
        mat.data[4] = 1.0;
        mat.data[8] = 1.0;
        return mat;
    }

    pub inline fn mul(left: Mat3, right: Mat3) Mat3 {
        @setFloatMode(.optimized);

        var out_matrix: Mat3 = undefined;

        out_matrix[0] = left[0] * right[0] + left[3] * right[1] + left[6] * right[2];
        out_matrix[1] = left[1] * right[0] + left[4] * right[1] + left[7] * right[2];
        out_matrix[2] = left[2] * right[0] + left[5] * right[1] + left[8] * right[2];

        out_matrix[3] = left[0] * right[3] + left[3] * right[4] + left[6] * right[5];
        out_matrix[4] = left[1] * right[3] + left[4] * right[4] + left[7] * right[5];
        out_matrix[5] = left[2] * right[3] + left[5] * right[4] + left[8] * right[5];

        out_matrix[6] = left[0] * right[6] + left[3] * right[7] + left[6] * right[8];
        out_matrix[7] = left[1] * right[6] + left[4] * right[7] + left[7] * right[8];
        out_matrix[8] = left[2] * right[6] + left[5] * right[7] + left[8] * right[8];

        return out_matrix;
    }
};
