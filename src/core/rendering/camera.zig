const std = @import("std");
const math = @import("math");

pub const Camera = union(enum) {
    ortho: OrthoCamera,

    pub fn calcProjMat(self: Camera) math.Mat4 {
        return switch (self) {
            inline else => |case| case.calcProjMat(),
        };
    }
};

pub const OrthoCamera = struct {
    left: f32,
    right: f32,
    bottom: f32,
    top: f32,
    near: f32,
    far: f32,

    size: f32 = 5,

    pub fn fromSize(width: u32, height: u32) OrthoCamera {
        const aspect_ratio = @as(f32, width) / @as(f32, height);
        return init(-1 * aspect_ratio, aspect_ratio, -1, 1, -1, 1);
    }

    pub fn init(
        left: f32,
        right: f32,
        bottom: f32,
        top: f32,
        near: f32,
        far: f32,
    ) OrthoCamera {
        return OrthoCamera{
            .left = left,
            .right = right,
            .bottom = bottom,
            .top = top,
            .near = near,
            .far = far,
        };
    }

    pub fn calcProjMat(self: OrthoCamera) math.Mat4 {
        return math.Mat4.orthographic(
            self.left * self.size,
            self.right * self.size,
            self.bottom * self.size,
            self.top * self.size,
            self.near,
            self.far,
        );
    }
};
