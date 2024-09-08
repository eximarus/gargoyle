pub const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "");
    @cDefine("CIMGUI_USE_VULKAN", "");
    @cDefine("CIMGUI_USE_SDL2", "");
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
});

const vk = @import("vulkan.zig");

const ImGui_ImplVulkan_InitInfo = extern struct {
    instance: vk.c.VkInstance = null,
    physical_device: vk.c.VkPhysicalDevice = null,
    device: vk.c.VkDevice = null,
    queue_family: u32 = 0,
    queue: vk.c.VkQueue = null,
    descriptor_pool: vk.c.VkDescriptorPool = null,
    render_pass: vk.c.VkRenderPass = null,
    min_image_count: u32 = 0,
    image_count: u32 = 0,
    msaa_samples: vk.c.VkSampleCountFlagBits = 0,

    pipeline_cache: vk.c.VkPipelineCache = null,
    subpass: u32 = 0,

    use_dynamic_rendering: bool = false,
    pipeline_rendering_create_info: vk.c.VkPipelineRenderingCreateInfoKHR = .{},

    allocator: ?*const vk.c.VkAllocationCallbacks = null,
    checkVkResultFn: ?*const fn (vk.c.VkResult) callconv(.C) void = null,
    min_allocation_size: vk.c.VkDeviceSize = 0,
};

pub extern fn ImGui_ImplVulkan_Init(
    info: *const ImGui_ImplVulkan_InitInfo,
) callconv(.C) bool;
pub extern fn ImGui_ImplVulkan_Shutdown() callconv(.C) void;
pub extern fn ImGui_ImplVulkan_NewFrame() callconv(.C) void;
pub extern fn ImGui_ImplVulkan_RenderDrawData(
    draw_data: ?*const c.ImDrawData,
    command_buffer: vk.c.VkCommandBuffer,
    pipeline: vk.c.VkPipeline,
) callconv(.C) void;
pub extern fn ImGui_ImplVulkan_CreateFontsTexture() callconv(.C) bool;
pub extern fn ImGui_ImplVulkan_DestroyFontsTexture() callconv(.C) void;
pub extern fn ImGui_ImplVulkan_SetMinImageCount(
    min_image_count: u32,
) callconv(.C) void;
