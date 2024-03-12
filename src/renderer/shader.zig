const std = @import("std");
const wgpu = @import("mach-gpu");
const math = @import("../math.zig");

const ShaderError = error{ CompileNotSuccess, LinkNotSuccess };

pub const Color = extern struct {
    r: f32 align(1),
    g: f32 align(1),
    b: f32 align(1),
    a: f32 align(1),
};

pub const DefaultShader = struct {
    pub const uNameViewProj = "uViewProj";

    pub const Vertex = extern struct {
        pos: math.V3F32 align(1),
        color: Color align(1),
        tex_coord: math.V2F32 align(1),
    };

    test "Vertex size" {
        // ensure no padding
        try std.testing.expectEqual(36, @sizeOf(Vertex));
        try std.testing.expectEqual(36 * 8, @bitSizeOf(Vertex));
    }

    pub fn getBufferData(vertices: []const Vertex) struct {
        size: usize,
        data: [*]const u8,
    } {
        return .{
            .size = @sizeOf(Vertex) * vertices.len,
            .data = @as([*]const u8, @ptrCast(vertices.ptr)),
        };
    }

    pub fn createVertexBuffer(
        device: *wgpu.Device,
        vertices: []const DefaultShader.Vertex,
    ) *wgpu.Buffer {
        const vertex_buffer = device.createBuffer(&.{
            .label = "Vertex Buffer",
            .usage = .{
                .copy_dst = true,
                .vertex = true,
            },
            .size = vertices.len * @sizeOf(std.meta.Elem(@TypeOf(vertices))),
        });
        device.getQueue().writeBuffer(vertex_buffer, 0, vertices);
        return vertex_buffer;
    }

    pub fn createIndexBuffer(
        device: *wgpu.Device,
        indices: []const u32,
    ) *wgpu.Buffer {
        const index_buffer = device.createBuffer(&.{
            .label = "Index Buffer",
            .usage = .{
                .copy_dst = true,
                .index = true,
            },
            .size = indices.len * @sizeOf(std.meta.Elem(@TypeOf(indices))),
        });
        device.getQueue().writeBuffer(index_buffer, 0, indices);
        return index_buffer;
    }

    pub fn createUniformBuffer(
        device: *wgpu.Device,
        view_proj_mat: *const math.Mat,
    ) *wgpu.Buffer {
        const uniform_buffer = device.createBuffer(&.{
            .label = "Uniform Buffer",
            .usage = .{
                .copy_dst = true,
                .uniform = true,
            },
            .size = @sizeOf(math.Mat),
        });
        device.getQueue().writeBuffer(uniform_buffer, 0, view_proj_mat);
        return uniform_buffer;
    }

    fn getVertexFormat(comptime T: type) wgpu.VertexFormat {
        return switch (@typeInfo(T)) {
            .Int => |int_info| switch (int_info.bits) {
                32 => if (int_info.signedness == .unsigned) .uint32 else .sint32,
                else => unreachable,
            },
            .Float => |float_info| switch (float_info.bits) {
                32 => .float32,
                else => unreachable,
            },
            .Array, .Vector => |arr_info| switch (arr_info.child) {
                .Float => switch (arr_info.child.bits) {
                    32 => switch (arr_info.len) {
                        2 => .float16x2,
                        4 => .float16x4,
                        else => unreachable,
                    },
                    32 => switch (arr_info.len) {
                        2 => .float32x2,
                        3 => .float32x3,
                        4 => .float32x4,
                        else => unreachable,
                    },
                },
                .Int => |info| switch (info.signedness) {
                    .signed => switch (info.bits) {
                        8 => switch (arr_info.len) {
                            2 => .sint8x2,
                            4 => .sint8x4,
                            else => unreachable,
                        },
                        16 => switch (arr_info.len) {
                            2 => .sint16x2,
                            4 => .sint16x4,
                            else => unreachable,
                        },
                        32 => switch (arr_info.len) {
                            2 => .sint32x2,
                            3 => .sint32x3,
                            4 => .sint32x4,
                            else => unreachable,
                        },
                    },
                    .unsigned => switch (info.bits) {
                        8 => switch (arr_info.len) {
                            2 => .uint8x2,
                            4 => .uint8x4,
                            else => unreachable,
                        },
                        16 => switch (arr_info.len) {
                            2 => .uint16x2,
                            4 => .uint16x4,
                            else => unreachable,
                        },
                        32 => switch (arr_info.len) {
                            2 => .uint32x2,
                            3 => .uint32x3,
                            4 => .uint32x4,
                            else => unreachable,
                        },
                    },
                    else => unreachable,
                },
                else => unreachable,
            },
            .Struct => |s_info| switch (@typeInfo(s_info.fields[0].type)) {
                .Float => switch (s_info.fields.len) {
                    2 => .float32x2,
                    3 => .float32x3,
                    4 => .float32x4,
                    else => unreachable,
                },
                else => unreachable,
            },
            else => unreachable,
        };
    }

    pub inline fn makeVertexBufferLayout() wgpu.VertexBufferLayout {
        const fields = std.meta.fields(Vertex);
        return wgpu.VertexBufferLayout{
            .attribute_count = fields.len,
            .array_stride = @sizeOf(Vertex),
            .attributes = &makeVertexAttributes(),
        };
    }

    inline fn makeVertexAttributes() [std.meta.fields(Vertex).len]wgpu.VertexAttribute {
        const fields = std.meta.fields(Vertex);
        var attributes: [fields.len]wgpu.VertexAttribute = undefined;
        comptime var offset = 0;
        inline for (0.., fields) |i, elem| {
            attributes[i] = wgpu.VertexAttribute{
                .shader_location = i,
                .format = getVertexFormat(elem.type),
                .offset = offset,
            };
            offset += @sizeOf(elem.type);
        }
        return attributes;
    }
};
