const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const types = @import("types.zig");
const resources = @import("resources.zig");

pub const DescriptorSet = struct {
    layout: c.VkDescriptorSetLayout,
    size: c.VkDeviceSize,
    offset: c.VkDeviceSize,
};

pub const GraphicsShader = struct {
    vs: c.VkShaderEXT,
    fs: c.VkShaderEXT,
    pipeline_layout: c.VkPipelineLayout,
    descriptor_set: DescriptorSet,

    pub inline fn bind(self: GraphicsShader, cmd: c.VkCommandBuffer) void {
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
        vk.destroyDescriptorSetLayout(device, self.descriptor_set_layout, null);
        vk.destroyPipelineLayout(device, self.pipeline_layout, null);
    }
};

pub fn create(
    comptime path: []const u8,
    arena: std.mem.Allocator,
    device: c.VkDevice,
    descriptorBufferOffsetAlignment: c.VkDeviceSize,
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

    var descriptor_layout: c.VkDescriptorSetLayout = undefined;
    try vk.check(vk.createDescriptorSetLayout(
        device,
        &c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .flags = c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT,
            .bindingCount = 1,
            .pBindings = &c.VkDescriptorSetLayoutBinding{
                .binding = 0,
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            },
        },
        null,
        &descriptor_layout,
    ));

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
                .setLayoutCount = 1,
                .pSetLayouts = &descriptor_layout,
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
                .setLayoutCount = 1,
                .pSetLayouts = &descriptor_layout,
            },
        },
        null,
        &shaders,
    ));

    var layout: c.VkPipelineLayout = undefined;
    try vk.check(vk.createPipelineLayout(device, &c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &pc_range,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_layout,
    }, null, &layout));

    var descriptor_size: c.VkDeviceSize = undefined;
    vk.getDescriptorSetLayoutSizeEXT(
        device,
        descriptor_layout,
        &descriptor_size,
    );

    var descriptor_offset: c.VkDeviceSize = undefined;
    vk.getDescriptorSetLayoutBindingOffsetEXT(device, descriptor_layout, 0, &descriptor_offset);

    return GraphicsShader{
        .vs = shaders[0],
        .fs = shaders[1],
        .pipeline_layout = layout,
        .descriptor_set = DescriptorSet{
            .layout = descriptor_layout,
            .size = alignedSize(descriptor_size, descriptorBufferOffsetAlignment),
            .offset = descriptor_offset,
        },
    };
}

inline fn alignedSize(value: c.VkDeviceSize, alignment: c.VkDeviceSize) c.VkDeviceSize {
    return (value + alignment - 1) & ~(alignment - 1);
}

pub inline fn createDescriptorBuffer(
    device: c.VkDevice,
    gpu_mem_props: c.VkPhysicalDeviceMemoryProperties,
    descriptor_set: DescriptorSet,
) !resources.Buffer {
    return resources.createBuffer(
        device,
        gpu_mem_props,
        descriptor_set.size,
        c.VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT |
            c.VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT |
            c.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,

        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
            c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        // c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );
}
