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
};
