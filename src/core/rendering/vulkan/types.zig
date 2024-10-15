const c = @import("c");
const math = @import("../../root.zig").math;

pub const Vertex = extern struct {
    position: math.Vec3 = math.Vec3.zero(),
    normal: math.Vec3 = math.Vec3.zero(),
    uv: math.Vec2 = math.Vec2.zero(),
    color: math.Color4 = math.color4(0, 0, 0, 1),
    tangent: math.Vec4 = math.Vec4.identity(),
};

pub const PushConstants = extern struct {
    world_matrix: math.Mat4,
    vertex_buffer: c.VkDeviceAddress,
};
