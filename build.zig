const std = @import("std");
const zmath = @import("zmath");
const gpu = @import("mach_gpu");

const GraphicsApi = enum {
    none,
    d3d12,
    metal,
    vulkan,
    opengl,
    opengl_es,
};

pub fn build(b: *std.Build) void {
    var graphics_api = b.option(GraphicsApi, "graphics-api", "Target Graphics Api") orelse .none;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zmath_pkg = zmath.package(b, target, optimize, .{
        .options = .{ .enable_cross_platform_determinism = true },
    });

    const lib = b.addStaticLibrary(.{
        .name = "gargoyle",
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "gargoyle",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    zmath_pkg.link(exe);

    const gpu_dep = b.dependency("mach_gpu", .{
        .target = target,
        .optimize = optimize,
    });

    gpu.link(gpu_dep.builder, exe, &exe.root_module, .{
        .gpu_dawn_options = .{
            .d3d12 = if (graphics_api == .none) null else graphics_api == .d3d12,
            .metal = if (graphics_api == .none) null else graphics_api == .metal,
            .vulkan = if (graphics_api == .none) null else graphics_api == .vulkan,
            .desktop_gl = if (graphics_api == .none) null else graphics_api == .opengl,
            .opengl_es = if (graphics_api == .none) null else graphics_api == .opengl_es,
        },
    }) catch unreachable;

    const tag = exe.rootModuleTarget().os.tag;
    if (graphics_api == .none) {
        if (tag == .windows) {
            graphics_api = .d3d12;
        } else if (tag.isDarwin()) {
            graphics_api = .metal;
        } else {
            graphics_api = .vulkan;
        }
    }

    const options = b.addOptions();
    options.addOption(@TypeOf(graphics_api), "graphics_api", graphics_api);
    exe.root_module.addOptions("config", options);

    exe.root_module.addImport("mach-glfw", b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    }).module("mach-glfw"));

    exe.root_module.addImport("mach-gpu", gpu_dep.module("mach-gpu"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    zmath_pkg.link(exe_unit_tests);

    gpu.link(gpu_dep.builder, exe_unit_tests, &exe_unit_tests.root_module, .{}) catch unreachable;

    exe_unit_tests.root_module.addImport("mach-glfw", b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    }).module("mach-glfw"));

    exe_unit_tests.root_module.addImport("mach-gpu", gpu_dep.module("mach-gpu"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
