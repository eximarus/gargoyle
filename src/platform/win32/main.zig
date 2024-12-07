const std = @import("std");
const c = @import("c");

const Runtime = @import("runtime");
const platform = @import("platform");
const Input = platform.Input;
const Window = platform.Window;
const WINAPI = std.os.windows.WINAPI;

var input: Input = undefined;

// TODO proper error handling
pub export fn WindowProc(hwnd: c.HWND, u_msg: c_uint, w_param: c.WPARAM, l_param: c.LPARAM) callconv(WINAPI) c.LRESULT {
    _ = switch (u_msg) {
        c.WM_KEYDOWN => {
            if (Input.KB.toKeyCode(@intCast(w_param))) |key_code| {
                input.kb.events.put(key_code, .down) catch {};
                input.kb.keys.put(key_code, true) catch {};
            } else |err| {
                switch (err) {
                    error.UnsupportedKey => {},
                    // else => {
                    //     std.log.debug("{}", .{err});
                    // },
                }
            }
        },
        c.WM_KEYUP => {
            if (Input.KB.toKeyCode(@intCast(w_param))) |key_code| {
                input.kb.events.put(key_code, .up) catch {};
                input.kb.keys.put(key_code, false) catch {};
            } else |err| {
                switch (err) {
                    error.UnsupportedKey => {},
                    // else => {
                    //     std.log.debug("{}", .{err});
                    // },
                }
            }
        },
        c.WM_MOUSEMOVE => {
            const xy: i32 = @intCast(l_param);
            const y: i16 = @intCast(xy >> 16);
            const x: i16 = @truncate(xy);

            input.mouse.pos = .{
                .x = @max(0, x),
                .y = @max(0, y),
            };
            input.mouse.is_hovering = false;
        },
        c.WM_MOUSEHOVER => {
            input.mouse.is_hovering = true;
        },
        c.WM_MOUSEWHEEL => {
            const word: u32 = @intCast(w_param);
            const rotation: u16 = @intCast(word >> 16);
            input.mouse.wheel_delta = @as(f32, @floatFromInt(rotation)) / @as(f32, @floatFromInt(c.WHEEL_DELTA));
        },
        c.WM_LBUTTONUP => {
            input.mouse.setButtonUp(.left) catch {};
        },
        c.WM_LBUTTONDOWN => {
            input.mouse.setButtonDown(.left) catch {};
        },
        c.WM_RBUTTONUP => {
            input.mouse.setButtonUp(.right) catch {};
        },
        c.WM_RBUTTONDOWN => {
            input.mouse.setButtonDown(.right) catch {};
        },
        c.WM_MBUTTONUP => {
            input.mouse.setButtonUp(.middle) catch {};
        },
        c.WM_MBUTTONDOWN => {
            input.mouse.setButtonDown(.middle) catch {};
        },
        c.WM_XBUTTONUP => {
            var num: u32 = @intCast(w_param);
            num >>= 16;
            switch (num) {
                c.XBUTTON1 => {
                    input.mouse.setButtonUp(.extra1) catch {};
                },
                c.XBUTTON2 => {
                    input.mouse.setButtonUp(.extra2) catch {};
                },
                else => unreachable,
            }
        },
        c.WM_XBUTTONDOWN => {
            var num: u32 = @intCast(w_param);
            num >>= 16;
            switch (num) {
                c.XBUTTON1 => {
                    input.mouse.setButtonDown(.extra1) catch {};
                },
                c.XBUTTON2 => {
                    input.mouse.setButtonDown(.extra2) catch {};
                },
                else => unreachable,
            }
        },
        c.WM_ERASEBKGND,
        c.WM_NCACTIVATE,
        c.WM_NCPAINT,
        => return 1,
        c.WM_CLOSE => c.DestroyWindow(hwnd),
        c.WM_DESTROY => c.PostQuitMessage(0),
        else => {},
    };
    return c.DefWindowProcA(hwnd, u_msg, w_param, l_param);
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
        c.WS_POPUP | c.WS_CLIPSIBLINGS | c.WS_CLIPCHILDREN, // dwStyle
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

    var inputBuf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&inputBuf);
    const allocator = fba.allocator();
    input = Input.init(allocator);

    const window = Window{
        .hwnd = hwnd,
        .hinstance = hinstance,
        .width = @intCast(screen_width),
        .height = @intCast(screen_height),
        .input = &input,
    };

    var rt = Runtime.init(window, "gargoyle.dll") catch |err| {
        std.log.err("caught error during runtime init: {}", .{err});
        if (@errorReturnTrace()) |t| {
            std.debug.dumpStackTrace(t.*);
        }
        return 1;
    };
    defer rt.shutdown();

    var msg: c.MSG = std.mem.zeroes(c.MSG);
    while (true) {
        input.kb.events.clearRetainingCapacity();
        input.mouse.events.clearRetainingCapacity();
        input.mouse.wheel_delta = 0;

        while (c.PeekMessageA(&msg, null, 0, 0, c.PM_NOREMOVE) == c.TRUE) {
            if (c.GetMessageA(&msg, null, 0, 0) > 0) {
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageA(&msg);
            } else {
                return 1;
            }
        }

        switch (rt.update()) {
            .@"continue" => {},
            .quit => return 0,
            else => |r| return @intFromEnum(r),
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
