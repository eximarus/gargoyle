const c = @import("c");

pub const vk = struct {
    pub const lib_path = "libvulkan.so.1";
};

pub const Window = extern struct {
    display: c.wl_display,
    surface: c.wl_surface,
};
