const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cDefine("VK_NO_PROTOTYPES", "");
    @cInclude("vulkan/vulkan.h");
    // @cInclude("fbx.h");
});
