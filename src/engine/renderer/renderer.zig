const config = @import("config");

pub const Renderer = switch (config.graphics_api) {
    .vulkan => @import("vulkan/VulkanRenderer.zig"),
};
