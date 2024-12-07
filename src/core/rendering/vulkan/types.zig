const c = @import("c");
const math = @import("../../root.zig").math;

pub const Vertex = extern struct {
    position: math.Vec3 = math.Vec3.zero(),
    uv_x: f32,
    normal: math.Vec3 = math.Vec3.zero(),
    uv_y: f32,
    color: math.Color4 = math.color4(0, 0, 0, 1),
    tangent: math.Vec3 = math.Vec3.zero(),
};

pub const PushConstants = extern struct {
    world_matrix: math.Mat4,
    vertex_buffer: c.VkDeviceAddress,
};
