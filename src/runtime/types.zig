pub const UpdateResult = enum(i32) {
    @"continue" = 0,
    quit = -1,
    _,
};

pub const Status = enum(u32) {
    foreground,
    visible,
    invisible,
};
