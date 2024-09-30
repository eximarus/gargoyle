const c = @import("c");

pub const vk_lib_name = "libvulkan.1.dylib";

const CAMetalLayer = opaque {
    fn layer() ?*CAMetalLayer {
        const Fn = *fn (self: c.id, op: c.SEL) ?*CAMetalLayer;
        const func: Fn = @ptrCast(&c.objc_msgSend);
        return func(
            c.objc_getClass("CAMetalLayer") orelse return null,
            c.sel_getUid("layer"),
        );
    }

    fn setContentsScale(self: *CAMetalLayer, scale_factor: f64) void {
        const Fn = *fn (self: c.id, op: c.SEL, scale_factor: f64) void;
        const func: Fn = @ptrCast(&c.objc_msgSend);
        func(@ptrCast(self), c.sel_getUid("setContentsScale:"), scale_factor);
    }
};

const NSWindow = opaque {
    fn contentView(self: *NSWindow) *NSView {
        const Fn = *fn (self: c.id, op: c.SEL) *NSView;
        const func: Fn = @ptrCast(&c.objc_msgSend);
        return func(@ptrCast(self), c.sel_getUid("contentView"));
    }

    fn backingScaleFactor(self: *NSWindow) f64 {
        const Fn = *fn (self: c.id, op: c.SEL) f64;
        const func: Fn = @ptrCast(&c.objc_msgSend);
        return func(@ptrCast(self), c.sel_getUid("backingScaleFactor"));
    }
};

const NSView = opaque {
    fn setWantsLayer(self: *NSView, value: bool) void {
        const Fn = *fn (self: c.id, op: c.SEL, value: bool) void;
        const func: Fn = @ptrCast(&c.objc_msgSend);
        func(@ptrCast(self), c.sel_getUid("setWantsLayer:"), value);
    }

    // technically accepts any CALayer
    fn setLayer(self: *NSView, value: *CAMetalLayer) void {
        const Fn = *fn (self: c.id, op: c.SEL, value: *CAMetalLayer) void;
        const func: Fn = @ptrCast(&c.objc_msgSend);
        func(@ptrCast(self), c.sel_getUid("setLayer:"), value);
    }
};

// pub const IOSWindow = extern struct {
//     // view: ?*anyopaque, // either a CAMetalLayer or a UIView
// };
