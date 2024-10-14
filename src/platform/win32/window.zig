const c = @import("c");
const Input = @import("input.zig");

pub const Window = extern struct {
    hinstance: c.HINSTANCE,
    hwnd: c.HWND,
    width: u32,
    height: u32,
    input: *Input,
};
