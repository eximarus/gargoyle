const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const types = @import("types.zig");
const resources = @import("resources.zig");

pub const DescriptorSetLayout = struct {
    layout: c.VkDescriptorSetLayout,
    size: c.VkDeviceSize,
    offset: c.VkDeviceSize,
};

pub const Shader = struct {
    const Graphics = struct {
        vs: c.VkShaderEXT,
        fs: c.VkShaderEXT,
        descriptor_set_layouts: []DescriptorSetLayout,
        pipeline_layout: c.VkPipelineLayout,
    };

    const Compute = struct {
        shader: c.VkShaderEXT,
        pipeline_layout: c.VkPipelineLayout,
        // descriptor_set_layouts: []DescriptorSetLayout,
    };

    gfx: Graphics,
    comp: Compute,

    pub inline fn bind(self: Shader, cmd: c.VkCommandBuffer) void {
        const stage_count = 5;
        vk.cmdBindShadersEXT(
            cmd,
            stage_count,
            &[stage_count]c.VkShaderStageFlagBits{
                c.VK_SHADER_STAGE_VERTEX_BIT,
                c.VK_SHADER_STAGE_FRAGMENT_BIT,
                c.VK_SHADER_STAGE_COMPUTE_BIT,
                // when mesh shaders are enabled it is required,
                // to provide mesh and task stages even if they are not used
                c.VK_SHADER_STAGE_TASK_BIT_EXT,
                c.VK_SHADER_STAGE_MESH_BIT_EXT,
            },
            &[stage_count]c.VkShaderEXT{
                self.gfx.vs,
                self.gfx.fs,
                self.comp.shader,
                @ptrCast(c.VK_NULL_HANDLE),
                @ptrCast(c.VK_NULL_HANDLE),
            },
        );
    }

    // pub inline fn destroy(self: GraphicsShader, device: c.VkDevice) void {
    //     vk.destroyShaderEXT(device, self.vs, null);
    //     vk.destroyShaderEXT(device, self.fs, null);
    //     vk.destroyDescriptorSetLayout(device, self.descriptor_set_layout, null);
    //     vk.destroyPipelineLayout(device, self.pipeline_layout, null);
    // }
};

fn createBindlessDescriptorSetLayout(
    device: c.VkDevice,
    bindings: []c.VkDescriptorSetLayoutBinding,
) !c.VkDescriptorSetLayout {
    var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;
    try vk.check(vk.createDescriptorSetLayout(
        device,
        &c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = &c.VkDescriptorSetLayoutBindingFlagsCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
                .bindingCount = 1,
                .pBindingFlags = &c.VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT |
                    c.VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT |
                    c.VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT,
            },
            .flags =
            // TODO not sure if this is needed or even legal
            // c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT |
            c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT,
            .bindingCount = bindings.len,
            .pBindings = bindings.ptr,
        },
        null,
        &descriptor_set_layout,
    ));
    return descriptor_set_layout;
}

pub fn create(
    comptime path: []const u8,
    arena: std.mem.Allocator,
    device: c.VkDevice,
    descriptorBufferOffsetAlignment: c.VkDeviceSize,
    options: struct {
        vs_main: c.String = "vsMain",
        fs_main: c.String = "fsMain",
        comp_main: c.String = "compMain",
    },
) !Shader {
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

    var descriptor_set_layout = try createBindlessDescriptorSetLayout(
        device,
        &[_]c.VkDescriptorSetLayoutBinding{
            c.VkDescriptorSetLayoutBinding{
                .binding = 0,
                .descriptorCount = std.math.maxInt(u16),
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            },
        },
    );

    var vs_create_info = c.VkShaderCreateInfoEXT{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_CREATE_INFO_EXT,
        .flags = c.VK_SHADER_CREATE_LINK_STAGE_BIT_EXT,
        .codeType = c.VK_SHADER_CODE_TYPE_SPIRV_EXT,
        .codeSize = @intCast(size),
        .pCode = @ptrCast(shader_code.ptr),
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &pc_range,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
    };
    var fs_create_info = vs_create_info;

    vs_create_info.stage = c.VK_SHADER_STAGE_VERTEX_BIT;
    vs_create_info.nextStage = c.VK_SHADER_STAGE_FRAGMENT_BIT;
    vs_create_info.pName = options.vs_main;

    fs_create_info.stage = c.VK_SHADER_STAGE_FRAGMENT_BIT;
    fs_create_info.pName = options.fs_main;

    const shader_count = 2;
    var shaders: [shader_count]c.VkShaderEXT = undefined;
    try vk.check(vk.createShadersEXT(
        device,
        shader_count,
        &[shader_count]c.VkShaderCreateInfoEXT{
            vs_create_info,
            fs_create_info,
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
        .pSetLayouts = &descriptor_set_layout,
    }, null, &layout));

    var descriptor_set_layout_size: c.VkDeviceSize = undefined;
    vk.getDescriptorSetLayoutSizeEXT(
        device,
        descriptor_set_layout,
        &descriptor_set_layout_size,
    );

    var descriptor_set_layout_offset: c.VkDeviceSize = undefined;
    vk.getDescriptorSetLayoutBindingOffsetEXT(device, descriptor_set_layout, 0, &descriptor_set_layout_offset);

    return Shader{
        .vs = shaders[0],
        .fs = shaders[1],
        .gfx_pipeline_layout = layout,
        .descriptor_sets = &[_]DescriptorSetLayout{
            DescriptorSetLayout{
                .layout = descriptor_set_layout,
                .size = alignedSize(descriptor_set_layout_size, descriptorBufferOffsetAlignment),
                .offset = descriptor_set_layout_offset,
            },
        },
    };
}

inline fn alignedSize(value: c.VkDeviceSize, alignment: c.VkDeviceSize) c.VkDeviceSize {
    return (value + alignment - 1) & ~(alignment - 1);
}

pub inline fn createDescriptorBuffer(
    device: c.VkDevice,
    physical_device_mem_props: c.VkPhysicalDeviceMemoryProperties,
    descriptor_set: DescriptorSetLayout,
) !resources.Buffer {
    return resources.createBuffer(
        device,
        physical_device_mem_props,
        descriptor_set.size,
        c.VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT |
            c.VK_BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT |
            c.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,

        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
            c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        // c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );
}
