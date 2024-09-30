const std = @import("std");

pub const Mat2 = extern struct {
    data: [2 * 2]f32,

    pub inline fn identity() Mat2 {
        var mat = std.mem.zeroes(Mat2);
        mat.data[0] = 1.0;
        mat.data[3] = 1.0;
        return mat;
    }
};
