const c = @import("c");
// const common = @import("common.zig");
// const CString = common.CString;

const ImGui_ImplVulkan_InitInfo = extern struct {
    instance: c.VkInstance = null,
    physical_device: c.VkPhysicalDevice = null,
    device: c.VkDevice = null,
    queue_family: u32 = 0,
    queue: c.VkQueue = null,
    descriptor_pool: c.VkDescriptorPool = null,
    render_pass: c.VkRenderPass = null,
    min_image_count: u32 = 0,
    image_count: u32 = 0,
    msaa_samples: c.VkSampleCountFlagBits = 0,

    pipeline_cache: c.VkPipelineCache = null,
    subpass: u32 = 0,

    use_dynamic_rendering: bool = false,
    pipeline_rendering_create_info: c.VkPipelineRenderingCreateInfoKHR = .{},

    allocator: ?*const c.VkAllocationCallbacks = null,
    checkVkResultFn: ?*const fn (c.VkResult) callconv(.C) void = null,
    min_allocation_size: c.VkDeviceSize = 0,
};

pub extern fn ImGui_ImplVulkan_Init(
    info: *const ImGui_ImplVulkan_InitInfo,
) callconv(.C) bool;
pub extern fn ImGui_ImplVulkan_Shutdown() callconv(.C) void;
pub extern fn ImGui_ImplVulkan_NewFrame() callconv(.C) void;
pub extern fn ImGui_ImplVulkan_RenderDrawData(
    draw_data: ?*const c.ImDrawData,
    command_buffer: c.VkCommandBuffer,
    pipeline: c.VkPipeline,
) callconv(.C) void;
pub extern fn ImGui_ImplVulkan_CreateFontsTexture() callconv(.C) bool;
pub extern fn ImGui_ImplVulkan_DestroyFontsTexture() callconv(.C) void;
pub extern fn ImGui_ImplVulkan_SetMinImageCount(
    min_image_count: u32,
) callconv(.C) void;
