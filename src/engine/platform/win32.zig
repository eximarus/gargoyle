const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

fn windowProc() callconv(.WINAPI) std.os.windows.LRESULT {}

pub fn createWindow() void {
    const class_name: []const std.os.windows.WCHAR = "Sample Window Class";
    const wc = c.WNDCLASS{
        .lpfnWndProc = windowProc,
        .hInstance = c.hInstance,
        .lpszClassName = class_name,
    };
    c.RegisterClass(&wc);
}
