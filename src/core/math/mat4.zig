const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;
const Quat = @import("quat.zig").Quat;
const f32x4 = @Vector(4, f32);
const i32x4 = @Vector(4, i32);

const f32x16 = @Vector(16, f32);
const i32x16 = @Vector(16, i32);

/// column-major
pub const Mat4 = extern struct {
    // zig fmt: off
    a11: f32, a21: f32, a31: f32, a41: f32, // col 1
    a12: f32, a22: f32, a32: f32, a42: f32, // col 2
    a13: f32, a23: f32, a33: f32, a43: f32, // col 3
    a14: f32, a24: f32, a34: f32, a44: f32, // col 4
    // zig fmt: on

    pub inline fn identity() Mat4 {
        var mat = std.mem.zeroes(Mat4);
        mat.a11 = 1.0;
        mat.a22 = 1.0;
        mat.a33 = 1.0;
        mat.a44 = 1.0;
        return mat;
    }

    pub inline fn mul(left: Mat4, right: Mat4) Mat4 {
        @setFloatMode(.optimized);

        const r: [4]f32x4 = @bitCast(left);

        const right0 = std.simd.repeat(16, r[0]);
        const right1 = std.simd.repeat(16, r[1]);
        const right2 = std.simd.repeat(16, r[2]);
        const right3 = std.simd.repeat(16, r[3]);

        const l: f32x16 = @bitCast(right);

        var result = @shuffle(f32, l, undefined, i32x16{ 0, 0, 0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12, 12, 12, 12 }) * right0;
        result += @shuffle(f32, l, undefined, i32x16{ 1, 1, 1, 1, 5, 5, 5, 5, 9, 9, 9, 9, 13, 13, 13, 13 }) * right1;
        result += @shuffle(f32, l, undefined, i32x16{ 2, 2, 2, 2, 6, 6, 6, 6, 10, 10, 10, 10, 14, 14, 14, 14 }) * right2;
        result += @shuffle(f32, l, undefined, i32x16{ 3, 3, 3, 3, 7, 7, 7, 7, 11, 11, 11, 11, 15, 15, 15, 15 }) * right3;

        return @bitCast(result);
    }

    test mul {
        const a = Mat4{
            // zig fmt: off
            .a11 = 1, .a12 = 1, .a13 = 1, .a14 = 1, 
            .a21 = 2, .a22 = 2, .a23 = 2, .a24 = 2, 
            .a31 = 3, .a32 = 3, .a33 = 3, .a34 = 3, 
            .a41 = 4, .a42 = 4, .a43 = 4, .a44 = 4,
            // zig fmt: on
        };

        const b = Mat4{
            // zig fmt: off
            .a11 = 1, .a12 = 2, .a13 = 3, .a14 = 4, 
            .a21 = 1, .a22 = 2, .a23 = 3, .a24 = 4, 
            .a31 = 1, .a32 = 2, .a33 = 3, .a34 = 4, 
            .a41 = 1, .a42 = 2, .a43 = 3, .a44 = 4,
            // zig fmt: on
        };

        try std.testing.expectEqualSlices(
            f32,
            &[_]f32{ 4, 8, 12, 16, 8, 16, 24, 32, 12, 24, 36, 48, 16, 32, 48, 64 },
            &@as([16]f32, @bitCast(a.mul(b))),
        );
    }

    pub inline fn perspective(
        fov_y: f32,
        aspect_ratio: f32,
        znear: f32,
        zfar: f32,
    ) Mat4 {
        const fov_rad = fov_y * std.math.rad_per_deg;
        const h = 1.0 / @tan(fov_rad * 0.5);
        const w = h / aspect_ratio;

        // reverse depth
        const a = -znear / (zfar - znear);
        const b = (znear * zfar) / (zfar - znear);

        return projection(w, h, a, b);
    }

    pub inline fn projection(w: f32, h: f32, a: f32, b: f32) Mat4 {
        var out_matrix: Mat4 = std.mem.zeroes(Mat4);
        out_matrix.a11 = w;
        out_matrix.a22 = h;
        out_matrix.a33 = a;
        out_matrix.a43 = 1.0;
        out_matrix.a34 = b;

        return out_matrix;
    }

    pub inline fn view(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = center.sub(eye).norm();
        const s = up.cross(f).norm();
        const u = f.cross(s);

        var out_matrix: Mat4 = undefined;

        out_matrix.a11 = s.x;
        out_matrix.a21 = u.x;
        out_matrix.a31 = f.x;
        out_matrix.a41 = 0.0;

        out_matrix.a12 = s.y;
        out_matrix.a22 = u.y;
        out_matrix.a32 = f.y;
        out_matrix.a42 = 0.0;

        out_matrix.a13 = s.z;
        out_matrix.a23 = u.z;
        out_matrix.a33 = f.z;
        out_matrix.a43 = 0.0;

        out_matrix.a14 = -s.dot(eye);
        out_matrix.a24 = -u.dot(eye);
        out_matrix.a34 = -f.dot(eye);
        out_matrix.a44 = 1.0;

        return out_matrix;
    }

    pub inline fn transformation(pos: Vec3, rot: Quat, scale: Vec3) Mat4 {
        return scaling(scale).mul(rotation(rot)).mul(translation(pos));
    }

    pub inline fn translation(position: Vec3) Mat4 {
        var out_matrix = Mat4.identity();
        out_matrix.a14 = position.x;
        out_matrix.a24 = position.y;
        out_matrix.a34 = position.z;
        return out_matrix;
    }

    pub inline fn rotation(quat: Quat) Mat4 {
        var out_matrix: Mat4 = undefined;
        const q = quat;

        const xy2 = 2.0 * q.b * q.c;
        const xz2 = 2.0 * q.b * q.d;
        const yz2 = 2.0 * q.c * q.d;

        const xx2 = 2.0 * q.b * q.b;
        const yy2 = 2.0 * q.c * q.c;
        const zz2 = 2.0 * q.d * q.d;

        const xw2 = 2.0 * q.b * q.a;
        const yw2 = 2.0 * q.c * q.a;
        const zw2 = 2.0 * q.d * q.a;

        out_matrix.a11 = 1.0 - yy2 - zz2;
        out_matrix.a21 = xy2 + zw2;
        out_matrix.a31 = xz2 - yw2;
        out_matrix.a41 = 0.0;

        out_matrix.a12 = xy2 - zw2;
        out_matrix.a22 = 1.0 - xx2 - zz2;
        out_matrix.a32 = yz2 + xw2;
        out_matrix.a42 = 0.0;

        out_matrix.a13 = xz2 + yw2;
        out_matrix.a23 = yz2 - xw2;
        out_matrix.a33 = 1.0 - xx2 - yy2;
        out_matrix.a43 = 0.0;

        out_matrix.a14 = 0.0;
        out_matrix.a24 = 0.0;
        out_matrix.a34 = 0.0;
        out_matrix.a44 = 1.0;

        return out_matrix;
    }

    pub inline fn scaling(scale: Vec3) Mat4 {
        var out_matrix = Mat4.identity();
        out_matrix.a11 = scale.x;
        out_matrix.a22 = scale.y;
        out_matrix.a33 = scale.z;
        return out_matrix;
    }
};

pub const Mat4Soa = struct {
    // zig fmt: off
    a11: []f32, a21: []f32, a31: []f32, a41: []f32, // col 1
    a12: []f32, a22: []f32, a32: []f32, a42: []f32, // col 2
    a13: []f32, a23: []f32, a33: []f32, a43: []f32, // col 3
    a14: []f32, a24: []f32, a34: []f32, a44: []f32, // col 4
    // zig fmt: on
};

pub inline fn mulMany(left: Mat4Soa, right: Mat4Soa) void {
    std.debug.assert(left.a11.len == right.a11.len);

    @setFloatMode(.optimized);
    const block_len = std.simd.suggestVectorLength(f32) orelse unreachable;
    const Vec = @Vector(block_len, f32);
    const Arr = [block_len]f32;

    var a11: Vec = undefined;
    var a21: Vec = undefined;
    var a31: Vec = undefined;
    var a41: Vec = undefined;

    var a12: Vec = undefined;
    var a22: Vec = undefined;
    var a32: Vec = undefined;
    var a42: Vec = undefined;

    var a13: Vec = undefined;
    var a23: Vec = undefined;
    var a33: Vec = undefined;
    var a43: Vec = undefined;

    var a14: Vec = undefined;
    var a24: Vec = undefined;
    var a34: Vec = undefined;
    var a44: Vec = undefined;

    var b11: Vec = undefined;
    var b21: Vec = undefined;
    var b31: Vec = undefined;
    var b41: Vec = undefined;

    var b12: Vec = undefined;
    var b22: Vec = undefined;
    var b32: Vec = undefined;
    var b42: Vec = undefined;

    var b13: Vec = undefined;
    var b23: Vec = undefined;
    var b33: Vec = undefined;
    var b43: Vec = undefined;

    var b14: Vec = undefined;
    var b24: Vec = undefined;
    var b34: Vec = undefined;
    var b44: Vec = undefined;

    var c11: Arr = undefined;
    var c21: Arr = undefined;
    var c31: Arr = undefined;
    var c41: Arr = undefined;

    var c12: Arr = undefined;
    var c22: Arr = undefined;
    var c32: Arr = undefined;
    var c42: Arr = undefined;

    var c13: Arr = undefined;
    var c23: Arr = undefined;
    var c33: Arr = undefined;
    var c43: Arr = undefined;

    var c14: Arr = undefined;
    var c24: Arr = undefined;
    var c34: Arr = undefined;
    var c44: Arr = undefined;

    var i: usize = 0;
    while (i < left.a11.len) : (i += block_len) {
        a11 = left.a11[i..][0..block_len].*;
        a21 = left.a21[i..][0..block_len].*;
        a31 = left.a31[i..][0..block_len].*;
        a41 = left.a41[i..][0..block_len].*;

        a12 = left.a12[i..][0..block_len].*;
        a22 = left.a22[i..][0..block_len].*;
        a32 = left.a32[i..][0..block_len].*;
        a42 = left.a42[i..][0..block_len].*;

        a13 = left.a13[i..][0..block_len].*;
        a23 = left.a23[i..][0..block_len].*;
        a33 = left.a33[i..][0..block_len].*;
        a43 = left.a43[i..][0..block_len].*;

        a14 = left.a14[i..][0..block_len].*;
        a24 = left.a24[i..][0..block_len].*;
        a34 = left.a34[i..][0..block_len].*;
        a44 = left.a44[i..][0..block_len].*;

        b11 = right.a11[i..][0..block_len].*;
        b21 = right.a21[i..][0..block_len].*;
        b31 = right.a31[i..][0..block_len].*;
        b41 = right.a41[i..][0..block_len].*;

        b12 = right.a12[i..][0..block_len].*;
        b22 = right.a22[i..][0..block_len].*;
        b32 = right.a32[i..][0..block_len].*;
        b42 = right.a42[i..][0..block_len].*;

        b13 = right.a13[i..][0..block_len].*;
        b23 = right.a23[i..][0..block_len].*;
        b33 = right.a33[i..][0..block_len].*;
        b43 = right.a43[i..][0..block_len].*;

        b14 = right.a14[i..][0..block_len].*;
        b24 = right.a24[i..][0..block_len].*;
        b34 = right.a34[i..][0..block_len].*;
        b44 = right.a44[i..][0..block_len].*;

        c11 = a11 * b11 + a12 * b21 + a13 * b31 + a14 * b41;
        c21 = a21 * b11 + a22 * b21 + a23 * b31 + a24 * b41;
        c31 = a31 * b11 + a32 * b21 + a33 * b31 + a34 * b41;
        c41 = a41 * b11 + a42 * b21 + a43 * b31 + a44 * b41;

        c12 = a11 * b12 + a12 * b22 + a13 * b32 + a14 * b42;
        c22 = a21 * b12 + a22 * b22 + a23 * b32 + a24 * b42;
        c32 = a31 * b12 + a32 * b22 + a33 * b32 + a34 * b42;
        c42 = a41 * b12 + a42 * b22 + a43 * b32 + a44 * b42;

        c13 = a11 * b13 + a12 * b23 + a13 * b33 + a14 * b43;
        c23 = a21 * b13 + a22 * b23 + a23 * b33 + a24 * b43;
        c33 = a31 * b13 + a32 * b23 + a33 * b33 + a34 * b43;
        c43 = a41 * b13 + a42 * b23 + a43 * b33 + a44 * b43;

        c14 = a11 * b14 + a12 * b24 + a13 * b34 + a14 * b44;
        c24 = a21 * b14 + a22 * b24 + a23 * b34 + a24 * b44;
        c34 = a31 * b14 + a32 * b24 + a33 * b34 + a34 * b44;
        c44 = a41 * b14 + a42 * b24 + a43 * b34 + a44 * b44;

        const stride = @min(block_len, left.a11[i..].len);
        @memcpy(left.a11[i..][0..stride], c11[0..stride]);
        @memcpy(left.a21[i..][0..stride], c21[0..stride]);
        @memcpy(left.a31[i..][0..stride], c31[0..stride]);
        @memcpy(left.a41[i..][0..stride], c41[0..stride]);

        @memcpy(left.a12[i..][0..stride], c12[0..stride]);
        @memcpy(left.a22[i..][0..stride], c22[0..stride]);
        @memcpy(left.a32[i..][0..stride], c32[0..stride]);
        @memcpy(left.a42[i..][0..stride], c42[0..stride]);

        @memcpy(left.a13[i..][0..stride], c13[0..stride]);
        @memcpy(left.a23[i..][0..stride], c23[0..stride]);
        @memcpy(left.a33[i..][0..stride], c33[0..stride]);
        @memcpy(left.a43[i..][0..stride], c43[0..stride]);

        @memcpy(left.a14[i..][0..stride], c14[0..stride]);
        @memcpy(left.a24[i..][0..stride], c24[0..stride]);
        @memcpy(left.a34[i..][0..stride], c34[0..stride]);
        @memcpy(left.a44[i..][0..stride], c44[0..stride]);
    }
}

test mulMany {
    var a11 = [1]f32{1};
    var a12 = [1]f32{1};
    var a13 = [1]f32{1};
    var a14 = [1]f32{1};
    var a21 = [1]f32{2};
    var a22 = [1]f32{2};
    var a23 = [1]f32{2};
    var a24 = [1]f32{2};
    var a31 = [1]f32{3};
    var a32 = [1]f32{3};
    var a33 = [1]f32{3};
    var a34 = [1]f32{3};
    var a41 = [1]f32{4};
    var a42 = [1]f32{4};
    var a43 = [1]f32{4};
    var a44 = [1]f32{4};
    const a = Mat4Soa{
        .a11 = &a11,
        .a12 = &a12,
        .a13 = &a13,
        .a14 = &a14,
        .a21 = &a21,
        .a22 = &a22,
        .a23 = &a23,
        .a24 = &a24,
        .a31 = &a31,
        .a32 = &a32,
        .a33 = &a33,
        .a34 = &a34,
        .a41 = &a41,
        .a42 = &a42,
        .a43 = &a43,
        .a44 = &a44,
    };

    const b = Mat4Soa{
        .a11 = @constCast(&[1]f32{1}),
        .a12 = @constCast(&[1]f32{2}),
        .a13 = @constCast(&[1]f32{3}),
        .a14 = @constCast(&[1]f32{4}),
        .a21 = @constCast(&[1]f32{1}),
        .a22 = @constCast(&[1]f32{2}),
        .a23 = @constCast(&[1]f32{3}),
        .a24 = @constCast(&[1]f32{4}),
        .a31 = @constCast(&[1]f32{1}),
        .a32 = @constCast(&[1]f32{2}),
        .a33 = @constCast(&[1]f32{3}),
        .a34 = @constCast(&[1]f32{4}),
        .a41 = @constCast(&[1]f32{1}),
        .a42 = @constCast(&[1]f32{2}),
        .a43 = @constCast(&[1]f32{3}),
        .a44 = @constCast(&[1]f32{4}),
    };

    mulMany(a, b);

    try std.testing.expectEqual(4, a.a11[0]);
    try std.testing.expectEqual(8, a.a21[0]);
    try std.testing.expectEqual(12, a.a31[0]);
    try std.testing.expectEqual(16, a.a41[0]);

    try std.testing.expectEqual(8, a.a12[0]);
    try std.testing.expectEqual(16, a.a22[0]);
    try std.testing.expectEqual(24, a.a32[0]);
    try std.testing.expectEqual(32, a.a42[0]);

    try std.testing.expectEqual(12, a.a13[0]);
    try std.testing.expectEqual(24, a.a23[0]);
    try std.testing.expectEqual(36, a.a33[0]);
    try std.testing.expectEqual(48, a.a43[0]);

    try std.testing.expectEqual(16, a.a14[0]);
    try std.testing.expectEqual(32, a.a24[0]);
    try std.testing.expectEqual(48, a.a34[0]);
    try std.testing.expectEqual(64, a.a44[0]);
}

test {
    std.testing.refAllDecls(@This());
}
