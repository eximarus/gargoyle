pub const Position = extern struct { x: u32, y: u32 };
pub const Size = extern struct { width: u32, height: u32 };
pub const Mode = enum(i32) {
    windowed,
    fullscreen,
    borderless_fullscreen,
};

pub const Config = extern struct {
    title: [*]const u8,
    mode: Mode = .borderless_fullscreen,
    size: ?*Size = null,
    pos: ?*Position = null,
};
