const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const app_name = b.option([]const u8, "app_name", "the name of the app being built") orelse "gargoyle_app";
    const app_ver = b.option([]const u8, "app_ver", "the version of the app being built") orelse "0.0.0";

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .cpu_features_add = std.Target.x86.featureSet(&.{ .avx2, .fma }),
    });

    const optimize = b.standardOptimizeOption(.{});
    const vulkan_dep = b.dependency("vulkan", .{});

    const c_mod = b.addModule("c", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/c.zig"),
        .link_libc = true,
        .link_libcpp = true,
    });
    c_mod.addIncludePath(vulkan_dep.path("include"));

    // const fbx_sdk_dir = b.graph.env_map.get("FBX_SDK_DIR") orelse return error.FbxSdkNotFound;
    //
    // const fbx_lib = b.addStaticLibrary(.{
    //     .name = "fbx-loader",
    //     .target = target,
    //     .optimize = optimize,
    // });
    // fbx_lib.linkLibCpp();
    // fbx_lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ fbx_sdk_dir, "lib", "x64", "release" }) });
    // fbx_lib.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ fbx_sdk_dir, "include" }) });
    // fbx_lib.linkSystemLibrary("libfbxsdk");
    // fbx_lib.addIncludePath(b.path("src/core/loading/fbx"));
    // fbx_lib.addCSourceFile(.{
    //     .file = b.path("src/core/loading/fbx/fbx.cpp"),
    //     .flags = &.{"-std=c++17"},
    // });
    //
    // c_mod.linkLibrary(fbx_lib);
    // c_mod.addIncludePath(b.path("src/core/loading/fbx"));
    // c_mod.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ fbx_sdk_dir, "lib", "x64", "release" }) });

    const rt_types = b.addModule("rt_types", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/runtime/types.zig"),
    });

    const rt_mod = b.addModule("runtime", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/runtime/rt.zig"),
    });

    const platform_mod = b.addModule("platform", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/platform/win32/root.zig"),
        .imports = &.{
            .{ .name = "c", .module = c_mod },
            .{ .name = "runtime", .module = rt_mod },
        },
    });

    const gargoyle_mod = b.addModule("gargoyle", .{
        .optimize = optimize,
        .root_source_file = b.path("src/core/root.zig"),
        .imports = &.{
            .{ .name = "c", .module = c_mod },
            .{ .name = "platform", .module = platform_mod },
            .{ .name = "rt_types", .module = rt_types },
        },
    });

    const options = b.addOptions();
    options.addOption([]const u8, "app_name", app_name);
    options.addOption([]const u8, "app_ver", app_ver);
    gargoyle_mod.addOptions("config", options);

    const lib = b.addSharedLibrary(.{
        .name = "gargoyle",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/runtime/entry.zig"),
    });
    lib.root_module.addImport("gargoyle", gargoyle_mod);

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = app_name,
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/platform/win32/main.zig"),
    });
    exe.root_module.addImport("c", c_mod);
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
}

pub const ShaderOptions = struct {
    name: []const u8,
    file: std.Build.LazyPath,
};

pub fn addShader(
    b: *std.Build,
    options: ShaderOptions,
) void {
    const cmd = b.addSystemCommand(&.{
        "slangc",
        "-profile",
        "sm_6_6+spirv_1_6",
        "-target",
        "spirv",
        "-emit-spirv-directly",
        "-fvk-use-entrypoint-name",
        "-fvk-use-gl-layout",
        "-matrix-layout-column-major",
        "-O3",
        "-o",
    });
    const out_file = cmd.addOutputFileArg(
        b.fmt("{s}.spv", .{options.name}),
    );
    cmd.addFileArg(options.file);

    const f = b.addInstallFileWithDir(
        out_file,
        .{ .custom = "win32" },
        b.fmt("assets/shaders/{s}.spv", .{options.name}),
    );
    b.getInstallStep().dependOn(&f.step);
}

pub const AssetOptions = struct {
    name: []const u8,
    file: std.Build.LazyPath,
};

pub fn addAsset(
    b: *std.Build,
    options: AssetOptions,
) void {
    const f = b.addInstallFileWithDir(
        options.file,
        .{ .custom = "win32" },
        b.fmt("assets/{s}", .{options.name}),
    );
    b.getInstallStep().dependOn(&f.step);
}

pub const BuildOptions = struct {
    app_name: []const u8,
    app_mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode = .Debug,
    app_ver: ?std.SemanticVersion = null,
};

pub fn buildWin32(
    b: *std.Build,
    options: BuildOptions,
) !void {
    const ver = if (options.app_ver) |v| std.fmt.allocPrint(b.allocator, "{}", .{v}) catch @panic("ah") else "0.0.0";

    const dep = b.dependencyFromBuildZig(@This(), .{
        .app_name = options.app_name,
        .app_ver = ver,
        .optimize = options.optimize,
    });

    const gargoyle_mod = dep.module("gargoyle");
    gargoyle_mod.addImport("app", options.app_mod);
    options.app_mod.addImport("gargoyle", gargoyle_mod);

    const install_options = std.Build.Step.InstallArtifact.Options{
        .dest_dir = .{ .override = .{ .custom = "win32" } },
    };

    addShader(b, .{
        .name = "default",
        .file = dep.path("shaders/default.slang"),
    });

    const lib = dep.artifact("gargoyle");
    const lib_output = b.addInstallArtifact(lib, install_options);
    b.getInstallStep().dependOn(&lib_output.step);

    const exe = dep.artifact(options.app_name);
    const exe_output = b.addInstallArtifact(exe, install_options);
    b.getInstallStep().dependOn(&exe_output.step);
}
