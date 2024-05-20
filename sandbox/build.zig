const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const gargoyle_dep = b.dependency("gargoyle", .{
        .target = target,
        .optimize = optimize,
        .app_name = @as([]const u8, "sandbox"),
        .app_root = @as([]const u8, b.pathFromRoot("src/root.zig")),
    });

    const run_step = b.step("run", "Run the application");
    for (gargoyle_dep.builder.install_tls.step.dependencies.items) |dep_step| {
        if (dep_step.cast(std.Build.Step.InstallArtifact)) |inst| {
            inst.dest_dir = .{ .prefix = {} };
            b.installArtifact(inst.artifact);
            if (inst.artifact.kind == .exe) {
                const run_exe = b.addRunArtifact(inst.artifact);
                run_step.dependOn(&run_exe.step);
            }
            // } else if (dep_step.cast(std.Build.Step.InstallFile)) |inst| {
            //     b.installFile(inst.source.getDisplayName(), inst.dest_rel_path);
        }
    }

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
