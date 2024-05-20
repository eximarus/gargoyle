const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "breakout",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const gargoyle = b.dependency("gargoyle", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("gargoyle", gargoyle.module("gargoyle_core"));
    // exe.linkLibrary(gargoyle.artifact("gargoyle_core"));

    b.installArtifact(exe);
}
