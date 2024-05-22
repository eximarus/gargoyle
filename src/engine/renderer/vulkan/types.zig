const c = @import("../../c.zig");
const vk = @import("vulkan.zig");
const vma = @import("vma.zig");

pub const AllocatedImage = struct {
    image: vk.Image,
    image_view: vk.ImageView,
    allocation: vma.Allocation,
    image_extent: c.VkExtent3D,
    image_format: c.VkFormat,
};

pub const AllocatedBuffer = struct {
    buffer: vk.Buffer,
    allocation: vma.Allocation,
    info: c.VmaAllocationInfo,
};
