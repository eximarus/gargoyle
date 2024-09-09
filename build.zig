const std = @import("std");
const builtin = @import("builtin");

pub const GraphicsApi = enum {
    vulkan,
    // opengl,
    // opengl_es,
    //
    // d3d12,
    // d3d11,
    //
    // metal,
    //
    // wgpu,
    // webgl,
    //
    // gnm
};

pub fn build(b: *std.Build) !void {
    const graphics_api = b.option(
        GraphicsApi,
        "graphics_api",
        "Which graphics api should be used for the render backend?",
    ) orelse .vulkan;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gargoyle_mod = b.addModule("gargoyle", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/engine/root.zig"),
    });

    linkSdl(b, gargoyle_mod);
    linkImgui(b, gargoyle_mod);
    linkCgltf(b, gargoyle_mod);

    const conf = b.addOptions();
    conf.addOption(
        GraphicsApi,
        "graphics_api",
        graphics_api,
    );
    gargoyle_mod.addOptions("config", conf);
    addGlslShader(b, gargoyle_mod, b.path("shaders/glsl/colored_triangle.vert"));
    addGlslShader(b, gargoyle_mod, b.path("shaders/glsl/colored_triangle.frag"));

    const app_lib = b.addSharedLibrary(.{
        .name = "sandbox",
        .root_source_file = b.path("src/app/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    app_lib.root_module.addImport("gargoyle", gargoyle_mod);
    app_lib.root_module.addAnonymousImport("app_root", .{
        .root_source_file = b.path("sandbox/src/root.zig"),
        .imports = &.{
            .{
                .name = "gargoyle",
                .module = gargoyle_mod,
            },
        },
    });
    app_lib.linkLibC();

    b.installArtifact(app_lib);

    const exe = b.addExecutable(.{
        .name = "ggeSandbox",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("gargoyle", gargoyle_mod);

    const app_conf = b.addOptions();
    app_conf.addOption([]const u8, "app_lib_file", app_lib.out_filename);
    exe.root_module.addOptions("config", app_conf);

    exe.want_lto = false; // TODO zig bug

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    const exe_unit_tests = b.addTest(.{
        .name = "test",
        .root_source_file = b.path("src/main.zig"),
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

fn linkCgltf(b: *std.Build, obj: *std.Build.Module) void {
    const dep = b.dependency("cgltf", .{});
    obj.addIncludePath(dep.path(""));
    obj.addCSourceFile(.{
        .file = b.path("src/cgltf.c"),
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
    lib.addIncludePath(dep.path("imgui/backends"));
    lib.addIncludePath(dep.path(""));

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
            "-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES=",
            if (target.result.os.tag == .windows)
                "-DIMGUI_IMPL_API=extern \"C\" __declspec(dllexport)"
            else
                "-DIMGUI_IMPL_API=extern \"C\" ",
        },
    });

    obj.linkLibrary(lib);
    obj.addCMacro("CIMGUI_USE_VULKAN", "");
    obj.addCMacro("CIMGUI_USE_SDL2", "");
    obj.addIncludePath(dep.path(""));
    obj.addIncludePath(dep.path("generator/output"));
}
