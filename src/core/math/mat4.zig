const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;
const Quat = @import("quat.zig").Quat;
const f32x4 = @Vector(4, f32);
const i32x4 = @Vector(4, i32);

const f32x16 = @Vector(16, f32);
const i32x16 = @Vector(16, i32);

pub const Mat4 = extern union {
    /// column-major
    elements: [4 * 4]f32,
    columns: [4]f32x4,
    simd: f32x16,

    pub inline fn identity() Mat4 {
        var mat = std.mem.zeroes(Mat4);
        mat.elements[0] = 1.0;
        mat.elements[5] = 1.0;
        mat.elements[10] = 1.0;
        mat.elements[15] = 1.0;
        return mat;
    }

    pub inline fn mul(left: Mat4, right: Mat4) Mat4 {
        @setFloatMode(.optimized);

        const right0 = std.simd.repeat(16, left.columns[0]);
        const right1 = std.simd.repeat(16, left.columns[1]);
        const right2 = std.simd.repeat(16, left.columns[2]);
        const right3 = std.simd.repeat(16, left.columns[3]);

        const l = right.simd;

        var result = @shuffle(f32, l, undefined, i32x16{ 0, 0, 0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12, 12, 12, 12 }) * right0;
        result += @shuffle(f32, l, undefined, i32x16{ 1, 1, 1, 1, 5, 5, 5, 5, 9, 9, 9, 9, 13, 13, 13, 13 }) * right1;
        result += @shuffle(f32, l, undefined, i32x16{ 2, 2, 2, 2, 6, 6, 6, 6, 10, 10, 10, 10, 14, 14, 14, 14 }) * right2;
        result += @shuffle(f32, l, undefined, i32x16{ 3, 3, 3, 3, 7, 7, 7, 7, 11, 11, 11, 11, 15, 15, 15, 15 }) * right3;

        return Mat4{ .simd = result };
    }

    test mul {
        const a = Mat4{
            .columns = .{
                f32x4{ 1, 2, 3, 4 },
                f32x4{ 1, 2, 3, 4 },
                f32x4{ 1, 2, 3, 4 },
                f32x4{ 1, 2, 3, 4 },
            },
        };

        const b = Mat4{
            .columns = .{
                f32x4{ 1, 1, 1, 1 },
                f32x4{ 2, 2, 2, 2 },
                f32x4{ 3, 3, 3, 3 },
                f32x4{ 4, 4, 4, 4 },
            },
        };

        try std.testing.expectEqualSlices(
            f32,
            &[_]f32{ 4, 8, 12, 16, 8, 16, 24, 32, 12, 24, 36, 48, 16, 32, 48, 64 },
            &a.mul(b).elements,
        );
    }

    pub inline fn perspective(
        fov_y: f32,
        width: u32,
        height: u32,
        znear: f32,
        zfar: f32,
    ) Mat4 {
        const aspect = @as(f32, @floatFromInt(width)) /
            @as(f32, @floatFromInt(height));
        return perspectiveAspect(fov_y, aspect, znear, zfar);
    }

    pub inline fn perspectiveAspect(
        fov_y: f32,
        aspect: f32,
        znear: f32,
        zfar: f32,
    ) Mat4 {
        const fov_rad = fov_y * std.math.rad_per_deg;
        const h = 1.0 / @tan(fov_rad * 0.5);
        const w = h / aspect;

        // normal depth
        // const a = zfar / (zfar - znear);
        // const b = (-znear * zfar) / (zfar - znear);

        // reverse depth
        // const a = znear / (znear - zfar);
        // const b = -znear * a;
        const a = -znear / (zfar - znear);
        const b = (znear * zfar) / (zfar - znear);

        return projection(w, h, a, b);
    }

    pub inline fn orthographicMag(
        xmag: f32,
        ymag: f32,
        znear: f32,
        zfar: f32,
    ) Mat4 {
        const a = 1.0 / (zfar - znear);
        const b = (-znear * zfar) / (zfar - znear);
        return projection(ymag, xmag, a, b);
    }

    pub inline fn orthographic(
        width: f32,
        height: f32,
        znear: f32,
        zfar: f32,
    ) Mat4 {
        const h = 2 / width;
        const w = 2 / height;
        const a = 1.0 / (zfar - znear);
        const b = (-znear * zfar) / (zfar - znear);

        return projection(w, h, a, b);
    }

    pub inline fn projection(w: f32, h: f32, a: f32, b: f32) Mat4 {
        var out_matrix: Mat4 = std.mem.zeroes(Mat4);
        out_matrix.elements[0] = w;
        out_matrix.elements[5] = h;
        out_matrix.elements[10] = a;
        out_matrix.elements[11] = 1.0;
        out_matrix.elements[14] = b;

        return out_matrix;
    }

    pub inline fn view(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = center.sub(eye).norm();
        const s = up.cross(f).norm();
        const u = f.cross(s);

        var out_matrix: Mat4 = undefined;

        out_matrix.elements[0] = s.x;
        out_matrix.elements[1] = u.x;
        out_matrix.elements[2] = f.x;
        out_matrix.elements[3] = 0.0;

        out_matrix.elements[4] = s.y;
        out_matrix.elements[5] = u.y;
        out_matrix.elements[6] = f.y;
        out_matrix.elements[7] = 0.0;

        out_matrix.elements[8] = s.z;
        out_matrix.elements[9] = u.z;
        out_matrix.elements[10] = f.z;
        out_matrix.elements[11] = 0.0;

        out_matrix.elements[12] = -s.dot(eye);
        out_matrix.elements[13] = -u.dot(eye);
        out_matrix.elements[14] = -f.dot(eye);
        out_matrix.elements[15] = 1.0;

        return out_matrix;
    }

    pub inline fn transformation(pos: Vec3, rot: Quat, scale: Vec3) Mat4 {
        return scaling(scale).mul(rotation(rot)).mul(translation(pos));
    }

    pub inline fn translation(position: Vec3) Mat4 {
        var out_matrix = Mat4.identity();
        out_matrix.elements[12] = position.x;
        out_matrix.elements[13] = position.y;
        out_matrix.elements[14] = position.z;
        return out_matrix;
    }

    pub inline fn rotation(quat: Quat) Mat4 {
        var out_matrix: Mat4 = undefined;
        const q = quat.elements;

        const xy2 = 2.0 * q.x * q.y;
        const xz2 = 2.0 * q.x * q.z;
        const yz2 = 2.0 * q.y * q.z;

        const xx2 = 2.0 * q.x * q.x;
        const yy2 = 2.0 * q.y * q.y;
        const zz2 = 2.0 * q.z * q.z;

        const xw2 = 2.0 * q.x * q.w;
        const yw2 = 2.0 * q.y * q.w;
        const zw2 = 2.0 * q.z * q.w;

        out_matrix.elements[0] = 1.0 - yy2 - zz2;
        out_matrix.elements[1] = xy2 + zw2;
        out_matrix.elements[2] = xz2 - yw2;
        out_matrix.elements[3] = 0.0;

        out_matrix.elements[4] = xy2 - zw2;
        out_matrix.elements[5] = 1.0 - xx2 - zz2;
        out_matrix.elements[6] = yz2 + xw2;
        out_matrix.elements[7] = 0.0;

        out_matrix.elements[8] = xz2 + yw2;
        out_matrix.elements[9] = yz2 - xw2;
        out_matrix.elements[10] = 1.0 - xx2 - yy2;
        out_matrix.elements[11] = 0.0;

        out_matrix.elements[12] = 0.0;
        out_matrix.elements[13] = 0.0;
        out_matrix.elements[14] = 0.0;
        out_matrix.elements[15] = 1.0;

        return out_matrix;
    }

    pub inline fn scaling(scale: Vec3) Mat4 {
        var out_matrix = Mat4.identity();
        out_matrix.elements[0] = scale.x;
        out_matrix.elements[5] = scale.y;
        out_matrix.elements[10] = scale.z;
        return out_matrix;
    }
};

test {
    std.testing.refAllDecls(@This());
}
