const c = @import("c");
const vk = @import("vulkan.zig");

pub const Texture2D = struct {
    extent: c.VkExtent2D,
    format: c.VkFormat,
    image: c.VkImage,
    view: c.VkImageView,
    sampler: c.VkSampler,
    memory: c.VkDeviceMemory,
};

pub const Buffer = struct {
    size: usize,
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
};

pub fn createBuffer(
    device: c.VkDevice,
    mem_props: c.VkPhysicalDeviceMemoryProperties,
    size: usize,
    usage: c.VkBufferUsageFlags,
    mem_flags: c.VkMemoryPropertyFlags,
) !Buffer {
    var new_buffer = Buffer{
        .size = size,
        .buffer = undefined,
        .memory = undefined,
    };

    try vk.check(vk.createBuffer(
        device,
        &c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = @intCast(size),
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        },
        null,
        &new_buffer.buffer,
    ));

    var req: c.VkMemoryRequirements = undefined;
    vk.getBufferMemoryRequirements(device, new_buffer.buffer, &req);

    try vk.check(vk.allocateMemory(device, &c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = if (usage & c.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT != 0)
            &c.VkMemoryAllocateFlagsInfo{
                .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO,
                .flags = c.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT,
            }
        else
            null,
        .allocationSize = req.size,
        .memoryTypeIndex = try findMemoryType(
            mem_props,
            req.memoryTypeBits,
            mem_flags,
        ),
    }, null, &new_buffer.memory));

    try vk.check(vk.bindBufferMemory(device, new_buffer.buffer, new_buffer.memory, 0));
    return new_buffer;
}

pub const Image = struct {
    extent: c.VkExtent3D,
    format: c.VkFormat,
    image: c.VkImage,
    memory: c.VkDeviceMemory,
    view: c.VkImageView,
};

// todo support creating many at once
pub fn createImage(
    device: c.VkDevice,
    format: c.VkFormat,
    extent: c.VkExtent3D,
    usage_flags: c.VkImageUsageFlags,
    aspect_flags: c.VkImageAspectFlags,
    gpu_mem_props: c.VkPhysicalDeviceMemoryProperties,
    image_mem_props: c.VkMemoryPropertyFlags,
) !Image {
    var new_image = Image{
        .format = format,
        .extent = extent,
        .image = undefined,
        .memory = undefined,
        .view = undefined,
    };

    try vk.check(vk.createImage(
        device,
        &c.VkImageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .imageType = c.VK_IMAGE_TYPE_2D,
            .format = format,
            .extent = extent,
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
            .tiling = c.VK_IMAGE_TILING_OPTIMAL,
            .usage = usage_flags,
        },
        null,
        &new_image.image,
    ));

    var req: c.VkMemoryRequirements = undefined;
    vk.getImageMemoryRequirements(device, new_image.image, &req);

    try vk.check(vk.allocateMemory(device, &c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = req.size,
        .memoryTypeIndex = try findMemoryType(
            gpu_mem_props,
            req.memoryTypeBits,
            image_mem_props,
        ),
    }, null, &new_image.memory));

    try vk.check(vk.bindImageMemory(device, new_image.image, new_image.memory, 0));

    try vk.check(vk.createImageView(
        device,
        &c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .image = new_image.image,
            .format = format,
            .subresourceRange = .{
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
                .aspectMask = aspect_flags,
            },
        },
        null,
        &new_image.view,
    ));

    return new_image;
}

fn findMemoryType(
    props: c.VkPhysicalDeviceMemoryProperties,
    type_filter: u32,
    properties: c.VkMemoryPropertyFlags,
) !u32 {
    for (0..props.memoryTypeCount) |i| {
        if (type_filter & (@as(u32, 1) << @intCast(i)) != 0 and (props.memoryTypes[i].propertyFlags & properties) == properties) {
            return @intCast(i);
        }
    }

    return error.SuitableMemoryTypeNotFound;
}
