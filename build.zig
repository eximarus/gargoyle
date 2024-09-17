const std = @import("std");
const builtin = @import("builtin");

pub const GraphicsApi = enum {
    vulkan,
    // vulkan_sc
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
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gargoyle_mod = b.addModule("gargoyle", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/engine/root.zig"),
        .link_libc = true,
    });

    var vulkan_dep = b.dependency("vulkan", .{});
    gargoyle_mod.addIncludePath(vulkan_dep.path("include"));

    const conf = b.addOptions();
    conf.addOption(
        GraphicsApi,
        "graphics_api",
        .vulkan,
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

    b.installArtifact(exe);

    // const exe_unit_tests = b.addTest(.{
    //     .name = "test",
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // exe_unit_tests.root_module.addImport("gargoyle", gargoyle_mod);
    //
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);

    // const linux_step = b.step("linux", "Create an AppImage for linux");
    // const android_step = b.step("android", "Create an Apk for Android");
    // const windows_step = b.step("windows", "Create a Windows Installer File");
    // const ios_step = b.step("ios", "Create a ios app");
    // const mac_step = b.step("mac", "Create a macos app");
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
