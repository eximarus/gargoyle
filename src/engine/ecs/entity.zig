const std = @import("std");
const ArrayList = std.ArrayList;
const MultiArrayList = std.MultiArrayList;

pub const Error = error{
    InvalidEntity,
    InvalidArchetype,
};

// const ChunkAllocator = struct {
//     child_allocator: std.mem.Allocator,
//     fba: std.heap.FixedBufferAllocator,
//     chunk_size: usize,
//
//     pub inline fn init(
//         child_allocator: std.mem.Allocator,
//         options: struct {
//             chunk_size: usize = 16 * 1024 * 1024,
//         },
//     ) ChunkAllocator {
//         const mem = try child_allocator.alloc(u8, options.chunk_size);
//         return ChunkAllocator{
//             .child_allocator = child_allocator,
//             .fba = std.heap.FixedBufferAllocator.init(mem),
//             .chunk_size = options.chunk_size,
//         };
//     }
//
//     pub fn allocator(self: *ChunkAllocator) std.mem.Allocator {
//         std.heap.ArenaAllocator;
//         return .{
//             .ptr = self,
//             .vtable = &.{
//                 .alloc = alloc,
//                 .resize = resize,
//                 .free = free,
//             },
//         };
//     }
//
//     fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
//         var self: *ChunkAllocator = @ptrCast(@alignCast(ctx));
//         var a = self.fba.allocator();
//
//         var buf = a.rawAlloc(len, ptr_align, ret_addr);
//         if (buf == null and self.child_allocator.resize(
//             self.fba.buffer,
//             self.fba.buffer.len + self.chunk_size,
//         )) {
//             buf = a.rawAlloc(len, ptr_align, ret_addr);
//         }
//         return buf;
//     }
//
//     fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
//         var self: *ChunkAllocator = @ptrCast(@alignCast(ctx));
//         var a = self.fba.allocator();
//
//         var result = a.rawResize(buf, buf_align, new_len, ret_addr);
//         if (!result and self.child_allocator.resize(
//             self.fba.buffer,
//             self.fba.buffer.len + self.chunk_size,
//         )) {
//             result = a.rawResize(buf, buf_align, new_len, ret_addr);
//         }
//         return result;
//     }
//
//     fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
//         var self: *ChunkAllocator = @ptrCast(@alignCast(ctx));
//         self.fba.allocator().rawFree(buf, buf_align, ret_addr);
//     }
//
//     pub fn deinit(self: *ChunkAllocator) void {
//         self.child_allocator.free(self.fba.buffer);
//     }
// };

pub fn Archetype(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Elem = T;

        pub const EntityGen = u32;
        pub const Entity = struct {
            idx: usize,
            gen: EntityGen,
        };

        const Pool = std.ArrayList(Entity);
        const GenerationCounters = std.ArrayListUnmanaged(EntityGen);
        const Components = std.MultiArrayList(Elem);

        allocator: std.mem.Allocator,
        generation_counters: GenerationCounters,
        pool: Pool,
        components: Components,

        pub fn init(
            allocator: std.mem.Allocator,
            size: usize,
            pool_size: usize,
        ) !Self {
            const capacity = if (size == 0) 16 * 1024 else size / (@sizeOf(EntityGen) + @sizeOf(Elem));
            var self: Self = undefined;
            self.allocator = allocator;
            self.generation_counters = try GenerationCounters
                .initCapacity(allocator, capacity);
            self.pool = try Pool.initCapacity(
                allocator,
                if (pool_size == 0) 8 else pool_size,
            );
            self.components = Components{};
            try self.components.ensureTotalCapacity(
                allocator,
                capacity,
            );

            return self;
        }

        // fn createChunk(self: Self) void {
        //     const mem = self.allocator.alloc(u8, 16 * 1024 * 1024);
        //     const fba = std.heap.FixedBufferAllocator.init(mem);
        //     _ = fba; // autofix
        // }

        pub fn createEntity(self: *Self, v: Elem) !Entity {
            const e = if (self.pool.popOrNull()) |item|
                item
            else blk: {
                const gen = 1;
                const idx = try self.components.addOne(self.allocator);
                try self.generation_counters.insert(self.allocator, idx, gen);
                break :blk Entity{
                    .idx = idx,
                    .gen = gen,
                };
            };

            self.components.set(e.idx, v);
            return e;
        }

        fn FieldType(comptime field: Components.Field) type {
            return std.meta.fieldInfo(Elem, field).type;
        }

        pub fn getComponentData(
            self: Self,
            e: Entity,
            comptime field: Components.Field,
        ) Error!*FieldType(field) {
            try self.validateEntity(e);
            return &self.components.items(field)[e.idx];
        }

        pub fn setComponentData(
            self: *Self,
            e: Entity,
            comptime field: Components.Field,
            t: FieldType(field),
        ) Error!void {
            try self.validateEntity(e);
            self.components.items(field)[e.idx] = t;
        }

        pub fn destroyEntity(self: *Self, e: Entity) !void {
            try self.validateEntity(e);
            var newE = e;
            newE.gen += 1;
            self.generation_counters.items[newE.idx] = newE.gen;
            try self.pool.append(newE);
        }

        pub fn deinit(self: *Self) void {
            self.components.deinit(self.allocator);
            self.generation_counters.deinit(self.allocator);
            self.pool.deinit();
        }

        inline fn validateEntity(self: Self, e: Entity) Error!void {
            if (e.gen == 0 or e.gen != self.generation_counters.items[e.idx]) {
                return Error.InvalidEntity;
            }
        }
    };
}

// Transform
pub const Translation = struct { x: f32, y: f32 };
pub const Rotation = f32;
pub const Scale = struct { x: f32, y: f32 };

// Sprite
pub const Rect = struct { x: f32, y: f32, width: f32, height: f32 };
pub const Color = struct { r: f32, g: f32, b: f32, a: f32 };
pub const Flip = struct {
    x: bool,
    y: bool,
};

// Physics
pub const Velocity = struct { x: f32, y: f32 };
