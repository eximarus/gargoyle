const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const lib_path = "./../lib/gargoyle.so";

    const fd, const wd = try startWatch();
    defer std.posix.close(fd);
    while (true) {
        const shouldReload = handleWatch(fd, wd);
        if (shouldReload) {}
    }
}

fn startWatch() !struct { i32, i32 } {
    const fd = try std.posix.inotify_init1(std.os.linux.IN.NONBLOCK);
    const wd = try std.posix.inotify_add_watch(
        fd,
        "src",
        std.os.linux.IN.MODIFY | std.os.linux.IN.CREATE | std.os.linux.IN.DELETE,
    );
    return .{ fd, wd };
}

fn handleWatch(fd: i32, wd: i32) !bool {
    // fds[0].fd = STDIN_FILENO;       /* Console input */
    // fds[0].events = POLLIN;

    const poll_fd = std.posix.pollfd{ .fd = fd, .events = std.posix.POLL.IN };
    const poll_num = try std.posix.poll(&.{poll_fd}, -1);
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
        len = try std.posix.read(fd, &buf);
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
