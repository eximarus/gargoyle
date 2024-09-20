const std = @import("std");
const gargoyle = @import("gargoyle");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("app", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
    });

    const gargoyle_dep = b.dependency("gargoyle", .{});
    try gargoyle.buildWin32(b, gargoyle_dep, .{
        .name = "sandbox",
        .optimize = optimize,
        .app_mod = mod,
    });

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
