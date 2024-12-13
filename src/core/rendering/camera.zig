const std = @import("std");
const math = @import("../root.zig").math;

pub const Camera = struct {
    view: math.Mat4,
    proj: math.Mat4,
    view_proj: math.Mat4,
    frustum_planes: [6]math.Vec4,
};

pub fn createPerspective(
    fov_y: f32,
    aspect_ratio: f32,
    znear: f32,
    zfar: f32,
    eye: math.Vec3,
    center: math.Vec3,
    up: math.Vec3,
) Camera {
    const proj = math.Mat4.perspective(fov_y, aspect_ratio, znear, zfar);
    const view = math.Mat4.view(eye, center, up);
    const view_proj = proj.mul(view);

    var cam = Camera{
        .view = view,
        .proj = proj,
        .view_proj = view_proj,
        .frustum_planes = undefined,
    };

    extractPlanes(&cam.frustum_planes, view_proj, false);

    return cam;
}

fn extractPlanes(planes: []math.Vec4, view_proj: math.Mat4, normalize: bool) void {
    planes[0].x = view_proj.a41 + view_proj.a11;
    planes[0].y = view_proj.a42 + view_proj.a12;
    planes[0].z = view_proj.a43 + view_proj.a13;
    planes[0].w = view_proj.a44 + view_proj.a14;

    planes[1].x = view_proj.a41 - view_proj.a11;
    planes[1].y = view_proj.a42 - view_proj.a12;
    planes[1].z = view_proj.a43 - view_proj.a13;
    planes[1].w = view_proj.a44 - view_proj.a14;

    planes[2].x = view_proj.a41 - view_proj.a21;
    planes[2].y = view_proj.a42 - view_proj.a22;
    planes[2].z = view_proj.a43 - view_proj.a23;
    planes[2].w = view_proj.a44 - view_proj.a24;

    planes[3].x = view_proj.a41 + view_proj.a21;
    planes[3].y = view_proj.a42 + view_proj.a22;
    planes[3].z = view_proj.a43 + view_proj.a23;
    planes[3].w = view_proj.a44 + view_proj.a24;

    planes[4].x = view_proj.a41 + view_proj.a31;
    planes[4].y = view_proj.a42 + view_proj.a32;
    planes[4].z = view_proj.a43 + view_proj.a33;
    planes[4].w = view_proj.a44 + view_proj.a34;

    planes[5].x = view_proj.a41 - view_proj.a31;
    planes[5].y = view_proj.a42 - view_proj.a32;
    planes[5].z = view_proj.a43 - view_proj.a33;
    planes[5].w = view_proj.a44 - view_proj.a34;

    if (normalize == true) {
        for (planes) |*plane| {
            plane.* = plane.norm();
        }
    }
}
