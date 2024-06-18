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

    const c_dep = b.dependency("c", .{
        .target = target,
        .optimize = optimize,
    });
    const c_mod = c_dep.module("c");

    const gargoyle_mod = b.addModule("gargoyle", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/engine/root.zig"),
    });
    gargoyle_mod.addImport("c", c_mod);

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

    const triple = try target.result.zigTriple(b.allocator);

    b.getInstallStep().dependOn(&b.addInstallArtifact(
        app_lib,
        .{ .dest_dir = .{ .override = .{ .custom = triple } } },
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
        .{ .dest_dir = .{ .override = .{ .custom = triple } } },
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
