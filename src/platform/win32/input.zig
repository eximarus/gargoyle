const std = @import("std");
const c = @import("c");

pub const KB = struct {
    pub const Event = enum {
        down,
        up,
    };
    pub const KeyCode = enum {
        esc,
        // ROW F
        f1,
        f2,
        f3,
        f4,
        f5,
        f6,
        f7,
        f8,
        f9,
        f10,
        f11,
        f12,

        // ROW NUM
        @"1",
        @"2",
        @"3",
        @"4",
        @"5",
        @"6",
        @"7",
        @"8",
        @"9",
        @"0",
        bckspc,

        // ROW 1
        tab,
        q,
        w,
        e,
        r,
        t,
        y,
        u,
        i,
        o,
        p,

        // ROW 2
        caps,
        a,
        s,
        d,
        f,
        g,
        h,
        j,
        k,
        l,
        enter,

        // ROW 3
        l_shift,
        z,
        x,
        c,
        v,
        b,
        n,
        m,
        r_shift,

        // ROW 4
        l_ctrl,
        l_alt,
        spc,
        r_alt,
        r_ctrl,
    };

    keys: std.AutoArrayHashMap(KeyCode, bool),
    events: std.AutoArrayHashMap(KeyCode, Event),

    pub fn toKeyCode(w_param: u32) !KeyCode {
        return switch (w_param) {
            c.VK_BACK => .bckspc,
            c.VK_TAB => .tab,
            c.VK_RETURN => .enter,
            c.VK_CAPITAL => .caps,
            c.VK_ESCAPE => .esc,
            c.VK_SPACE => .spc,
            0x30 => .@"0",
            0x31 => .@"1",
            0x32 => .@"2",
            0x33 => .@"3",
            0x34 => .@"4",
            0x35 => .@"5",
            0x36 => .@"6",
            0x37 => .@"7",
            0x38 => .@"8",
            0x39 => .@"9",
            0x41 => .a,
            0x42 => .b,
            0x43 => .c,
            0x44 => .d,
            0x45 => .e,
            0x46 => .f,
            0x47 => .g,
            0x48 => .h,
            0x49 => .i,
            0x4A => .j,
            0x4B => .k,
            0x4C => .l,
            0x4D => .m,
            0x4E => .n,
            0x4F => .o,
            0x50 => .p,
            0x51 => .q,
            0x52 => .r,
            0x53 => .s,
            0x54 => .t,
            0x55 => .u,
            0x56 => .v,
            0x57 => .w,
            0x58 => .x,
            0x59 => .y,
            0x5A => .z,
            c.VK_F1 => .f1,
            c.VK_F2 => .f2,
            c.VK_F3 => .f3,
            c.VK_F4 => .f4,
            c.VK_F5 => .f5,
            c.VK_F6 => .f6,
            c.VK_F7 => .f7,
            c.VK_F8 => .f8,
            c.VK_F9 => .f9,
            c.VK_F10 => .f10,
            c.VK_F11 => .f11,
            c.VK_F12 => .f12,
            c.VK_LSHIFT => .l_shift,
            c.VK_RSHIFT => .r_shift,
            c.VK_LCONTROL => .l_ctrl,
            c.VK_RCONTROL => .r_ctrl,
            c.VK_LMENU => .l_alt,
            c.VK_RMENU => .r_alt,

            else => return error.UnsupportedKey,
        };
    }

    pub inline fn getKey(self: *KB, key_code: KeyCode) bool {
        return self.keys.get(key_code) orelse false;
    }

    pub inline fn getKeyDown(self: *KB, key_code: KeyCode) bool {
        const event = self.events.get(key_code) orelse return false;
        return event == .down;
    }

    pub inline fn getKeyUp(self: *KB, key_code: KeyCode) bool {
        const event = self.events.get(key_code) orelse return false;
        return event == .up;
    }
};

pub const Mouse = struct {
    pub const Event = enum {
        down,
        up,
        dblclk,
    };

    pub const Button = enum {
        left,
        right,
        middle,
        extra1,
        extra2,
    };

    events: std.AutoArrayHashMap(Button, Event),
    buttons: std.AutoArrayHashMap(Button, bool),

    is_hovering: bool,
    pos: struct { x: u16, y: u16 },
    wheel_delta: f32,

    pub inline fn getButton(self: *Mouse, mb: Button) bool {
        return self.buttons.get(mb) orelse false;
    }

    pub inline fn getButtonDown(self: *Mouse, mb: Button) bool {
        const event = self.events.get(mb) orelse return false;
        return event == .down;
    }

    pub inline fn getButtonUp(self: *Mouse, mb: Button) bool {
        const event = self.events.get(mb) orelse return false;
        return event == .up;
    }

    pub inline fn getButtonDoubleClick(self: *Mouse, mb: Button) bool {
        const event = self.events.get(mb) orelse return false;
        return event == .dblclk;
    }

    pub inline fn getWheelUp(self: *Mouse) bool {
        return self.wheel_delta > 0;
    }

    pub inline fn getWheelDown(self: *Mouse) bool {
        return self.wheel_delta < 0;
    }

    pub inline fn setButtonUp(self: *Mouse, mb: Button) !void {
        try self.events.put(mb, .up);
        try self.buttons.put(mb, false);
    }

    pub inline fn setButtonDown(self: *Mouse, mb: Button) !void {
        try self.events.put(mb, .down);
        try self.buttons.put(mb, true);
    }
};

pub const Input = @This();

mouse: Mouse,
kb: KB,

pub fn init(allocator: std.mem.Allocator) Input {
    return Input{
        .kb = .{
            .keys = std.AutoArrayHashMap(KB.KeyCode, bool).init(allocator),
            .events = std.AutoArrayHashMap(KB.KeyCode, KB.Event).init(allocator),
        },
        .mouse = .{
            .buttons = std.AutoArrayHashMap(Mouse.Button, bool).init(allocator),
            .events = std.AutoArrayHashMap(Mouse.Button, Mouse.Event).init(allocator),
            .pos = .{ .x = 0, .y = 0 },
            .is_hovering = false,
            .wheel_delta = 0,
        },
    };
}
