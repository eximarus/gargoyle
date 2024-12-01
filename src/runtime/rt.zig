const std = @import("std");
const types = @import("./types.zig");
const Window = opaque {};
const App = opaque {};

const Runtime = @This();

var dyn_lib: ?std.DynLib = null;
var ggStart: *const fn (Window) callconv(.C) *App = undefined;
var ggUpdate: *const fn (*App, f32) callconv(.C) types.UpdateResult = undefined;
var ggStatusChanged: *const fn (*App, types.Status) callconv(.C) void = undefined;
var ggReload: *const fn (*App) callconv(.C) void = undefined;
var ggLowMemory: *const fn (*App) callconv(.C) void = undefined;
var ggShutdown: *const fn (*App) callconv(.C) void = undefined;

fn loadAppDll(path: []const u8) !void {
    if (dyn_lib != null) {
        return error.AlreadyLoaded;
    }

    dyn_lib = try std.DynLib.open(path);
    ggStart = try dyn_lib.?.lookup(@TypeOf(ggStart), "ggStart");
    ggUpdate = try dyn_lib.?.lookup(@TypeOf(ggUpdate), "ggUpdate");
    ggStatusChanged = try dyn_lib.?.lookup(@TypeOf(ggStatusChanged), "ggStatusChanged");
    ggLowMemory = try dyn_lib.?.lookup(@TypeOf(ggLowMemory), "ggLowMemory");
    ggReload = try dyn_lib.?.lookup(@TypeOf(ggReload), "ggReload");
    ggShutdown = try dyn_lib.?.lookup(@TypeOf(ggShutdown), "ggShutdown");
}

fn unloadAppDll() !void {
    if (dyn_lib == null) {
        return error.NotLoaded;
    }

    dyn_lib.close();
    dyn_lib = null;
}

dll_path: []const u8,
timer: std.time.Timer,
app: *App,

pub fn init(window: Window, dll_path: []const u8) !Runtime {
    try loadAppDll(dll_path);

    return Runtime{
        .dll_path = dll_path,
        .app = ggStart(window),
        .timer = std.time.Timer.start() catch unreachable,
    };
}

pub fn update(self: *Runtime) types.UpdateResult {
    const dt_ns = self.timer.lap();
    const dt = @as(f32, @floatCast(@as(f64, @floatFromInt(dt_ns)) /
        @as(f64, @floatFromInt(std.time.ns_per_s))));

    return ggUpdate(self.app, dt);
}

pub fn updateStatus(self: *Runtime, status: types.Status) void {
    ggStatusChanged(self.app, status);
}

pub fn lowMemory(self: *Runtime) void {
    ggLowMemory(self.app);
}

// TODO websocket connection to a file watch / compilation server
// server will send us new dlls and assets to load
// this is dangerous so we have to ensure this only works over the local network
fn reload(self: *Runtime) !void {
    unloadAppDll() catch unreachable;
    try loadAppDll(self.dll_path);
    ggReload(self.app);
}

pub fn shutdown(self: *Runtime) void {
    ggShutdown(self.app);
}
