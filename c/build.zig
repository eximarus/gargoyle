const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("c", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("root.zig"),
    });

    try linkVulkan(b, mod);
    linkVma(b, mod);
    linkSdl(b, mod);
    linkStb(b, mod);
    linkImgui(b, mod);
    linkCgltf(b, mod);
}

fn linkSdl(b: *std.Build, mod: *std.Build.Module) void {
    mod.link_libc = true;
    if (mod.resolved_target.?.result.os.tag == .windows) {
        const dep = b.dependency("sdl_win32", .{});
        mod.addIncludePath(dep.path("include"));
        mod.addLibraryPath(dep.path("lib/x64"));
        mod.linkSystemLibrary("SDL2", .{ .use_pkg_config = .no });
    } else {
        mod.linkSystemLibrary("SDL2", .{});
    }
}

fn linkVulkan(b: *std.Build, obj: *std.Build.Module) !void {
    const target = obj.resolved_target.?;
    const dep = b.dependency("volk", .{});

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    try flags.append("-std=c89");
    if (target.result.isAndroid()) {
        try flags.append("-DVK_USE_PLATFORM_ANDROID_KHR=");
    } else {
        switch (target.result.os.tag) {
            .ios => try flags.append("-DVK_USE_PLATFORM_IOS_MVK="),
            .macos => try flags.append("-DVK_USE_PLATFORM_MACOS_MVK="),
            .windows => try flags.append("-DVK_USE_PLATFORM_WIN32_KHR="),
            .linux => {
                try flags.append("-DVK_USE_PLATFORM_XLIB_KHR=");
                try flags.append("-DVK_USE_PLATFORM_WAYLAND_KHR=");
                try flags.append("-DVK_USE_PLATFORM_MIR_KHR=");
            },
            else => @panic("target not supported!"),
        }
    }

    obj.addIncludePath(dep.path(""));
    obj.addCSourceFile(.{
        .file = dep.path("volk.c"),
        .flags = flags.items,
    });

    includeVulkan(b, obj);
}

fn includeVulkan(b: *std.Build, obj: *std.Build.Module) void {
    const target = obj.resolved_target.?;
    if (target.result.os.tag != .windows) {
        return;
    }

    if (b.graph.env_map.get("VK_SDK_PATH")) |path| {
        obj.addIncludePath(.{
            .cwd_relative = b.pathJoin(&.{ path, "Include" }),
        });
    } else {
        // TODO fallback copy in project repo
        std.log.warn("VULKAN SDK NOT FOUND\n", .{});
    }
}

fn linkVma(b: *std.Build, obj: *std.Build.Module) void {
    const dep = b.dependency("vma", .{});
    obj.addIncludePath(dep.path("include"));
    obj.addCSourceFile(.{
        .file = b.path("vk_mem_alloc.cpp"),
        .flags = &.{""},
    });
    obj.link_libcpp = true;
}

fn linkStb(b: *std.Build, obj: *std.Build.Module) void {
    const dep = b.dependency("stb", .{});
    obj.addIncludePath(dep.path(""));
    obj.addCSourceFile(.{
        .file = b.path("stb_image.c"),
        .flags = &.{
            "-std=c89",
            "-msse2",
        },
    });
}

fn linkCgltf(b: *std.Build, obj: *std.Build.Module) void {
    const dep = b.dependency("cgltf", .{});
    obj.addIncludePath(dep.path(""));
    obj.addCSourceFile(.{
        .file = b.path("cgltf.c"),
        .flags = &.{
            "-std=c99",
        },
    });
}

fn linkImgui(b: *std.Build, obj: *std.Build.Module) void {
    const target = obj.resolved_target.?;
    const dep = b.dependency("imgui", .{});

    const lib = b.addStaticLibrary(.{
        .name = "cimgui",
        .target = target,
        .optimize = .ReleaseFast,
    });
    lib.linkLibCpp();

    linkSdl(b, &lib.root_module);

    lib.addIncludePath(dep.path("imgui"));
    lib.addIncludePath(dep.path(""));
    lib.addIncludePath(dep.path("imgui/backends"));
    lib.addIncludePath(dep.path(""));

    const volk_dep = b.dependency("volk", .{});
    const volk_dir = b.addInstallDirectory(.{
        .install_dir = .{ .header = {} },
        .install_subdir = "Volk",
        .source_dir = volk_dep.path(""),
        .include_extensions = &.{".h"},
    });

    const p = b.getInstallPath(.{ .header = {} }, "");
    lib.addIncludePath(.{ .path = p });

    includeVulkan(b, &lib.root_module);

    lib.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "cimgui.cpp",

            "imgui/imgui.cpp",
            "imgui/imgui_draw.cpp",
            "imgui/imgui_demo.cpp",
            "imgui/imgui_widgets.cpp",

            "imgui/imgui_tables.cpp",

            "imgui/backends/imgui_impl_sdl2.cpp",
            "imgui/backends/imgui_impl_vulkan.cpp",
        },
        .flags = &.{
            "-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1",
            "-DIMGUI_IMPL_VULKAN_USE_VOLK=",
            if (target.result.os.tag == .windows)
                "-DIMGUI_IMPL_API=extern \"C\" __declspec(dllexport)"
            else
                "-DIMGUI_IMPL_API=extern \"C\" ",
        },
    });

    lib.step.dependOn(&volk_dir.step);

    obj.linkLibrary(lib);
    obj.addCMacro("CIMGUI_USE_VULKAN", "");
    obj.addCMacro("CIMGUI_USE_SDL2", "");
    obj.addIncludePath(dep.path(""));
    obj.addIncludePath(dep.path("generator/output"));
}
