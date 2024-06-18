const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const vma = @import("vma.zig");
const math = @import("../../math/math.zig");

pub const Image = extern struct {
    image: vk.Image,
    image_view: vk.ImageView,
    allocation: vma.Allocation,
    image_extent: c.VkExtent3D,
    image_format: c.VkFormat,
};

pub const Buffer = extern struct {
    buffer: vk.Buffer,
    allocation: vma.Allocation,
    info: c.VmaAllocationInfo,
};

pub const Vertex = extern struct {
    position: math.Vec3,
    uv_x: f32 = 0,
    normal: math.Vec3 = std.mem.zeroes(math.Vec3),
    uv_y: f32 = 0,
    color: math.Color4,
};

pub const Mesh = extern struct {
    index_buffer: Buffer,
    vertex_buffer: Buffer,
    vb_addr: c.VkDeviceAddress,
};

pub const DrawPushConstants = extern struct {
    world_matrix: math.Mat4,
    vertex_buffer: c.VkDeviceAddress,
};
