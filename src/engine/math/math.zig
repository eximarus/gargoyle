const std = @import("std");
pub usingnamespace std.math;

pub const vec4 = Vec4.new;
pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub inline fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return Vec4{ .x = x, .y = y, .z = z, .w = w };
    }
};

pub const vec3 = Vec3.new;
pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }
};

pub const vec2 = Vec2.new;
pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub inline fn new(x: f32, y: f32) Vec2 {
        return Vec2{ .x = x, .y = y };
    }

    pub inline fn zero() Vec2 {
        return new(0.0, 0.0);
    }

    pub inline fn one() Vec2 {
        return new(1.0, 1.0);
    }

    pub inline fn up() Vec2 {
        return new(0.0, 1.0);
    }

    pub inline fn down() Vec2 {
        return new(0.0, -1.0);
    }

    pub inline fn left() Vec2 {
        return new(-1.0, 0.0);
    }

    pub inline fn right() Vec2 {
        return new(1.0, 0.0);
    }

    pub inline fn add(self: Vec2, other: Vec2) Vec2 {
        return new(self.x + other.x, self.y + other.y);
    }

    pub inline fn sub(self: Vec2, other: Vec2) Vec2 {
        return new(self.x - other.x, self.y - other.y);
    }

    pub inline fn mul(self: Vec2, other: Vec2) Vec2 {
        return new(self.x * other.x, self.y * other.y);
    }

    pub inline fn div(self: Vec2, other: Vec2) Vec2 {
        return new(self.x / other.x, self.y / other.y);
    }

    pub inline fn magSq(self: Vec2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub inline fn mag(self: Vec2) f32 {
        return std.math.sqrt(self.magSq());
    }

    pub inline fn normalize(self: *Vec2) void {
        const m = self.mag();
        self.x /= m;
        self.y /= m;
    }

    pub inline fn normalized(self: Vec2) Vec2 {
        var v = self;
        v.normalize();
        return v;
    }

    pub inline fn approxEq(self: Vec2, other: Vec2, tolerance: f32) bool {
        if (!std.math.approxEqAbs(f32, self.x, other.x, tolerance)) {
            return false;
        }
        if (!std.math.approxEqAbs(f32, self.y, other.y, tolerance)) {
            return false;
        }
        return true;
    }

    pub inline fn dist(self: Vec2, other: Vec2) f32 {
        return self.sub(other).mag();
    }
};

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

pub const Quat = Vec4;

pub const Float2 = extern union {
    elem: [2]f32,
    vec: @Vector(2, f32),
    xy: Vec2,
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
    xyz: Vec3,
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
    xyzw: Vec4,
    rgba: Color4,
    xyz: Vec3,
    rgb: Color3,
    xy: Vec2,
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
