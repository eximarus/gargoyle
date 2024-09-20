const std = @import("std");
const c = @import("c");
const Window = @import("root.zig").Window;
const WINAPI = std.os.windows.WINAPI;

const Engine = opaque {};
var createEngine: *const fn (Window) callconv(.C) *Engine = undefined;
var updateEngine: *const fn (*Engine) callconv(.C) u32 = undefined;
var shutdownEngine: *const fn (*Engine) callconv(.C) void = undefined;

// pub fn logFn(
//     comptime message_level: std.log.Level,
//     comptime scope: @Type(.EnumLiteral),
//     comptime format: []const u8,
//     args: anytype,
// ) void {
//     const level_txt = comptime message_level.asText();
//     const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
//     var buf: [4096]u8 = undefined;
//     const msg = std.fmt.bufPrintZ(&buf, level_txt ++ prefix2 ++ format ++ "\n", args) catch "";
//     c.OutputDebugStringA(msg);
// }
//
// pub const std_options: std.Options = .{
//     .logFn = logFn,
// };

pub export fn WindowProc(hwnd: c.HWND, uMsg: c_uint, wParam: c.WPARAM, lParam: c.LPARAM) callconv(WINAPI) c.LRESULT {
    _ = switch (uMsg) {
        c.WM_ERASEBKGND,
        c.WM_NCACTIVATE,
        c.WM_NCPAINT,
        => return 1,
        c.WM_CLOSE => c.DestroyWindow(hwnd),
        c.WM_DESTROY => c.PostQuitMessage(0),
        else => {
            // std.log.warn("Unknown window message: 0x{x:0>4}\n", .{uMsg});
        },
    };
    return c.DefWindowProcA(hwnd, uMsg, wParam, lParam);
}

pub export fn WinMain(
    hInstance: std.os.windows.HINSTANCE,
    hPrevInstance: ?std.os.windows.HINSTANCE,
    pCmdLine: std.os.windows.PWSTR,
    nCmdShow: std.os.windows.INT,
) callconv(WINAPI) std.os.windows.INT {
    return wWinMain(hInstance, hPrevInstance, pCmdLine, nCmdShow);
}

pub export fn wWinMain(
    _hInstance: std.os.windows.HINSTANCE,
    _: ?std.os.windows.HINSTANCE,
    _: std.os.windows.PWSTR,
    _: std.os.windows.INT,
) callconv(WINAPI) std.os.windows.INT {
    const hinstance: c.HINSTANCE = @ptrCast(@alignCast(_hInstance));

    var class = std.mem.zeroes(c.WNDCLASSEXA);
    class.cbSize = @sizeOf(c.WNDCLASSEXA);
    class.style = c.CS_DBLCLKS;
    class.hInstance = hinstance;
    class.lpszClassName = "gargoyle_window_class";
    class.lpfnWndProc = WindowProc;
    class.hCursor = c.LoadCursorA(null, c.MAKEINTRESOURCEA(32512));

    const class_atom = c.RegisterClassExA(&class);
    if (class_atom == 0) {
        logLastError();
        return 1;
    }

    const screen_width = c.GetSystemMetrics(c.SM_CXSCREEN);
    const screen_height = c.GetSystemMetrics(c.SM_CYSCREEN);

    const hwnd = c.CreateWindowExA(
        0, // dwExStyle
        class_atom, // lpClassName
        null, // lpWindowName
        c.WS_POPUP | c.WS_VISIBLE, // dwStyle
        0, // X
        0, // Y
        screen_width, // nWidth
        screen_height, // nHeight
        null, // hWndParent
        null, // hMenu
        hinstance, // hInstance
        null, // additional application data
    );
    _ = c.ShowWindow(hwnd, c.SW_NORMAL);

    var dyn_lib = std.DynLib.open("gargoyle.dll") catch |err| {
        std.log.err("failed to load gargoyle.dll. err: {}\n", .{err});
        return 1;
    };
    createEngine = dyn_lib.lookup(@TypeOf(createEngine), "ggeCreate") orelse {
        std.log.err("failed to load createEngine function. \n", .{});
        return 1;
    };
    updateEngine = dyn_lib.lookup(@TypeOf(updateEngine), "ggeUpdate") orelse {
        std.log.err("failed to load updateEngine function. \n", .{});
        return 1;
    };
    shutdownEngine = dyn_lib.lookup(@TypeOf(shutdownEngine), "ggeShutdown") orelse {
        std.log.err("failed to load shutdownEngine function. \n", .{});
        return 1;
    };

    const window = Window{
        .hwnd = hwnd,
        .hinstance = hinstance,
        .width = @intCast(screen_width),
        .height = @intCast(screen_height),
    };
    const engine = createEngine(window);
    defer shutdownEngine(engine);

    var msg: c.MSG = std.mem.zeroes(c.MSG);
    while (c.GetMessageA(&msg, null, 0, 0) > 0) {
        _ = c.TranslateMessage(&msg);
        _ = c.DispatchMessageA(&msg);
        const r = updateEngine(engine);
        switch (r) {
            0 => {},
            1 => return 0,
            else => return 1,
        }
    }
    return 0;
}

fn logLastError() void {
    const last_error = c.GetLastError();
    var lp_msg_buf: c.LPVOID = undefined;

    const size = c.FormatMessageA(
        c.FORMAT_MESSAGE_ALLOCATE_BUFFER |
            c.FORMAT_MESSAGE_FROM_SYSTEM |
            c.FORMAT_MESSAGE_IGNORE_INSERTS,
        null,
        last_error,
        c.MAKELANGID(c.LANG_NEUTRAL, c.SUBLANG_DEFAULT),
        @ptrCast(&lp_msg_buf),
        0,
        null,
    );

    if (size > 0) {
        std.log.err("{s}\n", .{@as(c.LPSTR, @ptrCast(lp_msg_buf))});
        defer _ = c.LocalFree(lp_msg_buf);
    } else {
        std.log.err("Unknown Windows Error\n", .{});
    }
}
