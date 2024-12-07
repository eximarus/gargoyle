const gg = @import("gargoyle");
const App = @import("app").App;

export fn ggStart(window: gg.platform.Window) callconv(.C) ?*App {
    return App.start(window) catch null;
}

export fn ggUpdate(app: *App, dt: f32) callconv(.C) gg.rt.UpdateResult {
    return app.update(dt) catch |err| @enumFromInt(@intFromError(err));
}

export fn ggStatusChanged(app: *App, status: gg.rt.Status) callconv(.C) void {
    app.onStatusChanged(status);
}

export fn ggReload(app: *App) callconv(.C) void {
    app.onReload();
}

export fn ggLowMemory(app: *App) callconv(.C) void {
    app.onLowMemory();
}

export fn ggShutdown(app: *App) callconv(.C) void {
    app.shutdown();
}
