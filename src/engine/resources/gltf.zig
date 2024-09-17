const std = @import("std");

pub const Vec3 = [3]f32;
pub const Vec2 = [2]f32;
pub const Vec4 = [4]f32;
pub const Mat4 = [16]f32;

pub const Accessor = struct {
    pub const ComponentType = enum(u32) {
        byte = 5120,
        unsigned_byte = 5121,
        short = 5122,
        unsigned_short = 5123,
        unsigned_int = 5125,
        float = 5126,

        pub fn size(self: ComponentType) usize {
            return switch (self) {
                .byte => @sizeOf(i8),
                .unsigned_byte => @sizeOf(u8),
                .short => @sizeOf(i16),
                .unsigned_short => @sizeOf(u16),
                .unsigned_int => @sizeOf(u32),
                .float => @sizeOf(f32),
            };
        }
    };
    pub const Sparse = struct {
        pub const Indices = struct {
            bufferView: usize,
            byteOffset: usize = 0,
            componentType: ComponentType,
            extensions: ?std.json.Value = null,
            extras: ?std.json.Value = null,
        };
        pub const Values = struct {
            bufferView: usize,
            byteOffset: usize = 0,
            extensions: ?std.json.Value = null,
            extras: ?std.json.Value = null,
        };

        count: usize,
        indices: Indices,
        values: Values,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };

    bufferView: ?usize,
    byteOffset: usize = 0,
    componentType: ComponentType,
    normalized: bool = false,
    count: usize,
    type: []const u8, // e.g., "SCALAR", "VEC2", "VEC3", "VEC4", "MAT4"
    max: ?[]f32 = null,
    min: ?[]f32 = null,
    sparse: ?Sparse = null,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Animation = struct {
    pub const Channel = struct {
        pub const Target = struct {
            node: ?usize = null,
            path: []const u8, // "translation", "rotation", "scale", "weights"
        };
        sampler: usize,
        target: Target,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };

    pub const Sampler = struct {
        input: usize,
        interpolation: []const u8 = "LINEAR", // "LINEAR", "STEP", "CUBICSPLINE"
        output: usize,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };
    channels: []Channel,
    samplers: []Animation.Sampler,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Asset = struct {
    copyright: ?[]const u8 = null,
    generator: ?[]const u8 = null,
    version: []const u8,
    minVersion: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Buffer = struct {
    uri: ?[]const u8 = null,
    byteLength: usize,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const BufferView = struct {
    pub const Target = enum(u32) {
        array_buffer = 34962,
        element_array_buffer = 34963,
    };
    buffer: usize,
    byteOffset: usize = 0,
    byteLength: usize,
    byteStride: ?usize = null,
    target: ?Target = null,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Camera = struct {
    pub const Orthographic = struct {
        xmag: f32,
        ymag: f32,
        zfar: f32,
        znear: f32,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };
    pub const Perspective = struct {
        aspectRatio: ?f32 = null,
        yfov: f32,
        zfar: ?f32 = null,
        znear: f32,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };
    orthographic: ?Orthographic = null,
    perspective: ?Perspective = null,
    type: []const u8, // "perspective", "orthographic"
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Gltf = struct {
    accessors: ?[]Accessor = null,
    animations: ?[]Animation = null,
    asset: Asset,
    buffers: ?[]Buffer = null,
    bufferViews: ?[]BufferView = null,
    cameras: ?[]Camera = null,
    images: ?[]Image = null,
    materials: ?[]Material = null,
    meshes: ?[]Mesh = null,
    nodes: ?[]Node = null,
    samplers: ?[]Sampler = null,
    scene: ?usize = null,
    scenes: ?[]Scene = null,
    skins: ?[]Skin = null,
    textures: ?[]Texture = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Image = struct {
    uri: ?[]const u8 = null,
    mimeType: ?[]const u8 = null,
    bufferView: ?usize = null,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Material = struct {
    pub const NormalTextureInfo = struct {
        index: usize,
        texCoord: u32 = 0,
        scale: f32 = 1,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };
    pub const OcclusionTextureInfo = struct {
        index: usize,
        texCoord: u32 = 0,
        strength: f32 = 1,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };
    pub const PbrMetallicRoughness = struct {
        baseColorFactor: Vec4 = Vec4{ 1, 1, 1, 1 },
        baseColorTexture: ?TextureInfo = null,
        metallicFactor: f32 = 1,
        roughnessFactor: f32 = 1,
        metallicRoughnessTexture: ?TextureInfo = null,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,
    };

    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
    pbrMetallicRoughness: ?PbrMetallicRoughness = null,
    normalTexture: ?NormalTextureInfo = null,
    occlusionTexture: ?OcclusionTextureInfo = null,
    emissiveTexture: ?TextureInfo = null,
    emissiveFactor: Vec3 = Vec3{ 0, 0, 0 },
    alphaMode: []const u8 = "OPAQUE", // "OPAQUE", "MASK", or "BLEND"
    alphaCutoff: f32 = 0.5,
    doubleSided: bool = false,
};

pub const Mesh = struct {
    pub const Primitive = struct {
        pub const Mode = enum(u32) {
            points = 0,
            lines = 1,
            line_loop = 2,
            line_strip = 3,
            triangles = 4,
            triangle_strip = 5,
            triangle_fan = 6,
        };
        attributes: std.json.Value,
        indices: ?usize = null,
        material: ?usize = null,
        mode: Mode = .triangles,
        targets: ?std.json.Value = null,
        extensions: ?std.json.Value = null,
        extras: ?std.json.Value = null,

        pub fn findAttribute(self: *const Primitive, id: []const u8) ?usize {
            const item = self.attributes.object.get(id) orelse return null;
            return @intCast(item.integer);
        }
    };
    primitives: []Primitive,
    weights: ?[]f32 = null,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Node = struct {
    camera: ?usize = null,
    children: ?[]usize = null,
    skin: ?usize = null,
    matrix: Mat4 = Mat4{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 },
    mesh: ?usize = null,
    rotation: Vec4 = Vec4{ 0, 0, 0, 1 },
    scale: Vec3 = Vec3{ 1, 1, 1 },
    translation: Vec3 = Vec3{ 0, 0, 0 },
    weights: ?[]f32 = null,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Sampler = struct {
    pub const MagFilter = enum(u32) {
        nearest = 9728,
        linear = 9729,
    };
    pub const MinFilter = enum(u32) {
        nearest = 9728,
        linear = 9729,
        nearest_mipmap_nearest = 9984,
        linear_mipmap_nearest = 9985,
        nearest_mipmap_linear = 9986,
        linear_mipmap_linear = 9987,
    };
    pub const WrapMode = enum(u32) {
        clamp_to_edge = 33071,
        mirrored_repeat = 33648,
        repeat = 10497,
    };
    magFilter: ?MagFilter = null,
    minFilter: ?MinFilter = null,
    wrapS: WrapMode = .repeat,
    wrapT: WrapMode = .repeat,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Scene = struct {
    nodes: ?[]usize = null,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Skin = struct {
    inverseBindMatrices: ?usize = null,
    skeleton: ?usize = null,
    joints: []usize,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const Texture = struct {
    sampler: ?usize = null,
    source: ?usize = null,
    name: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

pub const TextureInfo = struct {
    index: usize,
    texCoord: u32 = 0,
    extensions: ?std.json.Value = null,
    extras: ?std.json.Value = null,
};

const Glb = struct {
    gltf: Gltf,
    bin: ?[]const u8,
};

const ChunkType = enum(u32) {
    bin = 0x004E4942,
    json = 0x4E4F534A,
};

pub fn load(path: []const u8, arena: std.mem.Allocator) !Glb {
    const f = try std.fs.cwd().openFile(path, .{});
    defer f.close();

    const endian = std.builtin.Endian.little;
    var reader = f.reader();
    const magic = try reader.readInt(u32, endian);
    if (magic == 0x46546C67) {
        const version = try reader.readInt(u32, endian);
        if (version != 2) {
            return error.InvalidGltfVersion;
        }

        const length = try reader.readInt(u32, endian);

        const json_length = try reader.readInt(u32, endian);
        const json_chunk_type = try reader.readEnum(ChunkType, endian);

        if (json_chunk_type != .json) {
            return error.InvalidFormat;
        }

        const json_bytes = try arena.alloc(u8, json_length);
        _ = try reader.read(json_bytes);

        const json = try std.json.parseFromSliceLeaky(Gltf, arena, json_bytes, .{});

        if (length - 12 - 8 - json_length > 0) {
            const bin_length = try reader.readInt(u32, endian);
            const bin_chunk_type = try reader.readEnum(ChunkType, endian);

            if (bin_chunk_type != .bin) {
                return error.InvalidFormat;
            }
            const bin = try reader.readAllAlloc(arena, bin_length);
            return Glb{
                .gltf = json,
                .bin = bin,
            };
        }
        return Glb{
            .gltf = json,
            .bin = null,
        };
    } else {
        try f.seekTo(0);

        const size = try f.getEndPos();
        const bin = try reader.readAllAlloc(arena, size);
        const json = try std.json.parseFromSliceLeaky(Gltf, arena, bin, .{});

        return Glb{
            .gltf = json,
            .bin = null,
        };
    }
}

pub inline fn readVertex(bin: []const u8, buffer_views: []BufferView, acc: Accessor, index: usize, stride: usize) []const u8 {
    const buffer_view = buffer_views[acc.bufferView.?];
    const vtx_data_offset = buffer_view.byteOffset + acc.byteOffset + stride * index;
    return bin[vtx_data_offset..(vtx_data_offset + stride)];
}
