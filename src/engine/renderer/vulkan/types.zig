const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const math = @import("../../math/math.zig");

pub const Image = extern struct {
    image: vk.Image,
    image_view: vk.ImageView,
    memory: c.VkDeviceMemory,
    image_extent: c.VkExtent3D,
    image_format: c.VkFormat,
};

pub const Buffer = extern struct {
    buffer: vk.Buffer,
    memory: c.VkDeviceMemory,
    size: usize,
};

pub const Vertex = extern struct {
    position: math.Vec3,
    uv_x: f32 = 0,
    normal: math.Vec3 = std.mem.zeroes(math.Vec3),
    uv_y: f32 = 0,
    color: math.Color4 = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
};

pub const Mesh = struct {
    index_buffer: Buffer,
    vertex_buffer: Buffer,
    vb_addr: c.VkDeviceAddress,
    name: ?[]const u8,
};

pub const DrawPushConstants = extern struct {
    world_matrix: math.Mat4,
    vertex_buffer: c.VkDeviceAddress,
};
