const builtin = @import("builtin");

pub usingnamespace @cImport({
    if (builtin.abi == .android) {
        @cDefine("VK_USE_PLATFORM_ANDROID_KHR", {});
    } else switch (builtin.os.tag) {
        .windows => {
            @cInclude("windows.h");
            @cDefine("VK_USE_PLATFORM_WIN32_KHR", {});
        },
        .linux => {
            @cInclude("xcb/xcb.h");
            @cDefine("VK_USE_PLATFORM_XCB_KHR", {});
        },
        .ios => {
            @cInclude("objc/message.h");
            @cDefine("VK_USE_PLATFORM_IOS_MVK", {});
        },
        .macos => {
            @cInclude("objc/message.h");
            @cDefine("VK_USE_PLATFORM_MACOS_MVK", {});
        },
        else => @compileError("platform not supported"),
    }
    @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("vulkan/vulkan.h");
    // @cInclude("fbx.h");
});

pub const String = [*:0]const u8;
