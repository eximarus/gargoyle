const std = @import("std");
const c = @import("c");
const math = @import("../../root.zig").math;
const vk = @import("vulkan.zig");
const resources = @import("resources.zig");

pub const Vertex = extern struct {
    position: math.Vec3 = std.mem.zeroes(math.Vec3),
    normal: math.Vec3 = std.mem.zeroes(math.Vec3),
    uv: math.Vec2 = std.mem.zeroes(math.Vec2),
    color: math.Color4 = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    tangent: math.Vec4 = math.Vec4.identity(),
};

pub const Mesh = struct {
    index_buffer: resources.Buffer,
    vertex_buffer: resources.Buffer,
    vb_addr: c.VkDeviceAddress,
    name: ?[]const u8,
    bounds: struct {
        min: math.Vec3,
        max: math.Vec3,
        center: math.Vec3,
    },
};

pub const PushConstants = extern struct {
    world_matrix: math.Mat4,
    vertex_buffer: c.VkDeviceAddress,
};
