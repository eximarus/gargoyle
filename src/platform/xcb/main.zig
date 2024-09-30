const std = @import("std");
const c = @import("c");

pub fn main() !void {
    const lib_path = "./../lib/libgargoyle.so";
    _ = lib_path;

    const fd, const wd = try startWatch();
    defer std.posix.close(fd);

    const connection = c.xcb_connect(null, null);
    defer c.xcb_disconnect(connection);

    const setup = c.xcb_get_setup(connection);
    const screen = c.xcb_setup_roots_iterator(setup).data;

    std.debug.print("w: {}, h: {}\n", .{ screen.*.width_in_pixels, screen.*.height_in_pixels });

    const window = c.xcb_generate_id(connection);
    _ = c.xcb_create_window(
        connection,
        c.XCB_COPY_FROM_PARENT, // depth (same as root)
        window,
        screen.*.root, // parent window
        0, // x
        0, // y
        screen.*.width_in_pixels, // width
        screen.*.height_in_pixels, // height
        0, // border_width
        c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        screen.*.root_visual,
        c.XCB_CW_BACK_PIXEL | c.XCB_CW_EVENT_MASK,
        null,
    );

    _ = c.xcb_map_window(connection, window);
    // xcb_set_input_focus(connection,XCB_INPUT_FOCUS_POINTER_ROOT,window,XCB_CURRENT_TIME);
    _ = c.xcb_flush(connection);

    while (true) {
        const shouldReload = handleWatch(fd, wd);
        if (shouldReload) {}

        var e = c.xcb_wait_for_event(connection);
        while (e != 0) : (e = c.xcb_poll_for_event(connection)) {
            defer std.c.free(e);
        }
    }
}

fn startWatch() !struct { i32, i32 } {
    const fd = try std.posix.inotify_init1(std.os.linux.IN.NONBLOCK);
    const wd = try std.posix.inotify_add_watch(
        fd,
        "src",
        std.os.linux.IN.MODIFY |
            std.os.linux.IN.CREATE |
            std.os.linux.IN.DELETE,
    );
    return .{ fd, wd };
}

fn handleWatch(fd: i32, wd: i32) bool {
    // fds[0].fd = STDIN_FILENO;       /* Console input */
    // fds[0].events = POLLIN;

    const poll_fd = std.posix.pollfd{
        .fd = fd,
        .events = std.posix.POLL.IN,
        .revents = 0,
    };
    const poll_num = std.posix.poll(@constCast(&[_]std.posix.pollfd{poll_fd}), -1) catch return false;
    if (poll_num < 1) {
        return false;
    }

    if (poll_fd.revents & std.posix.POLL.IN == 0) {
        return false;
    }

    _ = wd;
    var buf: [4096]u8 align(@alignOf(std.os.linux.inotify_event)) = undefined;
    var len: usize = undefined;
    var changed = false;
    // var event: *std.os.linux.inotify_event = undefined;
    while (true) {
        len = std.posix.read(fd, &buf) catch break;
        if (len <= 0) {
            break;
        }
        changed = true;

        // const buf_ptr = @intFromPtr(&buf);
        // var ptr = buf_ptr;
        // while (ptr < buf_ptr + len) : (ptr += @sizeOf(std.os.linux.inotify_event) + event.len) {
        //     event = @ptrFromInt(ptr);
        // }
    }
    return changed;
}
