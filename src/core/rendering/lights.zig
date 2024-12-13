const std = @import("std");
const math = @import("../root.zig").math;

pub const DirectionalLight = struct {
    direction: math.Vec3,
    color: math.Color3,
    intensity: f32,
};

pub const PointLight = struct {
    position: math.Vec3,
    color: math.Color3,
    intensity: f32,
};

pub const SpotLight = struct {
    position: math.Vec3,
    direction: math.Vec3,
    color: math.Color3,
    intensity: f32,

    inner_cone_angle: f32,
    outer_cone_angle: f32,
};
