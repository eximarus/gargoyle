const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");

// pub const Pool = struct {
//     device: c.VkDevice,
//
//     pub fn alloc(self: *Pool) void {
//         try vk.check(vk.allocateMemory(self.device, &c.VkMemoryAllocateInfo{
//             .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
//             .pNext = @ptrCast(&args.alloc_flags),
//             .allocationSize = req.size,
//             .memoryTypeIndex = try findMemoryType(
//                 args.gpu_mem_props,
//                 req.memoryTypeBits,
//                 args.buf_mem_props,
//             ),
//         }, null, &new_buffer.memory));
//     }
// };
