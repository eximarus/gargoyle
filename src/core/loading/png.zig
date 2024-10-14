const std = @import("std");

const math = if (@import("builtin").is_test) struct {
    pub inline fn color4(r: f32, g: f32, b: f32, a: f32) Color4 {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub const Color4 = extern struct {
        r: f32,
        g: f32,
        b: f32,
        a: f32,
    };
} else @import("../root.zig").math;

const endian = std.builtin.Endian.big;
const png_signature = 0x89504E470D0A1A0A;

const ChunkType = enum(u32) {
    // critical
    ihdr = 0x49484452,
    plte = 0x504C5445,
    idat = 0x49444154,
    iend = 0x49454E44,
    // ancillary
    trns = 0x74524E53,
    chrm = 0x6348524D,
    gama = 0x67414D41,
    iccp = 0x69434350,
    sbit = 0x73424954,
    srgb = 0x73534742,
    cicp = 0x63494350,
    mdcv = 0x6D444376,
    clli = 0x634C4C69,
    // ...
    _,
};

const ColorType = enum(u8) {
    greyscale = 0,
    truecolor = 2,
    indexed_color = 3,
    greyscale_with_alpha = 4,
    truecolor_with_alpha = 6,
};

const FilterMethod = enum(u8) {
    adaptive = 0,
};

const CompressionMethod = enum(u8) {
    deflate = 0,
};

const InterlaceMethod = enum(u8) {
    none = 0,
    adam7 = 1,
};

const Header = struct {
    width: u32,
    height: u32,
    bit_depth: u8,
    color_type: ColorType,
    compression_method: CompressionMethod,
    filter_method: FilterMethod,
    interlace_method: InterlaceMethod,

    fn validate(self: Header) !void {
        if (self.width == 0) return error.InvalidWidth;
        if (self.height == 0) return error.InvalidHeight;
        switch (self.color_type) {
            .greyscale => {
                switch (self.bit_depth) {
                    1, 2, 4, 8, 16 => {},
                    else => return error.InvalidBitDepth,
                }
            },
            .truecolor => {
                switch (self.bit_depth) {
                    8, 16 => {},
                    else => return error.InvalidBitDepth,
                }
            },
            .indexed_color => {
                switch (self.bit_depth) {
                    1, 2, 4, 8 => {},
                    else => return error.InvalidBitDepth,
                }
            },
            .greyscale_with_alpha => {
                switch (self.bit_depth) {
                    8, 16 => {},
                    else => return error.InvalidBitDepth,
                }
            },
            .truecolor_with_alpha => {
                switch (self.bit_depth) {
                    8, 16 => {},
                    else => return error.InvalidBitDepth,
                }
            },
        }
    }
};

const Palette = extern struct {
    red: u8,
    green: u8,
    blue: u8,
};

const Transparency = union(enum) {
    const TrueColor = extern struct {
        red: u16,
        green: u16,
        blue: u16,
    };

    greyscale: u16,
    truecolor: TrueColor,
    indexed_color: []u8,
};

const FilterType = enum(u8) {
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,
};

const Png = struct {
    header: Header,
    palette: []Palette,
    transparency: ?Transparency = null,
    gamma: ?f32 = null,
    data: []math.Color4,
};

pub inline fn fromFile(arena: std.mem.Allocator, path: []const u8) !Png {
    const f = try std.fs.cwd().openFile(path, .{});
    defer f.close();

    return fromReader(arena, f.reader().any());
}

pub inline fn fromBuffer(arena: std.mem.Allocator, buf: []const u8) !Png {
    var stream = std.io.fixedBufferStream(buf);
    return fromReader(arena, stream.reader().any());
}

// TODO performance
pub fn fromReader(arena: std.mem.Allocator, reader: std.io.AnyReader) !Png {
    const signature = try reader.readInt(u64, endian);
    if (signature != png_signature) {
        return error.PngInvalidSignature;
    }

    var png = Png{
        .header = undefined,
        .palette = undefined,
        .data = undefined,
    };

    var compressed_data = std.ArrayList(u8).init(arena);

    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        const length = try reader.readInt(u32, endian);
        const chunk_buf = try arena.alloc(u8, length + @sizeOf(ChunkType));
        const read_size = try reader.read(chunk_buf);

        if (read_size != chunk_buf.len) {
            return error.PngReadSizeMismatch;
        }

        const crc = try reader.readInt(u32, endian);
        if (crc != std.hash.Crc32.hash(chunk_buf)) {
            return error.PngInvalidCrc;
        }

        var chunk_stream = std.io.fixedBufferStream(chunk_buf);
        const chunk_reader = chunk_stream.reader();
        const chunk_type = try chunk_reader.readEnum(ChunkType, endian);

        if (length > 0) {
            switch (chunk_type) {
                .ihdr => {
                    png.header = Header{
                        .width = try chunk_reader.readInt(u32, endian),
                        .height = try chunk_reader.readInt(u32, endian),
                        .bit_depth = try chunk_reader.readByte(),
                        .color_type = try chunk_reader.readEnum(ColorType, endian),
                        .compression_method = try chunk_reader.readEnum(CompressionMethod, endian),
                        .filter_method = try chunk_reader.readEnum(FilterMethod, endian),
                        .interlace_method = try chunk_reader.readEnum(InterlaceMethod, endian),
                    };
                    try png.header.validate();
                },
                .plte => {
                    switch (png.header.color_type) {
                        .greyscale, .greyscale_with_alpha => return error.PngPalleteNotSupported,
                        else => {},
                    }
                    const item_count = length / 3;
                    const items = try arena.alloc(Palette, item_count);
                    for (items) |*item| {
                        item.* = try chunk_reader.readStructEndian(Palette, endian);
                    }
                    png.palette = items;
                },
                .trns => {
                    switch (png.header.color_type) {
                        .greyscale => {
                            png.transparency = .{
                                .greyscale = try chunk_reader.readInt(
                                    u16,
                                    endian,
                                ),
                            };
                        },
                        .truecolor => {
                            png.transparency = .{
                                .truecolor = try chunk_reader.readStructEndian(
                                    Transparency.TrueColor,
                                    endian,
                                ),
                            };
                        },
                        .indexed_color => {
                            const items = try arena.alloc(u8, png.palette.len);
                            const chunk_read_size = try chunk_reader.read(items);
                            if (chunk_read_size != items.len) {
                                return error.PngInvalidIndexedColorReadSize;
                            }
                            png.transparency = .{ .indexed_color = items };
                        },
                        else => return error.PngInvalidTrnsColorType,
                    }
                },
                .gama => {
                    const encoded_gamma = try chunk_reader.readInt(u32, endian);
                    png.gamma = @as(f32, @floatFromInt(encoded_gamma)) / 100000.0;
                },
                .idat => {
                    try compressed_data.ensureUnusedCapacity(length);
                    const slice = compressed_data.unusedCapacitySlice();
                    const comp_read_size = try chunk_reader.read(slice[0..length]);
                    if (comp_read_size != length) {
                        return error.ReadSizeMismatch;
                    }
                    compressed_data.items.len += length;
                },
                else => {},
            }
        }

        if (chunk_type == .iend) {
            break;
        }
    }

    if (i == 10000) {
        return error.PngTooManyChunks;
    }

    var decompressed_data = try std.ArrayList(u8).initCapacity(
        arena,
        compressed_data.items.len,
    );

    var compressed_stream = std.io.fixedBufferStream(compressed_data.items);

    try std.compress.zlib.decompress(
        compressed_stream.reader(),
        decompressed_data.writer(),
    );

    png.data = try arena.alloc(math.Color4, png.header.width * png.header.height);
    const bytes_per_pixel: u8 = switch (png.header.color_type) {
        .greyscale => (png.header.bit_depth + 7) / 8,
        .truecolor => 3 * png.header.bit_depth / 8,
        .indexed_color => 1,
        .greyscale_with_alpha => 2 * png.header.bit_depth / 8,
        .truecolor_with_alpha => 4 * png.header.bit_depth / 8,
    };

    const stride = png.header.width * bytes_per_pixel;
    var prev_scanline = try arena.alloc(u8, stride);
    var curr_scanline = try arena.alloc(u8, stride);

    var decompressed_stream = std.io.fixedBufferStream(decompressed_data.items);
    const final_reader = decompressed_stream.reader();

    const extractFn = createExtractFn(
        png.header.color_type,
        png.header.bit_depth,
    );

    for (0..png.header.height) |y| {
        const ftype = try final_reader.readEnum(FilterType, endian);
        const read_size = try final_reader.read(curr_scanline);
        if (read_size != curr_scanline.len) {
            return error.ReadSizeMismatch;
        }
        recon(ftype, curr_scanline, prev_scanline, bytes_per_pixel);

        for (0..png.header.width) |x| {
            const idx = x + y * png.header.width;
            png.data[idx] = extractFn(png, curr_scanline, x);
        }

        std.mem.swap([]u8, &prev_scanline, &curr_scanline);
    }

    return png;
}

fn recon(
    filter_type: FilterType,
    curr_scanline: []u8,
    prev_scanline: []u8,
    bpp: usize,
) void {
    switch (filter_type) {
        .none => {},
        .sub => reconSub(curr_scanline, bpp),
        .up => reconUp(curr_scanline, prev_scanline),
        .average => reconAverage(curr_scanline, prev_scanline, bpp),
        .paeth => reconPaeth(curr_scanline, prev_scanline, bpp),
    }
}

fn reconSub(scanline: []u8, bpp: usize) void {
    for (bpp..scanline.len) |i| {
        const curr_byte = scanline[i];
        const prev_byte = scanline[i - bpp];
        scanline[i], _ = @addWithOverflow(curr_byte, prev_byte);
    }
}

test reconSub {
    var scanline = ([_]u8{127} ** 512);
    reconSub(&scanline, 1);

    for (scanline, 0..) |item, i| {
        try std.testing.expectEqual(127 * (i + 1) % 256, item);
    }
}

fn reconUp(scanline: []u8, prev_scanline: []const u8) void {
    for (scanline, 0..) |*curr_byte, i| {
        const prev_byte = prev_scanline[i];
        const result, _ = @addWithOverflow(curr_byte.*, prev_byte);
        curr_byte.* = result;
    }
}

test reconUp {
    var scanline = ([_]u8{127} ** 512);
    var prev_scanline = ([_]u8{127} ** 512);
    reconUp(&scanline, &prev_scanline);
    for (scanline) |item| {
        try std.testing.expectEqual(254, item);
    }
}

fn reconAverage(scanline: []u8, prev_scanline: []u8, bpp: usize) void {
    for (scanline, 0..) |*curr_byte, i| {
        const left: u16 = if (i >= bpp) @intCast(scanline[i - bpp]) else 0;
        const up: u16 = @intCast(prev_scanline[i]);
        const result, _ = @addWithOverflow(curr_byte.*, @as(u8, @intCast((left + up) / 2)));
        curr_byte.* = result;
    }
}

test reconAverage {
    var scanline = ([_]u8{127} ** 512);
    var prev_scanline = ([_]u8{127} ** 512);
    reconAverage(&scanline, &prev_scanline, 1);
}

fn reconPaeth(scanline: []u8, prev_scanline: []u8, bpp: usize) void {
    for (scanline, 0..) |*curr_byte, i| {
        const left: i16 = if (i >= bpp) @intCast(scanline[i - bpp]) else 0;
        const up: i16 = @intCast(prev_scanline[i]);
        const upper_left: i16 = if (i >= bpp) @intCast(prev_scanline[i - bpp]) else 0;

        const p = left + up - upper_left;
        const p_left = @abs(p - left);
        const p_up = @abs(p - up);
        const p_upper_left = @abs(p - upper_left);

        const paeth_pred: u8 = if (p_left < p_up and p_left <= p_upper_left)
            @intCast(left)
        else if (p_up <= p_upper_left)
            @intCast(up)
        else
            @intCast(upper_left);

        const result, _ = @addWithOverflow(curr_byte.*, paeth_pred);
        curr_byte.* = result;
    }
}

test reconPaeth {
    var scanline = ([_]u8{127} ** 512);
    var prev_scanline = ([_]u8{127} ** 512);
    reconPaeth(&scanline, &prev_scanline, 1);
}

// TODO Png argument is cache unfriendly
fn createExtractFn(
    color_type: ColorType,
    bit_depth: u8,
) *const fn (Png, []u8, usize) math.Color4 {
    return switch (color_type) {
        .greyscale => switch (bit_depth) {
            1 => &createExtractGreyscale(1, false),
            2 => &createExtractGreyscale(2, false),
            4 => &createExtractGreyscale(4, false),
            8 => &createExtractGreyscale(8, false),
            16 => &createExtractGreyscale(16, false),
            else => unreachable,
        },
        .truecolor => switch (bit_depth) {
            8 => &createExtractTrueColor(8, false),
            16 => &createExtractTrueColor(16, false),
            else => unreachable,
        },
        .indexed_color => switch (bit_depth) {
            1 => &createExtractIndexed(1),
            2 => &createExtractIndexed(2),
            4 => &createExtractIndexed(4),
            8 => &createExtractIndexed(8),
            else => unreachable,
        },
        .greyscale_with_alpha => switch (bit_depth) {
            1 => &createExtractGreyscale(1, true),
            2 => &createExtractGreyscale(2, true),
            4 => &createExtractGreyscale(4, true),
            8 => &createExtractGreyscale(8, true),
            16 => &createExtractGreyscale(16, true),
            else => unreachable,
        },
        .truecolor_with_alpha => switch (bit_depth) {
            8 => &createExtractTrueColor(8, true),
            16 => &createExtractTrueColor(16, true),
            else => unreachable,
        },
    };
}

fn createExtractTrueColor(comptime bit_depth: comptime_int, comptime with_alpha: bool) fn (Png, []u8, usize) math.Color4 {
    return switch (bit_depth) {
        8 => struct {
            fn extract(_: Png, scanline: []u8, x: usize) math.Color4 {
                const base = x * if (with_alpha) 4 else 3;
                var vec = @Vector(4, f32){
                    @floatFromInt(scanline[base]),
                    @floatFromInt(scanline[base + 1]),
                    @floatFromInt(scanline[base + 2]),
                    if (with_alpha) @floatFromInt(scanline[base + 3]) else 255.0,
                };
                vec /= @splat(255.0);
                return @bitCast(vec);
            }
        }.extract,
        16 => struct {
            fn extract(_: Png, scanline: []u8, x: usize) math.Color4 {
                const base = x * 2 * if (with_alpha) 4 else 3;

                var vec1 = @Vector(4, u16){
                    scanline[base],
                    scanline[base + 2],
                    scanline[base + 4],
                    if (with_alpha) scanline[base + 6] else 255.0,
                };
                vec1 <<= @splat(8);

                const vec2 = @Vector(4, u16){
                    scanline[base + 1],
                    scanline[base + 3],
                    scanline[base + 5],
                    if (with_alpha) scanline[base + 7] else 255.0,
                };

                vec1 |= vec2;

                var vec3 = @Vector(4, f32){
                    @floatFromInt(vec1[0]),
                    @floatFromInt(vec1[1]),
                    @floatFromInt(vec1[2]),
                    @floatFromInt(vec1[3]),
                };
                vec3 /= @splat(65535.0);

                return @bitCast(vec3);

                // return @as(f32, @floatFromInt(@as(u16, @intCast(first)) << 8 |
                //     @as(u16, @intCast(second)))) / 65535.0;

                // return math.color4(
                //     extract16(scanline[base], scanline[base + 1]),
                //     extract16(scanline[base + 2], scanline[base + 3]),
                //     extract16(scanline[base + 4], scanline[base + 5]),
                //     if (with_alpha)
                //         extract16(scanline[base + 6], scanline[base + 7])
                //     else
                //         1.0,
                // );
            }
        }.extract,
        else => unreachable,
    };
}

fn createExtractGreyscale(comptime bit_depth: comptime_int, comptime with_alpha: bool) fn (Png, []u8, usize) math.Color4 {
    return switch (bit_depth) {
        1, 2, 4 => struct {
            fn extract(_: Png, scanline: []u8, x: usize) math.Color4 {
                const grey = extract8(extractBits(scanline, x, bit_depth));
                return math.color4(
                    grey,
                    grey,
                    grey,
                    1.0,
                );
            }
        }.extract,
        8 => struct {
            fn extract(_: Png, scanline: []u8, x: usize) math.Color4 {
                const grey = extract8(scanline[x]);
                return math.color4(
                    grey,
                    grey,
                    grey,
                    if (with_alpha)
                        extract8(scanline[x + 1])
                    else
                        1.0,
                );
            }
        }.extract,
        16 => struct {
            fn extract(_: Png, scanline: []u8, x: usize) math.Color4 {
                const grey = extract16(scanline[x], scanline[x + 1]);
                return math.color4(
                    grey,
                    grey,
                    grey,
                    if (with_alpha)
                        extract16(scanline[x + 2], scanline[x + 3])
                    else
                        1.0,
                );
            }
        }.extract,
        else => unreachable,
    };
}

fn createExtractIndexed(comptime bit_depth: comptime_int) fn (Png, []u8, usize) math.Color4 {
    return struct {
        fn extract(png: Png, scanline: []u8, x: usize) math.Color4 {
            const index = extractBits(scanline, x, bit_depth);
            const rgb = png.palette[index];

            var vec = @Vector(4, f32){
                @floatFromInt(rgb.red),
                @floatFromInt(rgb.blue),
                @floatFromInt(rgb.green),
                if (png.transparency) |t|
                    @floatFromInt(t.indexed_color[index])
                else
                    255.0,
            };
            vec /= @splat(255.0);
            return @bitCast(vec);
        }
    }.extract;
}

inline fn extract8(val: u8) f32 {
    return @as(f32, @floatFromInt(val)) / 255.0;
}

inline fn extract16(first: u8, second: u8) f32 {
    return @as(f32, @floatFromInt(@as(u16, @intCast(first)) << 8 |
        @as(u16, @intCast(second)))) / 65535.0;
}

inline fn extractBits(scanline: []u8, x: usize, bit_depth: u8) u8 {
    const bits_per_pixel: usize = @intCast(bit_depth);
    const byte_idx = (x * bits_per_pixel) / 8;
    const bit_offset = (x * bits_per_pixel) % 8;
    const shift: u3 = @intCast(@as(u4, 8) - bit_offset - bits_per_pixel);

    return @intCast(scanline[byte_idx] >> shift & ((@as(u16, 1) << bits_per_pixel) - 1));
}

test "png" {
    const buf: []const u8 = &.{
        // Signature
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        // IHDR
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x02,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x12, 0x16, 0xf1,
        0x4d,
        // IDAT
        0x00, 0x00, 0x00, 0x1f, 0x49, 0x44, 0x41,
        0x54, 0x08, 0x1d, 0x01, 0x14, 0x00, 0xeb, 0xff,
        0x00, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00,
        0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0x80, 0x80,
        0x80, 0xff, 0xff, 0xff, 0x3a, 0x61, 0x07, 0x7b,
        0xcb, 0xca, 0x5c, 0x63,
        // IEND
        0x00, 0x00, 0x00, 0x00,
        0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const png = try fromBuffer(arena.allocator(), buf);
    try std.testing.expectEqual(3, png.header.width);
    try std.testing.expectEqual(2, png.header.height);
    try std.testing.expectEqual(8, png.header.bit_depth);
    try std.testing.expectEqual(.truecolor, png.header.color_type);
    try std.testing.expectEqual(.deflate, png.header.compression_method);
    try std.testing.expectEqual(.adaptive, png.header.filter_method);
    try std.testing.expectEqual(.none, png.header.interlace_method);
    try std.testing.expectEqual(3 * 2, png.data.len);

    const tolerance = 0.01;
    try std.testing.expectApproxEqAbs(1, png.data[0].r, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[0].g, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[0].b, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[0].a, tolerance);

    try std.testing.expectApproxEqAbs(0, png.data[1].r, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[1].g, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[1].b, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[1].a, tolerance);

    try std.testing.expectApproxEqAbs(0, png.data[2].r, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[2].g, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[2].b, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[2].a, tolerance);

    try std.testing.expectApproxEqAbs(0, png.data[3].r, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[3].g, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[3].b, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[3].a, tolerance);

    try std.testing.expectApproxEqAbs(0.5, png.data[4].r, tolerance);
    try std.testing.expectApproxEqAbs(0.5, png.data[4].g, tolerance);
    try std.testing.expectApproxEqAbs(0.5, png.data[4].b, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[4].a, tolerance);

    try std.testing.expectApproxEqAbs(1, png.data[5].r, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[5].g, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[5].b, tolerance);
    try std.testing.expectApproxEqAbs(1, png.data[5].a, tolerance);
}

test "tRNS" {
    const buf: []const u8 = &.{
        // Signature
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        // IHDR
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x03, 0x00, 0x00, 0x00, 0x28, 0xcb, 0x34,
        0xbb,
        // PLTE
        0x00, 0x00, 0x00, 0x03, 0x50, 0x4c, 0x54,
        0x45, 0x00, 0x00, 0x00, 0xa7, 0x7a, 0x3d, 0xda,
        // tRNS
        0x00, 0x00, 0x00, 0x01, 0x74, 0x52, 0x4e, 0x53,
        0x64, 0x0a, 0x39, 0x7d, 0x27,
        // IDAT
        0x00, 0x00, 0x00,
        0x0d, 0x49, 0x44, 0x41, 0x54, 0x08, 0x1d, 0x01,
        0x02, 0x00, 0xfd, 0xff, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x01, 0xcd, 0xe3, 0xd1, 0x2b,
        // IEND
        0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
        0x60, 0x82,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const png = try fromBuffer(arena.allocator(), buf);

    try std.testing.expectEqual(1, png.header.width);
    try std.testing.expectEqual(1, png.header.height);
    try std.testing.expectEqual(8, png.header.bit_depth);
    try std.testing.expectEqual(.indexed_color, png.header.color_type);
    try std.testing.expectEqual(.deflate, png.header.compression_method);
    try std.testing.expectEqual(.adaptive, png.header.filter_method);
    try std.testing.expectEqual(.none, png.header.interlace_method);
    try std.testing.expectEqual(1, png.data.len);

    const tolerance = 0.01;
    try std.testing.expectApproxEqAbs(0, png.data[0].r, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[0].g, tolerance);
    try std.testing.expectApproxEqAbs(0, png.data[0].b, tolerance);
    try std.testing.expectApproxEqAbs(0.4, png.data[0].a, tolerance);
}
