const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");

// TODO create 1 pool per memory type
// easiest solution to avoid fragmentation is
// to do page allocation and have each resource use one or more pages
// even if the page is larger that what is necessary

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
//

// 128MB jumps per pool
pub const BufferPool = struct {
    fn createBuffer(self: BufferPool) void {
        _ = self;
    }
};
