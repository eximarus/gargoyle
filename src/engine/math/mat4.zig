const std = @import("std");

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
};
