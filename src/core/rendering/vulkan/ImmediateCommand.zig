const std = @import("std");
const c = @import("c");

const vk = @import("vulkan.zig");
const ImmediateCommand = @This();

device: c.VkDevice,
fence: c.VkFence,
cmd: c.VkCommandBuffer,
queue: c.VkQueue,

pub fn submit(self: ImmediateCommand, ctx: anytype) !void {
    try vk.check(vk.resetFences(self.device, 1, &self.fence));
    try vk.check(vk.resetCommandBuffer(self.cmd, 0));

    try vk.check(vk.beginCommandBuffer(self.cmd, &c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    }));

    ctx.submit(self.cmd);

    try vk.check(vk.endCommandBuffer(self.cmd));

    const submit_info = c.VkSubmitInfo2{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO_2,
        .commandBufferInfoCount = 1,
        .pCommandBufferInfos = &c.VkCommandBufferSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
            .commandBuffer = self.cmd,
        },
    };

    try vk.check(vk.queueSubmit2(self.queue, 1, &submit_info, self.fence));
    try vk.check(vk.waitForFences(self.device, 1, &self.fence, c.VK_TRUE, 9999999999));
}
