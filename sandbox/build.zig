const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .windows,
            .cpu_arch = .x86_64,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const gargoyle_dep = b.dependency("gargoyle", .{
        .target = target,
        .optimize = optimize,
    });

    for (gargoyle_dep.builder.install_tls.step.dependencies.items) |dep_step| {
        if (dep_step.cast(std.Build.Step.InstallArtifact)) |inst| {
            b.installArtifact(inst.artifact);
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
