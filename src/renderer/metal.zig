const std = @import("std");
const glfw = @import("mach-glfw");
const wgpu = @import("mach-gpu");
const builtin = @import("builtin");
const target = builtin.target;

const Window = @import("../window.zig");

const objc = struct {
    const SEL = ?*opaque {};
    const Class = ?*opaque {};

    extern fn sel_getUid(str: [*:0]const u8) SEL;
    extern fn objc_getClass(name: [*:0]const u8) Class;
    extern fn objc_msgSend() void;
};

fn msgSend(obj: anytype, sel_name: [:0]const u8, args: anytype, comptime ReturnType: type) ReturnType {
    const args_meta = @typeInfo(@TypeOf(args)).Struct.fields;

    const FnType = switch (args_meta.len) {
        0 => *const fn (@TypeOf(obj), objc.SEL) callconv(.C) ReturnType,
        1 => *const fn (@TypeOf(obj), objc.SEL, args_meta[0].type) callconv(.C) ReturnType,
        2 => *const fn (
            @TypeOf(obj),
            objc.SEL,
            args_meta[0].type,
            args_meta[1].type,
        ) callconv(.C) ReturnType,
        3 => *const fn (
            @TypeOf(obj),
            objc.SEL,
            args_meta[0].type,
            args_meta[1].type,
            args_meta[2].type,
        ) callconv(.C) ReturnType,
        4 => *const fn (
            @TypeOf(obj),
            objc.SEL,
            args_meta[0].type,
            args_meta[1].type,
            args_meta[2].type,
            args_meta[3].type,
        ) callconv(.C) ReturnType,
        else => @compileError("[zgpu] Unsupported number of args"),
    };

    const func = @as(FnType, @ptrCast(&objc.objc_msgSend));
    const sel = objc.sel_getUid(sel_name.ptr);

    return @call(.never_inline, func, .{ obj, sel } ++ args);
}

pub fn getMetalLayer(window: *const glfw.Window) *anyopaque {
    const ns_window = glfw.Native(.{ .cocoa = true })
        .getCocoaWindow(window.*).?;

    const layer = msgSend(
        objc.objc_getClass("CAMetalLayer"),
        "layer",
        .{},
        ?*anyopaque,
    ) orelse {
        @panic("failed to create Metal layer");
    };

    const ns_view = msgSend(ns_window, "contentView", .{}, *anyopaque);
    msgSend(ns_view, "setWantsLayer:", .{true}, void);
    msgSend(ns_view, "setLayer:", .{layer.?}, void);

    // retina support
    const scale_factor = msgSend(ns_window, "backingScaleFactor", .{}, f64);
    msgSend(layer, "setContentsScale:", .{scale_factor}, void);
    return layer;
}
