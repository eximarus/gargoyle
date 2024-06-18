const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const common = @import("common.zig");
const CString = common.CString;

const PhysicalDevice = @This();
