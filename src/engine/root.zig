const std = @import("std");
const App = @import("app").App;
const gargoyle = @import("gargoyle");
const Context = gargoyle.Context;
const AppConfig = gargoyle.AppConfig;

const Window = gargoyle.platform.Window;

const Instance = extern struct {
    engine: *gargoyle.Engine,
    app: *App,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn ggCreate(window: Window) callconv(.C) *Instance {
    const allocator = gpa.allocator();
    const instance = allocator.create(Instance) catch |err| {
        std.debug.panic("failed to create engine. err:{}\n", .{err});
    };

    instance.app = App.create(allocator) catch |err| {
        std.debug.panic("failed to create app. err: {}\n", .{err});
    };

    instance.engine = gargoyle.Engine.create(
        allocator,
        window,
        if (@hasDecl(App, "configure"))
            &App.configure()
        else
            &AppConfig{},
    ) catch |err| {
        std.debug.panic("failed to init engine. err: {}\n", .{err});
    };

    return instance;
}

export fn ggUpdate(instance: *Instance) callconv(.C) u32 {
    return instance.engine.update(instance.app);
}

export fn ggShutdown(instance: *Instance) callconv(.C) void {
    instance.app.shutdown();
    instance.engine.shutdown();
}
