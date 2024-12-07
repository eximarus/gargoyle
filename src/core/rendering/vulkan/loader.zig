const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const vkdraw = @import("vkdraw.zig");

const core = @import("../../root.zig");
const math = core.math;
const gltf = core.loading.gltf;
const png = core.loading.png;

const resources = @import("resources.zig");
const types = @import("types.zig");

const ImmediateCommand = @import("ImmediateCommand.zig");

pub fn loadGltfMeshes(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    glb: gltf.Glb,
    physical_device_mem_props: c.VkPhysicalDeviceMemoryProperties,
    imm_cmd: ImmediateCommand,
) ![]resources.Mesh {
    const accessors = glb.gltf.accessors orelse return error.InvalidGltf;
    const gltf_meshes = glb.gltf.meshes orelse return error.InvalidGltf;
    const buffer_views = glb.gltf.bufferViews orelse return error.InvalidGltf;
    const bin = glb.bin orelse return error.InvalidGltf;

    var indices = std.ArrayList(u32).init(arena);
    var vertices = std.ArrayList(types.Vertex).init(arena);

    const meshes = try gpa.alloc(resources.Mesh, gltf_meshes.len);
    for (gltf_meshes, meshes) |gltf_mesh, *mesh| {
        indices.clearRetainingCapacity();
        vertices.clearRetainingCapacity();

        var min = math.Vec3.splat(math.inf(f32));
        var max = math.Vec3.splat(-math.inf(f32));
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
                    // TODO switch outside of loop
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
            const tangent_acc = if (p.findAttribute("TANGENT")) |attr| accessors[attr] else null;
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

                const pos = vertex.position;
                min = math.Vec3.min(pos, min);
                max = math.Vec3.max(pos, max);

                if (normal_acc) |acc| {
                    const normals = gltf.readVertexAttr(bin, buffer_views, acc, i, @sizeOf(@TypeOf(vertex.normal)));
                    @memcpy(std.mem.asBytes(&vertex.normal), normals);
                } else {
                    vertex.normal = math.vec3(1, 0, 0);
                }

                if (tangent_acc) |acc| {
                    const tangent = gltf.readVertexAttr(bin, buffer_views, acc, i, @sizeOf(@TypeOf(vertex.tangent)));
                    @memcpy(std.mem.asBytes(&vertex.tangent), tangent);
                } else {
                    vertex.tangent = math.Vec3.zero();
                }

                if (texcoord_acc) |acc| {
                    var uv: math.Vec2 = undefined;
                    const texcoords = gltf.readVertexAttr(bin, buffer_views, acc, i, @sizeOf(@TypeOf(uv)));
                    @memcpy(std.mem.asBytes(&uv), texcoords);
                    vertex.uv_x = uv.x;
                    vertex.uv_y = uv.y;
                } else {
                    vertex.uv_x = 0;
                    vertex.uv_y = 0;
                }

                if (color_acc) |acc| {
                    const colors = gltf.readVertexAttr(bin, buffer_views, acc, i, @sizeOf(@TypeOf(vertex.color)));
                    @memcpy(std.mem.asBytes(&vertex.color), colors);
                } else {
                    vertex.color = math.color4(1.0, 1.0, 1.0, 1.0);
                }

                // flip z for LH
                vertex.position.z = -vertex.position.z;
                vertex.normal.z = -vertex.normal.z;

                // vertex.normal.z = (-vertex.normal.z + 1.0) / 2.0;
                // vertex.position.z = (-vertex.position.z + 1.0) / 2.0;
            }
            vertices.items.len += vtx_count;
        }

        // flip indices for LH
        var i: usize = 0;
        while (i < indices.items.len) : (i += 3) {
            std.mem.swap(u32, &indices.items[i + 1], &indices.items[i + 2]);
        }

        mesh.* = try uploadMesh(
            indices.items,
            vertices.items,
            resources.Mesh.Bounds{
                .min = min,
                .max = max,
                .origin = max.add(min).divf(2),
                .extents = max.sub(min).divf(2),
            },
            physical_device_mem_props,
            imm_cmd,
        );
    }

    return meshes;
}

fn uploadMesh(
    indices: []const u32,
    vertices: []const types.Vertex,
    bounds: resources.Mesh.Bounds,
    physical_device_mem_props: c.VkPhysicalDeviceMemoryProperties,
    imm_cmd: ImmediateCommand,
) !resources.Mesh {
    const device = imm_cmd.device;
    const vb_size = vertices.len * @sizeOf(types.Vertex);
    const ib_size = indices.len * @sizeOf(u32);

    var mesh = resources.Mesh{
        .bounds = bounds,
        .vertex_buffer = try resources.createBuffer(
            device,
            physical_device_mem_props,
            vb_size,
            c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT |
                c.VK_BUFFER_USAGE_TRANSFER_DST_BIT |
                c.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ),
        .vb_addr = undefined,
        .index_buffer = try resources.createBuffer(
            device,
            physical_device_mem_props,
            ib_size,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT |
                c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ),
    };

    mesh.vb_addr = vk.getBufferDeviceAddress(
        device,
        &c.VkBufferDeviceAddressInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            .buffer = mesh.vertex_buffer.buffer,
        },
    );

    const staging = try resources.createBuffer(
        device,
        physical_device_mem_props,
        vb_size + ib_size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
            c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );

    // TODO allocate larger chunks of memory at once and use offsets
    // aka BlockAllocator
    var data: [*]u8 = undefined;
    try vk.check(vk.mapMemory(device, staging.memory, 0, vb_size + ib_size, 0, @ptrCast(&data)));
    @memcpy(data, std.mem.sliceAsBytes(vertices));
    @memcpy(data[vb_size..], std.mem.sliceAsBytes(indices));
    vk.unmapMemory(device, staging.memory);

    const C = struct {
        vertex_buffer: c.VkBuffer,
        vb_size: usize,
        index_buffer: c.VkBuffer,
        ib_size: usize,
        staging_buffer: c.VkBuffer,

        pub fn submit(this: @This(), cmd: c.VkCommandBuffer) void {
            vk.cmdCopyBuffer2(
                cmd,
                &c.VkCopyBufferInfo2{
                    .sType = c.VK_STRUCTURE_TYPE_COPY_BUFFER_INFO_2,
                    .srcBuffer = this.staging_buffer,
                    .dstBuffer = this.vertex_buffer,
                    .regionCount = 1,
                    .pRegions = &c.VkBufferCopy2{
                        .sType = c.VK_STRUCTURE_TYPE_BUFFER_COPY_2,
                        .dstOffset = 0,
                        .srcOffset = 0,
                        .size = this.vb_size,
                    },
                },
            );

            vk.cmdCopyBuffer2(
                cmd,
                &c.VkCopyBufferInfo2{
                    .sType = c.VK_STRUCTURE_TYPE_COPY_BUFFER_INFO_2,
                    .srcBuffer = this.staging_buffer,
                    .dstBuffer = this.index_buffer,
                    .regionCount = 1,
                    .pRegions = &c.VkBufferCopy2{
                        .sType = c.VK_STRUCTURE_TYPE_BUFFER_COPY_2,
                        .dstOffset = 0,
                        .srcOffset = this.vb_size,
                        .size = this.ib_size,
                    },
                },
            );
        }
    };

    try imm_cmd.submit(&C{
        .vertex_buffer = mesh.vertex_buffer.buffer,
        .vb_size = vb_size,
        .index_buffer = mesh.index_buffer.buffer,
        .ib_size = ib_size,
        .staging_buffer = staging.buffer,
    });

    vk.destroyBuffer(device, staging.buffer, null);
    vk.freeMemory(device, staging.memory, null);

    return mesh;
}

pub fn loadGltfTextures(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    glb: gltf.Glb,
    physical_device_mem_props: c.VkPhysicalDeviceMemoryProperties,
    imm_cmd: ImmediateCommand,
) ![]resources.Texture2D {
    const buffer_views = glb.gltf.bufferViews orelse return error.InvalidGltf;
    const bin = glb.bin orelse return error.InvalidGltf;

    const out_textures = try gpa.alloc(resources.Texture2D, glb.gltf.textures.?.len);
    for (glb.gltf.textures.?, out_textures) |tex, *out_tex| {
        out_tex.* = resources.Texture2D{
            .view = undefined,
            .image = undefined,
            .extent = undefined,
            .format = undefined,
            .memory = undefined,
            .sampler = undefined,
        };
        if (tex.sampler) |s| {
            const sampler = glb.gltf.samplers.?[s];

            var sampler_info = c.VkSamplerCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
                .addressModeU = vkWrapMode(sampler.wrapS),
                .addressModeV = vkWrapMode(sampler.wrapT),
            };

            if (sampler.magFilter) |mag| {
                sampler_info.magFilter = switch (mag) {
                    .nearest => c.VK_FILTER_NEAREST,
                    .linear => c.VK_FILTER_LINEAR,
                };
            }
            if (sampler.minFilter) |min| {
                switch (min) {
                    .linear => {
                        sampler_info.minFilter = c.VK_FILTER_LINEAR;
                    },
                    .linear_mipmap_linear => {
                        sampler_info.minFilter = c.VK_FILTER_LINEAR;
                        sampler_info.mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR;
                    },
                    .linear_mipmap_nearest => {
                        sampler_info.minFilter = c.VK_FILTER_LINEAR;
                        sampler_info.mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_NEAREST;
                    },
                    .nearest => {
                        sampler_info.minFilter = c.VK_FILTER_NEAREST;
                    },
                    .nearest_mipmap_linear => {
                        sampler_info.minFilter = c.VK_FILTER_NEAREST;
                        sampler_info.mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR;
                    },
                    .nearest_mipmap_nearest => {
                        sampler_info.minFilter = c.VK_FILTER_NEAREST;
                        sampler_info.mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_NEAREST;
                    },
                }
            }

            var vk_sampler: c.VkSampler = undefined;
            _ = vk.createSampler(imm_cmd.device, &sampler_info, null, &vk_sampler);
            out_tex.sampler = vk_sampler;
        }

        if (tex.source) |s| {
            const image = glb.gltf.images.?[s];
            const buffer_view_idx = image.bufferView orelse return error.InvalidGltf;
            const buffer_view = buffer_views[buffer_view_idx];
            const data_offset = buffer_view.byteOffset;
            const data_len = buffer_view.byteLength;
            const image_data = bin[data_offset..(data_offset + data_len)];
            const png_data = try png.fromBuffer(arena, image_data);

            const vk_image = try resources.createImage(
                imm_cmd.device,
                c.VK_FORMAT_R32G32B32A32_SFLOAT,
                c.VkExtent3D{
                    .width = png_data.header.width,
                    .height = png_data.header.height,
                    .depth = 1,
                },
                c.VK_IMAGE_USAGE_SAMPLED_BIT |
                    c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                    c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                c.VK_IMAGE_ASPECT_COLOR_BIT,
                physical_device_mem_props,
                c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            );

            const image_size = @sizeOf(math.Color4) * png_data.data.len;
            const staging = try resources.createBuffer(
                imm_cmd.device,
                physical_device_mem_props,
                image_size,
                c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                    c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            );

            // TODO allocate larger chunks of memory at once and use offsets
            var data: [*]u8 = undefined;
            try vk.check(vk.mapMemory(imm_cmd.device, staging.memory, 0, image_size, 0, @ptrCast(&data)));
            @memcpy(data, std.mem.sliceAsBytes(png_data.data));
            vk.unmapMemory(imm_cmd.device, staging.memory);

            const C = struct {
                staging_buffer: c.VkBuffer,
                image: resources.Image,

                pub fn submit(this: @This(), cmd: c.VkCommandBuffer) void {
                    vkdraw.transitionImage(
                        cmd,
                        this.image.image,
                        c.VK_IMAGE_LAYOUT_UNDEFINED,
                        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    );

                    vk.cmdCopyBufferToImage2(
                        cmd,
                        &c.VkCopyBufferToImageInfo2{
                            .sType = c.VK_STRUCTURE_TYPE_COPY_BUFFER_TO_IMAGE_INFO_2,
                            .srcBuffer = this.staging_buffer,
                            .dstImage = this.image.image,
                            .dstImageLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                            .regionCount = 1,
                            .pRegions = &c.VkBufferImageCopy2{
                                .sType = c.VK_STRUCTURE_TYPE_BUFFER_IMAGE_COPY_2,
                                .bufferOffset = 0,
                                .bufferRowLength = 0,
                                .bufferImageHeight = 0,

                                .imageSubresource = c.VkImageSubresourceLayers{
                                    .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                                    .mipLevel = 0,
                                    .baseArrayLayer = 0,
                                    .layerCount = 1,
                                },
                                .imageExtent = this.image.extent,
                            },
                        },
                    );

                    vkdraw.transitionImage(
                        cmd,
                        this.image.image,
                        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                        c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    );
                }
            };

            try imm_cmd.submit(&C{
                .staging_buffer = staging.buffer,
                .image = vk_image,
            });

            vk.destroyBuffer(imm_cmd.device, staging.buffer, null);
            vk.freeMemory(imm_cmd.device, staging.memory, null);

            out_tex.memory = vk_image.memory;
            out_tex.format = vk_image.format;
            out_tex.extent = c.VkExtent2D{
                .width = vk_image.extent.width,
                .height = vk_image.extent.height,
            };
            out_tex.image = vk_image.image;
            out_tex.view = vk_image.view;
        }
    }
    return out_textures;
}

pub fn vkWrapMode(self: gltf.Sampler.WrapMode) c.VkSamplerAddressMode {
    return switch (self) {
        .repeat => c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .clamp_to_edge => c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .mirrored_repeat => c.VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
    };
}

pub fn loadGltfMaterials(
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    glb: gltf.Glb,
    physical_device_mem_props: c.VkPhysicalDeviceMemoryProperties,
    imm_cmd: ImmediateCommand,
) ![]resources.Material {
    const buffer_views = glb.gltf.bufferViews orelse return error.InvalidGltf;
    const bin = glb.bin orelse return error.InvalidGltf;
    _ = bin;
    _ = buffer_views;
    _ = imm_cmd;
    _ = physical_device_mem_props;
    _ = arena;

    const out_materials = try gpa.alloc(resources.Material, glb.gltf.materials.?.len);
    for (glb.gltf.materials.?, out_materials) |mat, *out_mat| {
        out_mat.* = resources.Material{};
        _ = mat;
        // mat.pbrMetallicRoughness.?.
        // mat.emissiveFactor
    }
    return out_materials;
}
