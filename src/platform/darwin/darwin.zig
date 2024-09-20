const objc = struct {
    const SEL = *opaque {};
    const id = *opaque {};

    extern fn sel_getUid(str: [*:0]const u8) callconv(.C) SEL;
    extern fn objc_getClass(name: [*:0]const u8) callconv(.C) ?id;
    extern fn objc_msgSend() callconv(.C) void;
};

pub const vk_lib_name = "libvulkan.1.dylib";

const CAMetalLayer = opaque {
    fn layer() ?*CAMetalLayer {
        const Fn = *fn (self: objc.id, op: objc.SEL) ?*CAMetalLayer;
        const func: Fn = @ptrCast(&objc.objc_msgSend);
        return func(
            objc.objc_getClass("CAMetalLayer") orelse return null,
            objc.sel_getUid("layer"),
        );
    }

    fn setContentsScale(self: *CAMetalLayer, scale_factor: f64) void {
        const Fn = *fn (self: objc.id, op: objc.SEL, scale_factor: f64) void;
        const func: Fn = @ptrCast(&objc.objc_msgSend);
        func(@ptrCast(self), objc.sel_getUid("setContentsScale:"), scale_factor);
    }
};

const NSWindow = opaque {
    fn contentView(self: *NSWindow) *NSView {
        const Fn = *fn (self: objc.id, op: objc.SEL) *NSView;
        const func: Fn = @ptrCast(&objc.objc_msgSend);
        return func(@ptrCast(self), objc.sel_getUid("contentView"));
    }

    fn backingScaleFactor(self: *NSWindow) f64 {
        const Fn = *fn (self: objc.id, op: objc.SEL) f64;
        const func: Fn = @ptrCast(&objc.objc_msgSend);
        return func(@ptrCast(self), objc.sel_getUid("backingScaleFactor"));
    }
};

const NSView = opaque {
    fn setWantsLayer(self: *NSView, value: bool) void {
        const Fn = *fn (self: objc.id, op: objc.SEL, value: bool) void;
        const func: Fn = @ptrCast(&objc.objc_msgSend);
        func(@ptrCast(self), objc.sel_getUid("setWantsLayer:"), value);
    }

    // technically accepts any CALayer
    fn setLayer(self: *NSView, value: *CAMetalLayer) void {
        const Fn = *fn (self: objc.id, op: objc.SEL, value: *CAMetalLayer) void;
        const func: Fn = @ptrCast(&objc.objc_msgSend);
        func(@ptrCast(self), objc.sel_getUid("setLayer:"), value);
    }
};

// pub const IOSWindow = extern struct {
//     // view: ?*anyopaque, // either a CAMetalLayer or a UIView
// };
