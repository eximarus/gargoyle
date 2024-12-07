const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const platform = @import("platform");
const log = std.log.scoped(.vulkan);

pub const validation_layers: []const c.String = &.{
    "VK_LAYER_KHRONOS_validation",
};
pub const enable_validation_layers = builtin.mode == .Debug;

pub const max_bindless_resources: u32 = @intCast(std.math.maxInt(u16));

fn PFN(comptime T: type) type {
    return @typeInfo(T).Optional.child;
}

pub var vkGetInstanceProcAddr: PFN(c.PFN_vkGetInstanceProcAddr) = undefined;
fn getInstanceProcAddr(instance: c.VkInstance, comptime name: []const u8) void {
    @field(@This(), [_]u8{std.ascii.toLower(name[2])} ++ name[3..]) = @ptrCast(vkGetInstanceProcAddr(instance, @ptrCast(name)) orelse {
        log.debug("{s} not found", .{name});
        return;
    });
}

var vkGetDeviceProcAddr: PFN(c.PFN_vkGetDeviceProcAddr) = undefined;
fn getDeviceProcAddr(device: c.VkDevice, comptime name: []const u8) void {
    @field(@This(), [_]u8{std.ascii.toLower(name[2])} ++ name[3..]) = @ptrCast(vkGetDeviceProcAddr(device, @ptrCast(name)) orelse {
        log.debug("{s} not found", .{name});
        return;
    });
}

var initialized = false;
var vk_lib: std.DynLib = undefined;

pub fn init() void {
    std.debug.assert(!initialized);

    vk_lib = std.DynLib.open(platform.vk.lib_path) catch |err| {
        std.debug.panic("{}", .{err});
    };

    vkGetInstanceProcAddr = vk_lib.lookup(PFN(c.PFN_vkGetInstanceProcAddr), "vkGetInstanceProcAddr") orelse {
        std.debug.panic("vkGetInstanceProcAddr not found", .{});
    };

    loadGlobalFunctions();

    initialized = true;
}

pub inline fn Bool32(value: bool) c.VkBool32 {
    return if (value) c.VK_TRUE else c.VK_FALSE;
}

pub const Error = error{
    OutOfHostMemory,
    OutOfDeviceMemory,
    InitializationFailed,
    DeviceLost,
    MemoryMapFailed,
    LayerNotPresent,
    ExtensionNotPresent,
    FeatureNotPresent,
    IncompatibleDriver,
    TooManyObjects,
    FormatNotSupported,
    FragmentedPool,
    Unknown,
    OutOfPoolMemory,
    InvalidExternalHandle,
    Fragmentation,
    InvalidOpaqueCaptureAddress,
    SurfaceLostKHR,
    NativeWindowInUseKHR,
    OutOfDateKHR,
    IncompatibleDisplayKHR,
    ValidationFailedEXT,
    InvalidShaderNV,
    ImageUsageNotSupportedKHR,
    VideoPictureLayoutNotSupportedKHR,
    VideoProfileOperationNotSupportedKHR,
    VideoProfileFormatNotSupportedKHR,
    VideoProfileCodecNotSupportedKHR,
    VideoStdVersionNotSupportedKHR,
    InvalidDrmFormatModifierPlaneLayoutEXT,
    NotPermittedKHR,
    FullScreenExclusiveModeLostEXT,
    CompressionExhaustedEXT,
    IncompatibleShaderBinaryEXT,
};

pub const Result = Error!enum {
    Success,
    NotReady,
    Timeout,
    EventSet,
    EventReset,
    Incomplete,

    PipelineCompileRequired,
    SuboptimalKHR,
    ThreadIdleKHR,
    ThreadDoneKHR,
    OperationDeferredKHR,
    OperationNotDeferredKHR,
};

pub inline fn check(r: c.VkResult) !void {
    if (result(r)) |value| {
        if (value != .Success) {
            return error.Unsuccessful;
        }
    } else |err| return err;
}

pub inline fn result(r: c.VkResult) Result {
    return switch (r) {
        c.VK_SUCCESS => .Success,
        c.VK_NOT_READY => .NotReady,
        c.VK_TIMEOUT => .Timeout,
        c.VK_EVENT_SET => .EventSet,
        c.VK_EVENT_RESET => .EventReset,
        c.VK_INCOMPLETE => .Incomplete,
        c.VK_PIPELINE_COMPILE_REQUIRED => .PipelineCompileRequired,
        c.VK_SUBOPTIMAL_KHR => .SuboptimalKHR,
        c.VK_THREAD_IDLE_KHR => .ThreadIdleKHR,
        c.VK_THREAD_DONE_KHR => .ThreadDoneKHR,
        c.VK_OPERATION_DEFERRED_KHR => .OperationDeferredKHR,
        c.VK_OPERATION_NOT_DEFERRED_KHR => .OperationNotDeferredKHR,

        c.VK_ERROR_OUT_OF_HOST_MEMORY => Error.OutOfHostMemory,
        c.VK_ERROR_OUT_OF_DEVICE_MEMORY => Error.OutOfDeviceMemory,
        c.VK_ERROR_INITIALIZATION_FAILED => Error.InitializationFailed,
        c.VK_ERROR_DEVICE_LOST => Error.DeviceLost,
        c.VK_ERROR_MEMORY_MAP_FAILED => Error.MemoryMapFailed,
        c.VK_ERROR_LAYER_NOT_PRESENT => Error.LayerNotPresent,
        c.VK_ERROR_EXTENSION_NOT_PRESENT => Error.ExtensionNotPresent,
        c.VK_ERROR_FEATURE_NOT_PRESENT => Error.FeatureNotPresent,
        c.VK_ERROR_INCOMPATIBLE_DRIVER => Error.IncompatibleDriver,
        c.VK_ERROR_TOO_MANY_OBJECTS => Error.TooManyObjects,
        c.VK_ERROR_FORMAT_NOT_SUPPORTED => Error.FormatNotSupported,
        c.VK_ERROR_FRAGMENTED_POOL => Error.FragmentedPool,
        c.VK_ERROR_UNKNOWN => Error.Unknown,
        c.VK_ERROR_OUT_OF_POOL_MEMORY => Error.OutOfPoolMemory,
        c.VK_ERROR_INVALID_EXTERNAL_HANDLE => Error.InvalidExternalHandle,
        c.VK_ERROR_FRAGMENTATION => Error.Fragmentation,
        c.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS => Error.InvalidOpaqueCaptureAddress,
        c.VK_ERROR_SURFACE_LOST_KHR => Error.SurfaceLostKHR,
        c.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR => Error.NativeWindowInUseKHR,
        c.VK_ERROR_OUT_OF_DATE_KHR => Error.OutOfDateKHR,
        c.VK_ERROR_INCOMPATIBLE_DISPLAY_KHR => Error.IncompatibleDisplayKHR,
        c.VK_ERROR_VALIDATION_FAILED_EXT => Error.ValidationFailedEXT,
        c.VK_ERROR_INVALID_SHADER_NV => Error.InvalidShaderNV,
        c.VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR => Error.ImageUsageNotSupportedKHR,
        c.VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR => Error.VideoPictureLayoutNotSupportedKHR,
        c.VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR => Error.VideoProfileOperationNotSupportedKHR,
        c.VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR => Error.VideoProfileFormatNotSupportedKHR,
        c.VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR => Error.VideoProfileCodecNotSupportedKHR,
        c.VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR => Error.VideoStdVersionNotSupportedKHR,
        c.VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT => Error.InvalidDrmFormatModifierPlaneLayoutEXT,
        c.VK_ERROR_NOT_PERMITTED_KHR => Error.NotPermittedKHR,
        c.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT => Error.FullScreenExclusiveModeLostEXT,
        c.VK_ERROR_COMPRESSION_EXHAUSTED_EXT => Error.CompressionExhaustedEXT,
        c.VK_ERROR_INCOMPATIBLE_SHADER_BINARY_EXT => Error.IncompatibleShaderBinaryEXT,
        else => Error.Unknown,
    };
}

//[[[cog
//  import cog
//  global_defs = [
//      'vkCreateInstance',
//      'vkEnumerateInstanceExtensionProperties',
//      'vkEnumerateInstanceLayerProperties',
//      'vkEnumerateInstanceVersion'
//  ]
//  instance_defs = [
//      'vkDestroyInstance',
//      'vkDestroySurfaceKHR',
//      'vkEnumeratePhysicalDevices',
//      'vkEnumerateDeviceExtensionProperties',
//      'vkGetPhysicalDeviceQueueFamilyProperties',
//      'vkGetPhysicalDeviceSurfaceSupportKHR',
//      'vkGetPhysicalDeviceProperties2',
//      'vkGetPhysicalDeviceFeatures2',
//      'vkGetPhysicalDeviceSurfaceCapabilitiesKHR',
//      'vkGetPhysicalDeviceSurfaceFormatsKHR',
//      'vkGetPhysicalDeviceSurfacePresentModesKHR',
//      'vkGetPhysicalDeviceMemoryProperties',
//      'vkCreateDevice',
//      'vkQueueSubmit2',
//      'vkQueueWaitIdle',
//      'vkQueueBindSparse',
//      'vkCreateDebugUtilsMessengerEXT',
//      'vkDestroyDebugUtilsMessengerEXT',
//      'vkQueuePresentKHR'
//  ]
//  device_defs = [
//      'vkGetDeviceQueue',
//      'vkCreateSwapchainKHR',
//      'vkDestroySwapchainKHR',
//      'vkCreateShaderModule',
//      'vkCreatePipelineLayout',
//      'vkDestroyShaderModule',
//      'vkDestroyPipelineLayout',
//      'vkCreateComputePipelines',
//      'vkCreateGraphicsPipelines',
//      'vkDestroyPipeline',
//      'vkCreateImageView',
//      'vkDestroyImageView',
//      'vkGetSwapchainImagesKHR',
//      'vkCreateDescriptorPool',
//      'vkResetDescriptorPool',
//      'vkDestroyDescriptorPool',
//      'vkAllocateDescriptorSets',
//      'vkCreateCommandPool',
//      'vkAllocateCommandBuffers',
//      'vkCreateDescriptorSetLayout',
//      'vkDestroyDescriptorSetLayout',
//      'vkUpdateDescriptorSets',
//      'vkDeviceWaitIdle',
//      'vkDestroyCommandPool',
//      'vkCreateFence',
//      'vkDestroyFence',
//      'vkCreateSemaphore',
//      'vkDestroySemaphore',
//      'vkWaitForFences',
//      'vkResetFences',
//      'vkGetBufferDeviceAddress',
//      'vkAcquireNextImageKHR',
//      'vkDestroyDevice',
//      'vkCreateSampler',
//      'vkCreateBuffer',
//      'vkDestroyBuffer',
//      'vkGetBufferMemoryRequirements',
//      'vkBindBufferMemory',
//      'vkCreateImage',
//      'vkDestroyImage',
//      'vkGetImageMemoryRequirements',
//      'vkBindImageMemory',
//      'vkAllocateMemory',
//      'vkFreeMemory',
//      'vkMapMemory',
//      'vkUnmapMemory',
//      'vkBeginCommandBuffer',
//      'vkResetCommandBuffer',
//      'vkCmdPipelineBarrier2',
//      'vkCmdClearColorImage',
//      'vkEndCommandBuffer',
//      'vkCmdCopyBuffer2',
//      'vkCmdBlitImage2',
//      'vkCmdBindPipeline',
//      'vkCmdBindIndexBuffer',
//      'vkCmdBindDescriptorSets',
//      'vkCmdSetViewport',
//      'vkCmdSetScissor',
//      'vkCmdDispatch',
//      'vkCmdBeginRendering',
//      'vkCmdDraw',
//      'vkCmdDrawIndexed',
//      'vkCmdEndRendering',
//      'vkCmdPushConstants',
//      'vkCmdSetLineWidth',
//      'vkCmdSetDepthBounds',
//      'vkCmdCopyBufferToImage2',
//      'vkCmdDrawIndexedIndirect',
//      'vkCmdDrawIndexedIndirectCount',
//  ]
//  all = global_defs + instance_defs + device_defs
//]]]
//[[[end]]]

//[[[cog
//   for item in all:
//      cog.outl(f"pub var {item[2].lower() + item[3:]}: PFN(c.PFN_vk{item[2:]}) = undefined;")
//]]]
pub var createInstance: PFN(c.PFN_vkCreateInstance) = undefined;
pub var enumerateInstanceExtensionProperties: PFN(c.PFN_vkEnumerateInstanceExtensionProperties) = undefined;
pub var enumerateInstanceLayerProperties: PFN(c.PFN_vkEnumerateInstanceLayerProperties) = undefined;
pub var enumerateInstanceVersion: PFN(c.PFN_vkEnumerateInstanceVersion) = undefined;
pub var destroyInstance: PFN(c.PFN_vkDestroyInstance) = undefined;
pub var destroySurfaceKHR: PFN(c.PFN_vkDestroySurfaceKHR) = undefined;
pub var enumeratePhysicalDevices: PFN(c.PFN_vkEnumeratePhysicalDevices) = undefined;
pub var enumerateDeviceExtensionProperties: PFN(c.PFN_vkEnumerateDeviceExtensionProperties) = undefined;
pub var getPhysicalDeviceQueueFamilyProperties: PFN(c.PFN_vkGetPhysicalDeviceQueueFamilyProperties) = undefined;
pub var getPhysicalDeviceSurfaceSupportKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR) = undefined;
pub var getPhysicalDeviceProperties2: PFN(c.PFN_vkGetPhysicalDeviceProperties2) = undefined;
pub var getPhysicalDeviceFeatures2: PFN(c.PFN_vkGetPhysicalDeviceFeatures2) = undefined;
pub var getPhysicalDeviceSurfaceCapabilitiesKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR) = undefined;
pub var getPhysicalDeviceSurfaceFormatsKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR) = undefined;
pub var getPhysicalDeviceSurfacePresentModesKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR) = undefined;
pub var getPhysicalDeviceMemoryProperties: PFN(c.PFN_vkGetPhysicalDeviceMemoryProperties) = undefined;
pub var createDevice: PFN(c.PFN_vkCreateDevice) = undefined;
pub var queueSubmit2: PFN(c.PFN_vkQueueSubmit2) = undefined;
pub var queueWaitIdle: PFN(c.PFN_vkQueueWaitIdle) = undefined;
pub var queueBindSparse: PFN(c.PFN_vkQueueBindSparse) = undefined;
pub var createDebugUtilsMessengerEXT: PFN(c.PFN_vkCreateDebugUtilsMessengerEXT) = undefined;
pub var destroyDebugUtilsMessengerEXT: PFN(c.PFN_vkDestroyDebugUtilsMessengerEXT) = undefined;
pub var queuePresentKHR: PFN(c.PFN_vkQueuePresentKHR) = undefined;
pub var getDeviceQueue: PFN(c.PFN_vkGetDeviceQueue) = undefined;
pub var createSwapchainKHR: PFN(c.PFN_vkCreateSwapchainKHR) = undefined;
pub var destroySwapchainKHR: PFN(c.PFN_vkDestroySwapchainKHR) = undefined;
pub var createShaderModule: PFN(c.PFN_vkCreateShaderModule) = undefined;
pub var createPipelineLayout: PFN(c.PFN_vkCreatePipelineLayout) = undefined;
pub var destroyShaderModule: PFN(c.PFN_vkDestroyShaderModule) = undefined;
pub var destroyPipelineLayout: PFN(c.PFN_vkDestroyPipelineLayout) = undefined;
pub var createComputePipelines: PFN(c.PFN_vkCreateComputePipelines) = undefined;
pub var createGraphicsPipelines: PFN(c.PFN_vkCreateGraphicsPipelines) = undefined;
pub var destroyPipeline: PFN(c.PFN_vkDestroyPipeline) = undefined;
pub var createImageView: PFN(c.PFN_vkCreateImageView) = undefined;
pub var destroyImageView: PFN(c.PFN_vkDestroyImageView) = undefined;
pub var getSwapchainImagesKHR: PFN(c.PFN_vkGetSwapchainImagesKHR) = undefined;
pub var createDescriptorPool: PFN(c.PFN_vkCreateDescriptorPool) = undefined;
pub var resetDescriptorPool: PFN(c.PFN_vkResetDescriptorPool) = undefined;
pub var destroyDescriptorPool: PFN(c.PFN_vkDestroyDescriptorPool) = undefined;
pub var allocateDescriptorSets: PFN(c.PFN_vkAllocateDescriptorSets) = undefined;
pub var createCommandPool: PFN(c.PFN_vkCreateCommandPool) = undefined;
pub var allocateCommandBuffers: PFN(c.PFN_vkAllocateCommandBuffers) = undefined;
pub var createDescriptorSetLayout: PFN(c.PFN_vkCreateDescriptorSetLayout) = undefined;
pub var destroyDescriptorSetLayout: PFN(c.PFN_vkDestroyDescriptorSetLayout) = undefined;
pub var updateDescriptorSets: PFN(c.PFN_vkUpdateDescriptorSets) = undefined;
pub var deviceWaitIdle: PFN(c.PFN_vkDeviceWaitIdle) = undefined;
pub var destroyCommandPool: PFN(c.PFN_vkDestroyCommandPool) = undefined;
pub var createFence: PFN(c.PFN_vkCreateFence) = undefined;
pub var destroyFence: PFN(c.PFN_vkDestroyFence) = undefined;
pub var createSemaphore: PFN(c.PFN_vkCreateSemaphore) = undefined;
pub var destroySemaphore: PFN(c.PFN_vkDestroySemaphore) = undefined;
pub var waitForFences: PFN(c.PFN_vkWaitForFences) = undefined;
pub var resetFences: PFN(c.PFN_vkResetFences) = undefined;
pub var getBufferDeviceAddress: PFN(c.PFN_vkGetBufferDeviceAddress) = undefined;
pub var acquireNextImageKHR: PFN(c.PFN_vkAcquireNextImageKHR) = undefined;
pub var destroyDevice: PFN(c.PFN_vkDestroyDevice) = undefined;
pub var createSampler: PFN(c.PFN_vkCreateSampler) = undefined;
pub var createBuffer: PFN(c.PFN_vkCreateBuffer) = undefined;
pub var destroyBuffer: PFN(c.PFN_vkDestroyBuffer) = undefined;
pub var getBufferMemoryRequirements: PFN(c.PFN_vkGetBufferMemoryRequirements) = undefined;
pub var bindBufferMemory: PFN(c.PFN_vkBindBufferMemory) = undefined;
pub var createImage: PFN(c.PFN_vkCreateImage) = undefined;
pub var destroyImage: PFN(c.PFN_vkDestroyImage) = undefined;
pub var getImageMemoryRequirements: PFN(c.PFN_vkGetImageMemoryRequirements) = undefined;
pub var bindImageMemory: PFN(c.PFN_vkBindImageMemory) = undefined;
pub var allocateMemory: PFN(c.PFN_vkAllocateMemory) = undefined;
pub var freeMemory: PFN(c.PFN_vkFreeMemory) = undefined;
pub var mapMemory: PFN(c.PFN_vkMapMemory) = undefined;
pub var unmapMemory: PFN(c.PFN_vkUnmapMemory) = undefined;
pub var beginCommandBuffer: PFN(c.PFN_vkBeginCommandBuffer) = undefined;
pub var resetCommandBuffer: PFN(c.PFN_vkResetCommandBuffer) = undefined;
pub var cmdPipelineBarrier2: PFN(c.PFN_vkCmdPipelineBarrier2) = undefined;
pub var cmdClearColorImage: PFN(c.PFN_vkCmdClearColorImage) = undefined;
pub var endCommandBuffer: PFN(c.PFN_vkEndCommandBuffer) = undefined;
pub var cmdCopyBuffer2: PFN(c.PFN_vkCmdCopyBuffer2) = undefined;
pub var cmdBlitImage2: PFN(c.PFN_vkCmdBlitImage2) = undefined;
pub var cmdBindPipeline: PFN(c.PFN_vkCmdBindPipeline) = undefined;
pub var cmdBindIndexBuffer: PFN(c.PFN_vkCmdBindIndexBuffer) = undefined;
pub var cmdBindDescriptorSets: PFN(c.PFN_vkCmdBindDescriptorSets) = undefined;
pub var cmdSetViewport: PFN(c.PFN_vkCmdSetViewport) = undefined;
pub var cmdSetScissor: PFN(c.PFN_vkCmdSetScissor) = undefined;
pub var cmdDispatch: PFN(c.PFN_vkCmdDispatch) = undefined;
pub var cmdBeginRendering: PFN(c.PFN_vkCmdBeginRendering) = undefined;
pub var cmdDraw: PFN(c.PFN_vkCmdDraw) = undefined;
pub var cmdDrawIndexed: PFN(c.PFN_vkCmdDrawIndexed) = undefined;
pub var cmdEndRendering: PFN(c.PFN_vkCmdEndRendering) = undefined;
pub var cmdPushConstants: PFN(c.PFN_vkCmdPushConstants) = undefined;
pub var cmdSetLineWidth: PFN(c.PFN_vkCmdSetLineWidth) = undefined;
pub var cmdSetDepthBounds: PFN(c.PFN_vkCmdSetDepthBounds) = undefined;
pub var cmdCopyBufferToImage2: PFN(c.PFN_vkCmdCopyBufferToImage2) = undefined;
pub var cmdDrawIndexedIndirect: PFN(c.PFN_vkCmdDrawIndexedIndirect) = undefined;
pub var cmdDrawIndexedIndirectCount: PFN(c.PFN_vkCmdDrawIndexedIndirectCount) = undefined;
//[[[end]]]

pub fn loadGlobalFunctions() void {
    //[[[cog
    //   for item in global_defs:
    //      cog.outl(f"getInstanceProcAddr(null, \"{item}\");")
    //]]]
    getInstanceProcAddr(null, "vkCreateInstance");
    getInstanceProcAddr(null, "vkEnumerateInstanceExtensionProperties");
    getInstanceProcAddr(null, "vkEnumerateInstanceLayerProperties");
    getInstanceProcAddr(null, "vkEnumerateInstanceVersion");
    //[[[end]]]
}

pub fn loadInstanceFunctions(instance: c.VkInstance) void {
    platform.vk.init(vkGetInstanceProcAddr, instance);
    vkGetDeviceProcAddr = @ptrCast(vkGetInstanceProcAddr(instance, "vkGetDeviceProcAddr") orelse {
        std.debug.panic("vkGetDeviceProcAddr not found", .{});
    });

    //[[[cog
    //   for item in instance_defs:
    //      cog.outl(f"getInstanceProcAddr(instance, \"{item}\");")
    //]]]
    getInstanceProcAddr(instance, "vkDestroyInstance");
    getInstanceProcAddr(instance, "vkDestroySurfaceKHR");
    getInstanceProcAddr(instance, "vkEnumeratePhysicalDevices");
    getInstanceProcAddr(instance, "vkEnumerateDeviceExtensionProperties");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceQueueFamilyProperties");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceSupportKHR");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceProperties2");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceFeatures2");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR");
    getInstanceProcAddr(instance, "vkGetPhysicalDeviceMemoryProperties");
    getInstanceProcAddr(instance, "vkCreateDevice");
    getInstanceProcAddr(instance, "vkQueueSubmit2");
    getInstanceProcAddr(instance, "vkQueueWaitIdle");
    getInstanceProcAddr(instance, "vkQueueBindSparse");
    getInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    getInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    getInstanceProcAddr(instance, "vkQueuePresentKHR");
    //[[[end]]]
}

pub fn loadDeviceFunctions(device: c.VkDevice) void {
    //[[[cog
    //   for item in device_defs:
    //      cog.outl(f"getDeviceProcAddr(device, \"{item}\");")
    //]]]
    getDeviceProcAddr(device, "vkGetDeviceQueue");
    getDeviceProcAddr(device, "vkCreateSwapchainKHR");
    getDeviceProcAddr(device, "vkDestroySwapchainKHR");
    getDeviceProcAddr(device, "vkCreateShaderModule");
    getDeviceProcAddr(device, "vkCreatePipelineLayout");
    getDeviceProcAddr(device, "vkDestroyShaderModule");
    getDeviceProcAddr(device, "vkDestroyPipelineLayout");
    getDeviceProcAddr(device, "vkCreateComputePipelines");
    getDeviceProcAddr(device, "vkCreateGraphicsPipelines");
    getDeviceProcAddr(device, "vkDestroyPipeline");
    getDeviceProcAddr(device, "vkCreateImageView");
    getDeviceProcAddr(device, "vkDestroyImageView");
    getDeviceProcAddr(device, "vkGetSwapchainImagesKHR");
    getDeviceProcAddr(device, "vkCreateDescriptorPool");
    getDeviceProcAddr(device, "vkResetDescriptorPool");
    getDeviceProcAddr(device, "vkDestroyDescriptorPool");
    getDeviceProcAddr(device, "vkAllocateDescriptorSets");
    getDeviceProcAddr(device, "vkCreateCommandPool");
    getDeviceProcAddr(device, "vkAllocateCommandBuffers");
    getDeviceProcAddr(device, "vkCreateDescriptorSetLayout");
    getDeviceProcAddr(device, "vkDestroyDescriptorSetLayout");
    getDeviceProcAddr(device, "vkUpdateDescriptorSets");
    getDeviceProcAddr(device, "vkDeviceWaitIdle");
    getDeviceProcAddr(device, "vkDestroyCommandPool");
    getDeviceProcAddr(device, "vkCreateFence");
    getDeviceProcAddr(device, "vkDestroyFence");
    getDeviceProcAddr(device, "vkCreateSemaphore");
    getDeviceProcAddr(device, "vkDestroySemaphore");
    getDeviceProcAddr(device, "vkWaitForFences");
    getDeviceProcAddr(device, "vkResetFences");
    getDeviceProcAddr(device, "vkGetBufferDeviceAddress");
    getDeviceProcAddr(device, "vkAcquireNextImageKHR");
    getDeviceProcAddr(device, "vkDestroyDevice");
    getDeviceProcAddr(device, "vkCreateSampler");
    getDeviceProcAddr(device, "vkCreateBuffer");
    getDeviceProcAddr(device, "vkDestroyBuffer");
    getDeviceProcAddr(device, "vkGetBufferMemoryRequirements");
    getDeviceProcAddr(device, "vkBindBufferMemory");
    getDeviceProcAddr(device, "vkCreateImage");
    getDeviceProcAddr(device, "vkDestroyImage");
    getDeviceProcAddr(device, "vkGetImageMemoryRequirements");
    getDeviceProcAddr(device, "vkBindImageMemory");
    getDeviceProcAddr(device, "vkAllocateMemory");
    getDeviceProcAddr(device, "vkFreeMemory");
    getDeviceProcAddr(device, "vkMapMemory");
    getDeviceProcAddr(device, "vkUnmapMemory");
    getDeviceProcAddr(device, "vkBeginCommandBuffer");
    getDeviceProcAddr(device, "vkResetCommandBuffer");
    getDeviceProcAddr(device, "vkCmdPipelineBarrier2");
    getDeviceProcAddr(device, "vkCmdClearColorImage");
    getDeviceProcAddr(device, "vkEndCommandBuffer");
    getDeviceProcAddr(device, "vkCmdCopyBuffer2");
    getDeviceProcAddr(device, "vkCmdBlitImage2");
    getDeviceProcAddr(device, "vkCmdBindPipeline");
    getDeviceProcAddr(device, "vkCmdBindIndexBuffer");
    getDeviceProcAddr(device, "vkCmdBindDescriptorSets");
    getDeviceProcAddr(device, "vkCmdSetViewport");
    getDeviceProcAddr(device, "vkCmdSetScissor");
    getDeviceProcAddr(device, "vkCmdDispatch");
    getDeviceProcAddr(device, "vkCmdBeginRendering");
    getDeviceProcAddr(device, "vkCmdDraw");
    getDeviceProcAddr(device, "vkCmdDrawIndexed");
    getDeviceProcAddr(device, "vkCmdEndRendering");
    getDeviceProcAddr(device, "vkCmdPushConstants");
    getDeviceProcAddr(device, "vkCmdSetLineWidth");
    getDeviceProcAddr(device, "vkCmdSetDepthBounds");
    getDeviceProcAddr(device, "vkCmdCopyBufferToImage2");
    getDeviceProcAddr(device, "vkCmdDrawIndexedIndirect");
    getDeviceProcAddr(device, "vkCmdDrawIndexedIndirectCount");
    //[[[end]]]
}
