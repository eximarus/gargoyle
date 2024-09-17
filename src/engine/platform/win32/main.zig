const std = @import("std");
const WINAPI = std.os.windows.WINAPI;
const c = @cImport({
    @cInclude("windows.h");
});

pub export fn WindowProc(hwnd: c.HWND, uMsg: c_uint, wParam: c.WPARAM, lParam: c.LPARAM) callconv(WINAPI) c.LRESULT {
    _ = switch (uMsg) {
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
    hInstance: std.os.windows.HINSTANCE,
    hPrevInstance: ?std.os.windows.HINSTANCE,
    _: std.os.windows.PWSTR,
    _: std.os.windows.INT,
) callconv(WINAPI) std.os.windows.INT {
    _ = hPrevInstance;

    const window_title = "Gargoyle";

    var class = std.mem.zeroes(c.WNDCLASSEXA);
    class.cbSize = @sizeOf(c.WNDCLASSEXA);
    class.style = c.CS_VREDRAW | c.CS_HREDRAW;
    class.hInstance = @ptrCast(hInstance);
    class.lpszClassName = "gargoyle_window_class";
    class.lpfnWndProc = WindowProc;

    const class_atom = c.RegisterClassExA(&class);
    if (class_atom == 0) {
        const last_error = c.GetLastError();
        var lp_msg_buf: c.LPVOID = undefined;

        _ = c.FormatMessageA(
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
        defer _ = c.LocalFree(lp_msg_buf);

        std.log.err("{s}\n", .{@as(c.LPSTR, @ptrCast(lp_msg_buf))});
        return 1;
    }

    const hwnd = c.CreateWindowExA(
        c.WS_EX_CLIENTEDGE,
        class_atom,
        window_title,
        c.WS_OVERLAPPEDWINDOW,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        null, // parent window
        null, // menu
        hInstance,
        null, // additional application data
    );
    _ = c.ShowWindow(hwnd, c.SW_NORMAL);
    _ = c.UpdateWindow(hwnd);

    var message: c.MSG = std.mem.zeroes(c.MSG);
    while (c.GetMessageA(&message, null, 0, 0) > 0) {
        _ = c.TranslateMessage(&message);
        _ = c.DispatchMessageA(&message);
    }
    return 0;
}
