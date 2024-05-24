const std = @import("std");
const math = @import("../../math/math.zig");
const c = @import("../../c.zig");
const common = @import("common.zig");
const types = @import("types.zig");
const VulkanRenderer = @import("VulkanRenderer.zig");

pub const GeoSurface = struct {
    start_index: u32,
    count: u32,
};

pub const MeshAssets = struct {
    name: common.CString,
    surfaces: []GeoSurface,
    mesh: types.Mesh,
};

const Attributes = struct {
    position: ?*c.cgltf_accessor = null,
    normal: ?*c.cgltf_accessor = null,
    tangent: ?*c.cgltf_accessor = null,
    texcoord: ?*c.cgltf_accessor = null,
    color: ?*c.cgltf_accessor = null,
    joints: ?*c.cgltf_accessor = null,
    weights: ?*c.cgltf_accessor = null,
    custom: ?*c.cgltf_accessor = null,
};

pub const GltfError = error{
    DataTooShort,
    UnknownFormat,
    InvalidJson,
    InvalidGltf,
    InvalidOptions,
    FileNotFound,
    IOError,
    OutOfMemory,
    LegacyGltf,

    UnknownResult,
};

pub fn gltfError(result: c.cgltf_result) GltfError!void {
    return switch (result) {
        c.cgltf_result_success => {},
        c.cgltf_result_data_too_short => GltfError.DataTooShort,
        c.cgltf_result_unknown_format => GltfError.UnknownFormat,
        c.cgltf_result_invalid_json => GltfError.InvalidJson,
        c.cgltf_result_invalid_gltf => GltfError.InvalidGltf,
        c.cgltf_result_invalid_options => GltfError.InvalidOptions,
        c.cgltf_result_file_not_found => GltfError.FileNotFound,
        c.cgltf_result_io_error => GltfError.IOError,
        c.cgltf_result_out_of_memory => GltfError.OutOfMemory,
        c.cgltf_result_legacy_gltf => GltfError.LegacyGltf,
        else => GltfError.UnknownResult,
    };
}

pub fn loadGltfMeshes(renderer: *VulkanRenderer, path: common.CString) ![]MeshAssets {
    const options = c.cgltf_options{};

    var data: *c.cgltf_data = undefined;
    try gltfError(c.cgltf_parse_file(&options, path, @ptrCast(&data)));
    defer c.cgltf_free(data);

    try gltfError(c.cgltf_load_buffers(&options, data, path));
    try gltfError(c.cgltf_validate(data));

    var indices = std.ArrayList(u32).init(renderer.allocator);
    defer indices.deinit();
    var vertices = std.ArrayList(types.Vertex).init(renderer.allocator);
    defer vertices.deinit();

    const meshes = try renderer.allocator.alloc(MeshAssets, data.meshes_count);
    for (data.meshes[0..data.meshes_count], meshes) |gltf_mesh, *mesh_assets| {
        mesh_assets.name = gltf_mesh.name;

        indices.clearRetainingCapacity();
        vertices.clearRetainingCapacity();

        mesh_assets.surfaces = try renderer.allocator.alloc(GeoSurface, gltf_mesh.primitives_count);
        for (
            gltf_mesh.primitives[0..gltf_mesh.primitives_count],
            mesh_assets.surfaces,
        ) |p, *surface| {
            surface.start_index = @intCast(indices.items.len);
            surface.count = @intCast(p.indices.*.count);

            try indices.ensureUnusedCapacity(surface.count);
            _ = c.cgltf_accessor_unpack_indices(
                p.indices,
                @ptrCast(indices.unusedCapacitySlice()[0..surface.count]),
                @sizeOf(u32),
                p.indices.*.count,
            );
            indices.items.len += surface.count;

            const attributes = createAttributeTable(&p);
            const posAccessor = attributes.position orelse break;
            try vertices.ensureUnusedCapacity(posAccessor.count);

            for (vertices.unusedCapacitySlice()[0..posAccessor.count], 0..) |*vertex, index| {
                _ = c.cgltf_accessor_read_float(posAccessor, index, @ptrCast(&vertex.position), 3);

                if (attributes.normal) |normal| {
                    _ = c.cgltf_accessor_read_float(normal, index, @ptrCast(&vertex.normal), 3);
                } else {
                    vertex.normal = math.vec3(1, 0, 0);
                }

                if (attributes.texcoord) |texcoord| {
                    var uvs: math.Vec2 = undefined;
                    _ = c.cgltf_accessor_read_float(texcoord, index, @ptrCast(&uvs), 2);
                    vertex.uv_x = uvs.x;
                    vertex.uv_y = uvs.y;
                } else {
                    vertex.uv_x = 0;
                    vertex.uv_y = 0;
                }

                if (attributes.color) |color| {
                    _ = c.cgltf_accessor_read_float(color, index, @ptrCast(&vertex.color), 4);
                } else {
                    vertex.color = math.color4(1.0, 1.0, 1.0, 1.0);
                }
            }
            vertices.items.len += posAccessor.count;
        }
        // display the vertex normals
        const override_colors = true;
        if (override_colors) {
            for (vertices.items) |*vtx| {
                vtx.color = math.color4(vtx.normal.x, vtx.normal.y, vtx.normal.z, 1.0);
            }
        }
        mesh_assets.mesh = try renderer.uploadMesh(indices.items, vertices.items);
    }
    return meshes;
}

fn createAttributeTable(p: *const c.cgltf_primitive) Attributes {
    var attributes = Attributes{};
    for (0..p.attributes_count) |attr_idx| {
        const attr = p.attributes[attr_idx];
        switch (attr.type) {
            c.cgltf_attribute_type_position => {
                attributes.position = attr.data;
            },
            c.cgltf_attribute_type_normal => {
                attributes.normal = attr.data;
            },
            c.cgltf_attribute_type_tangent => {
                attributes.tangent = attr.data;
            },
            c.cgltf_attribute_type_texcoord => {
                attributes.texcoord = attr.data;
            },
            c.cgltf_attribute_type_color => {
                attributes.color = attr.data;
            },
            c.cgltf_attribute_type_joints => {
                attributes.joints = attr.data;
            },
            c.cgltf_attribute_type_weights => {
                attributes.weights = attr.data;
            },
            c.cgltf_attribute_type_custom => {
                attributes.custom = attr.data;
            },
            else => {},
        }
    }
    return attributes;
}
