const std = @import("std");
pub usingnamespace std.math;

pub usingnamespace @import("vec2.zig");
pub usingnamespace @import("vec3.zig");
pub usingnamespace @import("vec4.zig");
pub usingnamespace @import("quat.zig");
pub usingnamespace @import("mat2.zig");
pub usingnamespace @import("mat3.zig");
pub usingnamespace @import("mat4.zig");

pub inline fn color4(r: f32, g: f32, b: f32, a: f32) Color4 {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

pub const Color4 = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Color3 = extern struct {
    r: f32,
    g: f32,
    b: f32,
};

pub const TexCoords = extern struct {
    u: f32,
    v: f32,
};

pub const Float2 = extern union {
    elem: [2]f32,
    vec: @Vector(2, f32),
    xy: @This().Vec2,
    uv: TexCoords,

    pub inline fn x(self: Float2) f32 {
        return self.xy.x;
    }
    pub inline fn y(self: Float2) f32 {
        return self.xy.y;
    }
    pub inline fn setX(self: *Float2, value: f32) void {
        self.xy.x = value;
    }
    pub inline fn setY(self: *Float2, value: f32) void {
        self.xy.y = value;
    }

    pub inline fn u(self: Float2) f32 {
        return self.uv.u;
    }
    pub inline fn v(self: Float2) f32 {
        return self.uv.v;
    }
    pub inline fn setU(self: *Float2, value: f32) void {
        self.uv.u = value;
    }
    pub inline fn setV(self: *Float2, value: f32) void {
        self.uv.v = value;
    }
};

pub const Float3 = extern union {
    elem: [3]f32,
    vec: @Vector(3, f32),
    xyz: @This().Vec3,
    rgb: Color3,

    pub inline fn x(self: Float3) f32 {
        return self.xyz.x;
    }
    pub inline fn y(self: Float3) f32 {
        return self.xyz.y;
    }
    pub inline fn z(self: Float3) f32 {
        return self.xyz.z;
    }

    pub inline fn setX(self: Float3, value: f32) f32 {
        self.xyz.x = value;
    }
    pub inline fn setY(self: Float3, value: f32) f32 {
        self.xyz.y = value;
    }
    pub inline fn setZ(self: Float3, value: f32) f32 {
        self.xyz.z = value;
    }

    pub inline fn r(self: Float3) f32 {
        return self.rgb.r;
    }
    pub inline fn g(self: Float3) f32 {
        return self.rgb.g;
    }
    pub inline fn b(self: Float3) f32 {
        return self.rgb.b;
    }

    pub inline fn setR(self: Float3, value: f32) f32 {
        self.rgb.r = value;
    }
    pub inline fn setG(self: Float3, value: f32) f32 {
        self.rgb.g = value;
    }
    pub inline fn setB(self: Float3, value: f32) f32 {
        self.rgb.b = value;
    }
};

pub const Float4 = extern union {
    elem: [4]f32,
    vec: @Vector(4, f32),
    xyzw: @This().Vec4,
    rgba: Color4,
    xyz: @This().Vec3,
    rgb: Color3,
    xy: @This().Vec2,
    uv: TexCoords,

    pub inline fn x(self: Float4) f32 {
        return self.xyzw.x;
    }
    pub inline fn y(self: Float4) f32 {
        return self.xyzw.y;
    }
    pub inline fn z(self: Float4) f32 {
        return self.xyzw.z;
    }
    pub inline fn w(self: Float4) f32 {
        return self.xyzw.w;
    }

    pub inline fn setX(self: Float3, value: f32) f32 {
        self.xyzw.x = value;
    }
    pub inline fn setY(self: Float3, value: f32) f32 {
        self.xyzw.y = value;
    }
    pub inline fn setZ(self: Float3, value: f32) f32 {
        self.xyzw.z = value;
    }
    pub inline fn setW(self: Float3, value: f32) f32 {
        self.xyzw.w = value;
    }

    pub inline fn r(self: Float4) f32 {
        return self.rgba.r;
    }
    pub inline fn g(self: Float4) f32 {
        return self.rgba.g;
    }
    pub inline fn b(self: Float4) f32 {
        return self.rgba.b;
    }
    pub inline fn a(self: Float4) f32 {
        return self.rgba.a;
    }

    pub inline fn setR(self: Float3, value: f32) f32 {
        self.rgba.r = value;
    }
    pub inline fn setG(self: Float3, value: f32) f32 {
        self.rgba.g = value;
    }
    pub inline fn setB(self: Float3, value: f32) f32 {
        self.rgba.b = value;
    }
    pub inline fn setA(self: Float3, value: f32) f32 {
        self.rgba.a = value;
    }
};
