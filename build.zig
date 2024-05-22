const std = @import("std");
const builtin = @import("builtin");

pub const GraphicsApi = enum {
    vulkan,
    // direct3d,
    // metal,
    // wgpu,
    //
    // opengl,
    // opengl_es,
    // webgl,
};

pub fn build(b: *std.Build) !void {
    const graphics_api = b.option(
        GraphicsApi,
        "graphics_api",
        "Which graphics api should be used for the render backend?",
    ) orelse .vulkan;

    const app_root = b.option(
        []const u8,
        "app_root",
        "Root source file for your app.",
    ) orelse "./sandbox/src/root.zig"; // @panic("app_root argument is required");

    const app_name = b.option(
        []const u8,
        "app_name",
        "What is the name of your app?",
    ) orelse "sandbox"; // @panic("app_name argument is required");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gargoyle_mod = b.addModule("gargoyle", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/engine/root.zig"),
    });

    const conf = b.addOptions();
    conf.addOption(
        GraphicsApi,
        "graphics_api",
        graphics_api,
    );
    conf.addOption(
        []const u8,
        "app_name",
        app_name,
    );
    gargoyle_mod.addOptions("config", conf);
    addGlslShader(b, gargoyle_mod, b.path("shaders/glsl/gradient.comp"));
    addGlslShader(b, gargoyle_mod, b.path("shaders/glsl/sky.comp"));
    addGlslShader(b, gargoyle_mod, b.path("shaders/glsl/colored_triangle.vert"));
    addGlslShader(b, gargoyle_mod, b.path("shaders/glsl/colored_triangle.frag"));

    try linkVulkan(b, gargoyle_mod);
    linkVma(b, gargoyle_mod);
    linkSdl(b, gargoyle_mod);
    linkWin32(b, gargoyle_mod);
    linkStb(b, gargoyle_mod);
    linkImgui(b, gargoyle_mod);
    linkBox2d(b, gargoyle_mod);

    const app_lib = b.addSharedLibrary(.{
        .name = app_name,
        .root_source_file = .{ .path = "src/app/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    app_lib.root_module.addImport("gargoyle", gargoyle_mod);
    app_lib.root_module.addAnonymousImport("app_root", .{
        .root_source_file = .{ .path = app_root },
        .imports = &.{
            .{
                .name = "gargoyle",
                .module = gargoyle_mod,
            },
        },
    });
    app_lib.linkLibC();

    b.getInstallStep().dependOn(&b.addInstallArtifact(
        app_lib,
        .{ .dest_dir = .{ .override = .{ .custom = "Publish" } } },
    ).step);

    const exe = b.addExecutable(.{
        .name = app_name,
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("gargoyle", gargoyle_mod);

    const app_conf = b.addOptions();
    app_conf.addOption([]const u8, "app_lib_file", app_lib.out_filename);
    exe.root_module.addOptions("config", app_conf);

    exe.want_lto = false; // TODO zig bug

    b.getInstallStep().dependOn(&b.addInstallArtifact(
        exe,
        .{ .dest_dir = .{ .override = .{ .custom = "Publish" } } },
    ).step);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    const exe_unit_tests = b.addTest(.{
        .name = "test",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("gargoyle", gargoyle_mod);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

pub fn addGlslShader(
    b: *std.Build,
    obj: *std.Build.Module,
    file: std.Build.LazyPath,
) void {
    const cmd = b.addSystemCommand(&.{ "glslangValidator", "-V", "-o" });
    const out_file = cmd.addOutputFileArg(
        b.fmt("{s}.spv", .{file.getDisplayName()}),
    );
    cmd.addFileArg(file);

    for (obj.depending_steps.keys()) |comp| {
        comp.step.dependOn(&cmd.step);
    }

    obj.addAnonymousImport(file.getDisplayName(), .{
        .root_source_file = out_file,
    });
}

fn linkWin32(b: *std.Build, obj: *std.Build.Module) void {
    const tag = obj.resolved_target.?.result.os.tag;
    if (tag != .windows) {
        return;
    }

    const win32_dep = b.dependency("zigwin32", .{});
    const win32_module = win32_dep.module("zigwin32");
    obj.addImport("zigwin32", win32_module);
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
        .file = b.path("src/engine/vendor/vk_mem_alloc.cpp"),
        .flags = &.{""},
    });
    obj.link_libcpp = true;
}

fn linkStb(b: *std.Build, obj: *std.Build.Module) void {
    const dep = b.dependency("stb", .{});
    obj.addIncludePath(dep.path(""));
    obj.addCSourceFile(.{
        .file = b.path("src/engine/vendor/stb_image.c"),
        .flags = &.{
            "-std=c89",
            "-msse2",
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

// TODO custom physics
fn linkBox2d(
    b: *std.Build,
    obj: *std.Build.Module,
) void {
    const target = obj.resolved_target.?;
    const dep = b.dependency("box2d", .{
        .target = target,
        .optimize = .ReleaseFast,
    });

    const lib = b.addStaticLibrary(.{
        .name = "box2d",
        .target = target,
        .optimize = .ReleaseFast,
    });
    lib.linkLibC();

    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("extern/simde"));

    lib.addCSourceFiles(.{
        .root = dep.path(""),
        .flags = &.{
            "-std=c17",
            "-mavx2",
        },
        .files = &.{
            "src/aabb.c",
            "src/aabb.h",
            "src/allocate.c",
            "src/allocate.h",
            "src/array.c",
            "src/array.h",
            "src/bitset.c",
            "src/bitset.h",
            // "src/bitset.inl",
            "src/block_allocator.c",
            "src/block_allocator.h",
            "src/body.c",
            "src/body.h",
            "src/broad_phase.c",
            "src/broad_phase.h",
            "src/constraint_graph.c",
            "src/constraint_graph.h",
            "src/contact.c",
            "src/contact.h",
            "src/contact_solver.c",
            "src/contact_solver.h",
            "src/core.c",
            "src/core.h",
            "src/distance.c",
            "src/distance_joint.c",
            "src/dynamic_tree.c",
            "src/geometry.c",
            "src/hull.c",
            "src/implementation.c",
            "src/island.c",
            "src/island.h",
            "src/joint.c",
            "src/joint.h",
            "src/manifold.c",
            "src/math.c",
            "src/motor_joint.c",
            "src/mouse_joint.c",
            "src/polygon_shape.h",
            "src/pool.c",
            "src/pool.h",
            "src/prismatic_joint.c",
            "src/revolute_joint.c",
            "src/shape.c",
            "src/shape.h",
            "src/solver.c",
            "src/solver.h",
            "src/stack_allocator.c",
            "src/stack_allocator.h",
            "src/table.c",
            "src/table.h",
            "src/timer.c",
            "src/types.c",
            // user_constants.h.in
            "src/weld_joint.c",
            "src/wheel_joint.c",
            "src/world.c",
            "src/world.h",

            "include/box2d/api.h",
            "include/box2d/box2d.h",
            "include/box2d/callbacks.h",
            "include/box2d/color.h",
            "include/box2d/constants.h",
            // "include/box2d/debug_draw.h",
            "include/box2d/distance.h",
            "include/box2d/dynamic_tree.h",
            "include/box2d/event_types.h",
            "include/box2d/geometry.h",
            "include/box2d/hull.h",
            "include/box2d/id.h",
            "include/box2d/joint_types.h",
            "include/box2d/manifold.h",
            "include/box2d/math.h",
            // "include/box2d/math_cpp.h",
            "include/box2d/math_types.h",
            "include/box2d/timer.h",
            "include/box2d/types.h",
        },
    });

    // link_target.step.dependOn(b.addInstallArtifact(lib, .{}));
    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("src"));
    lib.linkLibrary(lib);
}
