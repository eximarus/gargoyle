const std = @import("std");
const math = @import("../math.zig");

pub const Camera = union(enum) {
    ortho: OrthoCamera,
    perspective: PerspectiveCamera,

    pub fn calcViewProjMat(self: Camera) math.Mat {
        return switch (self) {
            inline else => |case| case.calcViewProjMat(),
        };
    }
};

pub const PerspectiveCamera = struct {
    fovy: f32,
    aspect: f32,
    near: f32,
    far: f32,

    position: math.V3F32,
    rotation: math.V3F32,

    pub fn init(
        fovy: f32,
        aspect: f32,
        near: f32,
        far: f32,
    ) PerspectiveCamera {
        return PerspectiveCamera{
            .fovy = fovy,
            .aspect = aspect,
            .near = near,
            .far = far,
            .position = math.V3F32{ .x = 0.0, .y = 0.0, .z = 0.0 },
            .rotation = math.V3F32{ .x = 0.0, .y = 0.0, .z = 0.0 },
        };
    }

    pub fn create(
        allocator: *std.mem.Allocator,
        fovy: f32,
        aspect: f32,
        near: f32,
        far: f32,
    ) !*const PerspectiveCamera {
        const cam = try allocator.create(PerspectiveCamera);
        cam.* = init(fovy, aspect, near, far);
    }

    pub fn calcProjMat(self: PerspectiveCamera) math.Mat {
        return math.perspectiveFovRhGl(
            self.fovy,
            self.aspect,
            self.near,
            self.far,
        );
    }

    pub fn calcViewMat(self: PerspectiveCamera) math.Mat {
        const x = math.mul(
            math.translation(
                self.position.x,
                self.position.y,
                self.position.z,
            ),
            math.rotationX(self.rotation.x),
        );
        const y = math.mul(x, math.rotationY(self.rotation.y));
        return math.inverse(math.mul(y, math.rotationZ(self.rotation.z)));
    }

    pub fn calcViewProjMat(self: PerspectiveCamera) math.Mat {
        const proj_mat = self.calcProjMat();
        const view_mat = self.calcViewMat();
        return math.mul(proj_mat, view_mat);
    }
};

pub const OrthoCamera = struct {
    left: f32,
    right: f32,
    bottom: f32,
    top: f32,
    near: f32,
    far: f32,

    position: math.V2F32,
    rotation: f32,

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
            .position = math.V2F32{ .x = 0.0, .y = 0.0 },
            .rotation = 0.0,
        };
    }

    pub fn create(
        allocator: *std.mem.Allocator,
        left: f32,
        right: f32,
        bottom: f32,
        top: f32,
        near: f32,
        far: f32,
    ) !*const OrthoCamera {
        const cam = try allocator.create(OrthoCamera);
        cam.* = init(left, right, bottom, top, near, far);
    }

    pub fn calcProjMat(self: OrthoCamera) math.Mat {
        return math.orthographicOffCenterRhGl(
            self.left,
            self.right,
            self.bottom,
            self.top,
            self.near,
            self.far,
        );
    }

    pub fn calcViewMat(self: OrthoCamera) math.Mat {
        return math.inverse(math.mul(
            math.translation(self.position.x, self.position.y, 0.0),
            math.rotationZ(self.rotation),
        ));
    }

    pub fn calcViewProjMat(self: OrthoCamera) math.Mat {
        const proj_mat = self.calcProjMat();
        const view_mat = self.calcViewMat();
        return math.mul(proj_mat, view_mat);
    }
};
