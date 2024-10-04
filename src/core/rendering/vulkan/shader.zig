const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const types = @import("types.zig");

pub const GraphicsShader = struct {
    vs: c.VkShaderEXT,
    fs: c.VkShaderEXT,
    layout: c.VkPipelineLayout,

    pub fn bind(self: GraphicsShader, cmd: c.VkCommandBuffer) void {
        vk.cmdBindShadersEXT(
            cmd,
            4,
            &[4]c.VkShaderStageFlagBits{
                c.VK_SHADER_STAGE_VERTEX_BIT,
                c.VK_SHADER_STAGE_FRAGMENT_BIT,
                // when mesh shaders are enabled it is required,
                // to provide mesh and task stages even if they are not used
                c.VK_SHADER_STAGE_TASK_BIT_EXT,
                c.VK_SHADER_STAGE_MESH_BIT_EXT,
            },
            &[4]c.VkShaderEXT{
                self.vs,
                self.fs,
                @ptrCast(c.VK_NULL_HANDLE),
                @ptrCast(c.VK_NULL_HANDLE),
            },
        );
    }

    pub inline fn destroy(self: GraphicsShader, device: c.VkDevice) void {
        vk.destroyShaderEXT(device, self.vs, null);
        vk.destroyShaderEXT(device, self.fs, null);
        vk.destroyPipelineLayout(device, self.layout, null);
    }
};

pub fn create(
    comptime path: []const u8,
    arena: std.mem.Allocator,
    device: c.VkDevice,
    options: struct {
        vs_main: c.String = "vsMain",
        fs_main: c.String = "fsMain",
    },
) !GraphicsShader {
    const f = try std.fs.cwd().openFile(path, .{});
    defer f.close();

    const size = try f.getEndPos();
    const buf = try arena.alloc(u8, size);

    _ = try f.readAll(buf);

    const shader_code = std.mem.bytesAsSlice(
        u32,
        @as([]align(@alignOf(u32)) const u8, @alignCast(buf)),
    );
    const pc_range = c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(types.PushConstants),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };

    var shaders: [2]c.VkShaderEXT = undefined;
    try vk.check(vk.createShadersEXT(
        device,
        2,
        &[2]c.VkShaderCreateInfoEXT{
            c.VkShaderCreateInfoEXT{
                .sType = c.VK_STRUCTURE_TYPE_SHADER_CREATE_INFO_EXT,
                .flags = c.VK_SHADER_CREATE_LINK_STAGE_BIT_EXT,
                .codeType = c.VK_SHADER_CODE_TYPE_SPIRV_EXT,
                .codeSize = @intCast(size),
                .pCode = @ptrCast(shader_code.ptr),
                .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                .nextStage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                .pName = options.vs_main,
                .pushConstantRangeCount = 1,
                .pPushConstantRanges = &pc_range,
            },
            c.VkShaderCreateInfoEXT{
                .sType = c.VK_STRUCTURE_TYPE_SHADER_CREATE_INFO_EXT,
                .flags = c.VK_SHADER_CREATE_LINK_STAGE_BIT_EXT,
                .codeType = c.VK_SHADER_CODE_TYPE_SPIRV_EXT,
                .codeSize = @intCast(size),
                .pCode = @ptrCast(shader_code.ptr),
                .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                .pName = options.fs_main,
                .pushConstantRangeCount = 1,
                .pPushConstantRanges = &pc_range,
            },
        },
        null,
        &shaders,
    ));

    var layout: c.VkPipelineLayout = undefined;
    try vk.check(vk.createPipelineLayout(device, &.{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &pc_range,
    }, null, &layout));

    return GraphicsShader{
        .vs = shaders[0],
        .fs = shaders[1],
        .layout = layout,
    };
}
