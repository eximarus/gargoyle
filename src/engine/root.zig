const std = @import("std");
const gargoyle = @import("gargoyle");
const Context = gargoyle.Context;
const App = @import("app").App;
const AppConfig = gargoyle.AppConfig;

const Window = gargoyle.platform.Window;

const Engine = extern struct {
    engine: *gargoyle.Engine,
    app: *App,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn ggeCreate(window: Window) callconv(.C) *Engine {
    const e = gpa.allocator().create(Engine) catch |err| {
        std.debug.panic("failed to create engine. err:{}\n", .{err});
    };
    e.app = App.create(gpa.allocator()) catch |err| {
        std.debug.panic("failed to create app. err: {}\n", .{err});
    };

    e.engine = @constCast(&(gargoyle.Engine.init(
        gpa.allocator(),
        window,
        if (@hasDecl(App, "configure"))
            &App.configure()
        else
            &AppConfig{},
    ) catch |err| {
        std.debug.panic("failed to init engine. err: {}\n", .{err});
    }));

    return e;
}

export fn ggeUpdate(e: *Engine) callconv(.C) u32 {
    return e.engine.update(e.app);
}

export fn ggeShutdown(e: *Engine) callconv(.C) void {
    e.app.shutdown();
    e.engine.shutdown();
}
