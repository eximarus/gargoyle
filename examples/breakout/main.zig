const std = @import("std");
const entity = @import("gargoyle");
const Archetype = entity.Archetype;
const Translation = entity.Translation;
const Rotation = entity.Rotation;
const Scale = entity.Scale;
const Velocity = entity.Velocity;
const Rect = entity.Rect;
const Color = entity.Color;
const Flip = entity.Flip;

pub const BrickType = union(enum) {
    sprite: u4,
    solid: void,
};

pub const Lives = u4;

pub const Player = Archetype(struct {
    translation: Translation,
    scale: Scale,
    velocity: Velocity,

    rect: Rect,
    color: Color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
    flip: Flip = .{ .x = false, .y = false },

    lives: Lives,
});

pub const Brick = Archetype(struct {
    translation: Translation,

    rect: Rect,
    color: Color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
    flip: Flip = .{ .x = false, .y = false },

    type: BrickType,
});

pub const Ball = Archetype(struct {
    translation: Translation,
    velocity: Velocity,

    rect: Rect,
    color: Color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
    flip: Flip = .{ .x = false, .y = false },
});

pub const Column = struct {
    brick_type: ?BrickType = null,
};

const levels = [1][1][15]Column{
    [1][15]Column{ // LEVEL
        [15]Column{ // ROW
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
            Column{ .brick_type = 4 },
        },
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();
    var players = try Player.init(allocator, 64, 1);
    defer players.deinit();

    const playerE = try players.createEntity(.{
        .translation = .{ .x = 0.0, .y = 0.0 },
        .rotation = 0.0,
        .scale = .{ .x = 1.0, .y = 1.0 },
        .velocity = .{ .x = 5.0, .y = 0.0 },
        .sprite = .{
            .rect = .{
                .x = 0,
                .y = 0,
                .width = 0,
                .height = 0,
            },
        },
        .lives = 3,
    });
    _ = playerE;

    const screen_width = 800;
    const screen_height = 600;

    var bricks = try Brick.init(allocator, 0, 0);
    const level1 = levels[0];
    for (level1, 0..) |row, y| {
        for (row, 0..) |column, x| {
            const brick_type = column.brick_type orelse continue;
            const rect = Rect{
                .x = 0.5, // pivot?
                .y = 0.5,
                .width = screen_width / row.len,
                .height = screen_height / level1.len,
            };

            const trans = Translation{
                .x = rect.width * x,
                .y = rect.height * y,
            };

            switch (brick_type) {
                .solid => try bricks.createEntity(.{
                    .type = brick_type,
                    .translation = trans,
                    .rect = rect,
                }),
                .sprite => |s| try bricks.createEntity(.{
                    .type = brick_type,
                    .translation = trans,
                    .rect = rect,
                    .color = switch (s) {
                        1 => Color{ .r = 0.2, .g = 0.6, .b = 1.0, .a = 1.0 },
                        2 => Color{ .r = 0.0, .g = 0.7, .b = 0.0, .a = 1.0 },
                        3 => Color{ .r = 0.8, .g = 0.8, .b = 0.4, .a = 1.0 },
                        4 => Color{ .r = 1.0, .g = 0.5, .b = 0.0, .a = 1.0 },
                    },
                }),
            }
        }
    }
}
