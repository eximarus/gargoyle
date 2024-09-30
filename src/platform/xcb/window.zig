const c = @import("c");

pub const Window = extern struct {
    connection: *c.xcb_connection_t,
    window: c.xcb_window_t,
    width: u32,
    height: u32,
};
