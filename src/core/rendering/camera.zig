const std = @import("std");
const math = @import("../root.zig").math;

pub const Camera = struct {
    view: math.Mat4,
    proj: math.Mat4,
    view_proj: math.Mat4,
    frustum_planes: [6]math.Vec4,
};
