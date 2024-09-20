const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    _ = b;
    // const optimize = b.standardOptimizeOption(.{});

    // const exe = buildWin32(b, .{
    //     .optimize = optimize,
    // });

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

pub const Win32Options = struct {
    name: []const u8,
    app_mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode = .Debug,
};

pub fn buildWin32(
    parent: *std.Build,
    gargoyle_dep: *std.Build.Dependency,
    options: Win32Options,
) !void {
    var b = gargoyle_dep.builder;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    });

    const c_mod = b.addModule("c", .{
        .optimize = options.optimize,
        .target = target,
        .root_source_file = b.path("src/c.zig"),
        .link_libc = true,
    });
    c_mod.addCMacro("VK_USE_PLATFORM_WIN32_KHR", "");

    var vulkan_dep = b.dependency("vulkan", .{});
    c_mod.addIncludePath(vulkan_dep.path("include"));

    const gargoyle_mod = b.addModule("gargoyle", .{
        .optimize = options.optimize,
        .target = target,
        .root_source_file = b.path("src/engine/module.zig"),
    });
    gargoyle_mod.addImport("c", c_mod);

    addGlslShader(gargoyle_mod, b.path("shaders/glsl/colored_triangle.vert"));
    addGlslShader(gargoyle_mod, b.path("shaders/glsl/colored_triangle.frag"));

    gargoyle_mod.addAnonymousImport("platform", .{
        .target = target,
        .optimize = options.optimize,
        .root_source_file = b.path("src/platform/win32/root.zig"),
        .imports = &.{.{ .name = "c", .module = c_mod }},
    });

    options.app_mod.addImport("gargoyle", gargoyle_mod);

    const lib = b.addSharedLibrary(.{
        .name = "gargoyle",
        .target = target,
        .optimize = options.optimize,
        .root_source_file = b.path("src/engine/root.zig"),
    });
    lib.root_module.addImport("gargoyle", gargoyle_mod);
    lib.root_module.addImport("app", options.app_mod);

    const exe = b.addExecutable(.{
        .name = options.name,
        .root_source_file = b.path("src/platform/win32/main.zig"),
        .target = target,
        .optimize = options.optimize,
    });
    exe.root_module.addImport("c", c_mod);

    const install_options = std.Build.Step.InstallArtifact.Options{
        .dest_dir = .{ .override = .{ .custom = "win32" } },
    };

    const lib_output = parent.addInstallArtifact(lib, install_options);
    parent.getInstallStep().dependOn(&lib_output.step);

    const exe_output = parent.addInstallArtifact(exe, install_options);
    parent.getInstallStep().dependOn(&exe_output.step);
}

pub fn addGlslShader(
    obj: *std.Build.Module,
    file: std.Build.LazyPath,
) void {
    var b = obj.owner;
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

// fn getVkPlatformDefine() []const u8 {
//     return if (builtin.abi == .android)
//         "VK_USE_PLATFORM_ANDROID_KHR"
//     else switch (builtin.os.tag) {
//         .ios => "VK_USE_PLATFORM_IOS_MVK",
//         .macos => "VK_USE_PLATFORM_MACOS_MVK",
//         .windows => "VK_USE_PLATFORM_WIN32_KHR",
//         .linux => "VK_USE_PLATFORM_WAYLAND_KHR",
//         else => @compileError("platform not supported."),
//     };
// }
