const std = @import("std");
const builtin = @import("builtin");
const wgpu = @import("mach-gpu");
const glfw = @import("mach-glfw");

const window = @import("window.zig");
const Renderer = @import("renderer/renderer.zig").Renderer;
const WebGpuRenderer = @import("renderer/WebGpuRenderer.zig");

pub const GPUInterface = wgpu.dawn.Interface;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (!builtin.is_test) {
        try wgpu.Impl.init(allocator, .{});
    }

    const glfw_window = try window.init("gargoyle");
    defer window.deinit(&glfw_window);

    var renderer = try WebGpuRenderer.init(&glfw_window);
    defer renderer.deinit();

    while (!glfw_window.shouldClose()) {
        glfw.pollEvents();
        // todo game loop
        try renderer.draw();
    }
}

// ensure all imported files have their tests run
test {
    std.testing.refAllDecls(@This());
}
