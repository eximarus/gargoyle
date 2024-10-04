const std = @import("std");
const c = @import("c");
const math = @import("../../root.zig").math;
const vk = @import("vulkan.zig");
const resources = @import("resources.zig");

pub const Vertex = extern struct {
    position: math.Vec3 = std.mem.zeroes(math.Vec3),
    normal: math.Vec3 = std.mem.zeroes(math.Vec3),
    color: math.Color4 = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    uv: math.Vec2 = std.mem.zeroes(math.Vec2),
};

pub const Mesh = struct {
    index_buffer: resources.Buffer,
    vertex_buffer: resources.Buffer,
    vb_addr: c.VkDeviceAddress,
    name: ?[]const u8,
};

pub const PushConstants = extern struct {
    world_matrix: math.Mat4,
    vertex_buffer: c.VkDeviceAddress,
};
