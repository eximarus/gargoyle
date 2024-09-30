const std = @import("std");
const gg = @import("gargoyle");
const Window = gg.platform.Window;

const Runtime = extern struct {
    engine: *gg.Engine,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn ggCreate(window: Window) callconv(.C) *Runtime {
    const allocator = gpa.allocator();
    const instance = allocator.create(Runtime) catch |err| {
        std.debug.panic("failed to create runtime. err:{}\n", .{err});
    };

    instance.engine = gg.Engine.create(
        allocator,
        window,
    ) catch |err| {
        std.debug.panic("failed to create engine. err: {}\n", .{err});
    };

    return instance;
}

export fn ggUpdate(rt: *Runtime) callconv(.C) u32 {
    return rt.engine.update();
}

export fn ggShutdown(rt: *Runtime) callconv(.C) void {
    rt.engine.shutdown();
}
