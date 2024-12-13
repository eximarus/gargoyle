const std = @import("std");

pub fn Archetype(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Elem = T;
        pub const Index = enum(u16) { none = std.math.maxInt(u16), _ };
        pub const Generation = enum(u16) { none = 0, _ };

        pub const Id = packed struct(u32) {
            idx: Index,
            gen: Generation,
        };

        gpa: std.mem.Allocator,
        elems: std.MultiArrayList(Elem) = std.MultiArrayList(Elem){},
        generations: std.ArrayListUnmanaged(Generation) = std.ArrayListUnmanaged(Generation){},
        free_list: std.ArrayListUnmanaged(Id) = std.ArrayListUnmanaged(Id){},

        pub fn init(gpa: std.mem.Allocator) Self {
            return Self{
                .gpa = gpa,
            };
        }

        pub fn create(self: *Self, elem: T) !Id {
            const id = self.free_list.popOrNull() orelse blk: {
                try self.generations.append(self.gpa, @enumFromInt(1));
                break :blk Id{
                    .idx = @enumFromInt(try self.elems.addOne(self.gpa)),
                    .gen = @enumFromInt(1),
                };
            };

            std.debug.assert(self.isValid(id));
            self.elems.set(@intFromEnum(id.idx), elem);
            return id;
        }

        pub fn get(self: *Self, id: Id) T {
            std.debug.assert(self.isValid(id));
            return self.elems.get(@intFromEnum(id.idx));
        }

        pub fn destroy(self: *Self, id: Id) !void {
            std.debug.assert(self.isValid(id));
            const new_gen, const flag = @addWithOverflow(id.gen, 1);

            const new_id = Id{
                .idx = id.idx,
                .gen = new_gen,
            };
            self.generations.items[new_id.idx] = new_id.gen;
            if (!flag) {
                try self.free_list.append(self.gpa, id);
            }
        }

        fn isValid(self: *Self, id: Id) bool {
            if (id.idx == .none or id.gen == .none) {
                return false;
            }

            const gen = self.generations.items[@intFromEnum(id.idx)];
            if (gen != id.gen) {
                return false;
            }
            return true;
        }
    };
}
