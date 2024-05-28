const std = @import("std");
pub usingnamespace std.math;

pub usingnamespace @import("vec2.zig");
pub usingnamespace @import("vec3.zig");
pub usingnamespace @import("vec4.zig");
pub usingnamespace @import("quat.zig");
pub usingnamespace @import("mat2.zig");
pub usingnamespace @import("mat3.zig");
pub usingnamespace @import("mat4.zig");

pub inline fn degToRad(deg: f32) f32 {
    return deg * std.math.rad_per_deg;
}

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
