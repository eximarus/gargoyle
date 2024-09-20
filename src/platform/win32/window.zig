const c = @import("c");

pub const Window = extern struct {
    hinstance: c.HINSTANCE,
    hwnd: c.HWND,
    width: u32,
    height: u32,
};
