const std = @import("std");
const gg = @import("gargoyle");
const Window = gg.platform.Window;

export fn ggCreate(window: Window) callconv(.C) *gg.Engine {
    return gg.Engine.create(window) catch |err| {
        std.debug.panic("failed to create engine. err: {}\n", .{err});
    };
}

export fn ggUpdate(e: *gg.Engine) callconv(.C) u32 {
    return e.update();
}

export fn ggShutdown(e: *gg.Engine) callconv(.C) void {
    e.shutdown();
}
