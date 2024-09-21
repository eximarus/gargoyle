const std = @import("std");
const math = @import("../../math/math.zig");
const gltf = @import("../../resources/gltf.zig");
const types = @import("types.zig");

const VulkanRenderer = @import("VulkanRenderer.zig");

pub fn loadGltfMeshes(renderer: *VulkanRenderer, path: []const u8) ![]types.Mesh {
    const glb = try gltf.load(path, renderer.arena);
    const accessors = glb.gltf.accessors orelse return error.InvalidGltf;
    const gltf_meshes = glb.gltf.meshes orelse return error.InvalidGltf;
    const buffer_views = glb.gltf.bufferViews orelse return error.InvalidGltf;
    const bin = glb.bin orelse return error.InvalidGltf;

    var indices = std.ArrayList(u32).init(renderer.arena);
    var vertices = std.ArrayList(types.Vertex).init(renderer.arena);

    const meshes = try renderer.gpa.alloc(types.Mesh, gltf_meshes.len);
    for (gltf_meshes, meshes) |gltf_mesh, *mesh| {
        indices.clearRetainingCapacity();
        vertices.clearRetainingCapacity();

        for (gltf_mesh.primitives) |p| {
            const idx_acc = accessors[p.indices orelse return error.InvalidGltf];
            const idx_count = idx_acc.count;
            const idx_buffer_view_idx = idx_acc.bufferView orelse return error.InvalidGltf;
            const idx_buffer_view = buffer_views[idx_buffer_view_idx];
            const idx_data_offset = idx_buffer_view.byteOffset + idx_acc.byteOffset;
            const idx_data_len = idx_buffer_view.byteLength;
            const idx_data = bin[idx_data_offset..(idx_data_offset + idx_data_len)];

            try indices.ensureUnusedCapacity(idx_count);
            const idx_slice = indices.unusedCapacitySlice()[0..idx_count];
            if (idx_acc.componentType == .unsigned_int) {
                @memcpy(std.mem.asBytes(idx_slice), idx_data);
            } else {
                const component_size = idx_acc.componentType.size();
                var k: usize = 0;
                for (0..idx_count) |j| {
                    idx_slice[j] = switch (idx_acc.componentType) {
                        .unsigned_byte => @intCast(@as(*const u8, @ptrCast(@alignCast(&idx_data[k]))).*),
                        .unsigned_short => @intCast(@as(*const u16, @ptrCast(@alignCast(&idx_data[k]))).*),
                        .short, .byte, .float => return error.InvalidGltf,
                        .unsigned_int => unreachable,
                    };
                    k += component_size;
                }
            }
            indices.items.len += idx_count;

            const pos_acc = accessors[p.findAttribute("POSITION") orelse return error.InvalidGltf];
            const normal_acc = if (p.findAttribute("NORMAL")) |attr| accessors[attr] else null;
            const texcoord_acc = if (p.findAttribute("TEXCOORD_0")) |attr| accessors[attr] else null;
            const color_acc = if (p.findAttribute("COLOR_0")) |attr| accessors[attr] else null;

            const vtx_count = pos_acc.count;
            try vertices.ensureUnusedCapacity(vtx_count);
            const vtx_slice = vertices.unusedCapacitySlice()[0..vtx_count];

            for (vtx_slice, 0..) |*vertex, i| {
                const stride = @sizeOf(@TypeOf(vertex.position));
                const buffer_view_idx = pos_acc.bufferView orelse return error.InvalidGltf;
                const buffer_view = buffer_views[buffer_view_idx];
                const vtx_data_offset = buffer_view.byteOffset + pos_acc.byteOffset + stride * i;
                const vtx_data_len = stride;
                const vtx_data = bin[vtx_data_offset..(vtx_data_offset + vtx_data_len)];
                @memcpy(std.mem.asBytes(&vertex.position), vtx_data);

                if (normal_acc) |acc| {
                    const normals = gltf.readVertex(bin, buffer_views, acc, i, @sizeOf(@TypeOf(vertex.normal)));
                    @memcpy(std.mem.asBytes(&vertex.normal), normals);
                } else {
                    vertex.normal = math.vec3(1, 0, 0);
                }

                if (texcoord_acc) |acc| {
                    var uvs: math.Vec2 = undefined;
                    const texcoords = gltf.readVertex(bin, buffer_views, acc, i, @sizeOf(@TypeOf(uvs)));
                    @memcpy(std.mem.asBytes(&uvs), texcoords);
                    vertex.uv_x = uvs.x;
                    vertex.uv_y = uvs.y;
                } else {
                    vertex.uv_x = 0;
                    vertex.uv_y = 0;
                }

                if (color_acc) |acc| {
                    const colors = gltf.readVertex(bin, buffer_views, acc, i, @sizeOf(@TypeOf(vertex.color)));
                    @memcpy(std.mem.asBytes(&vertex.color), colors);
                } else {
                    vertex.color = math.color4(1.0, 1.0, 1.0, 1.0);
                }

                // flip z for LH
                vertex.normal.z = (-vertex.normal.z + 1.0) / 2.0;
                vertex.position.z = (-vertex.position.z + 1.0) / 2.0;
            }
            vertices.items.len += vtx_count;
        }

        // flip indices for LH
        var i: usize = 0;
        while (i < indices.items.len) : (i += 3) {
            std.mem.swap(u32, &indices.items[i], &indices.items[i + 2]);
        }

        // display the vertex normals... for now
        for (vertices.items) |*vtx| {
            vtx.color = math.color4(vtx.normal.x, vtx.normal.y, vtx.normal.z, 1.0);
        }

        mesh.* = try renderer.uploadMesh(indices.items, vertices.items);
    }
    return meshes;
}
