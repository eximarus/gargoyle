const std = @import("std");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");

pub fn loadShaderModule(
    comptime path: []const u8,
    device: vk.Device,
) !vk.ShaderModule {
    // const shader_file align(@alignOf(u32)) = @embedFile(path).*;
    const shader_code = std.mem.bytesAsSlice(
        u32,
        @as([]align(@alignOf(u32)) const u8, @alignCast(@embedFile(path))),
        // &shader_file,
    );

    return device.createShaderModule(&.{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = @intCast(shader_code.len * @sizeOf(u32)),
        .pCode = @ptrCast(shader_code.ptr),
    }, null);
}
