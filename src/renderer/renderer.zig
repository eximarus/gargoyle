const math = @import("../math.zig");
const WebGpuRenderer = @import("WebGpuRenderer.zig");

pub const GraphicsApi = enum {
    none,

    opengl,
    d3d11,

    vulkan,
    d3d12,
    metal,

    wgpu,
};

pub const Renderer = union(enum) {
    wgpu: WebGpuRenderer,

    pub fn draw(self: *const Renderer) !void {
        return switch (self.*) {
            inline else => |case| case.draw(),
        };
    }
};
