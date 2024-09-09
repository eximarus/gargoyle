const std = @import("std");
const builtin = @import("builtin");

pub const CString = [*:0]const u8;

fn getVkPlatformDefine() []const u8 {
    return if (builtin.abi == .android)
        "VK_USE_PLATFORM_ANDROID_KHR"
    else switch (builtin.os.tag) {
        .ios => "VK_USE_PLATFORM_IOS_MVK",
        .macos => "VK_USE_PLATFORM_MACOS_MVK",
        .windows => "VK_USE_PLATFORM_WIN32_KHR",
        .linux => "VK_USE_PLATFORM_WAYLAND_KHR",
        else => @compileError("platform not supported."),
    };
}

pub const c = @cImport({
    @cDefine("VK_NO_PROTOTYPES", "");
    @cDefine(getVkPlatformDefine(), "");
    @cInclude("vulkan/vulkan.h");
});

fn PFN(comptime T: type) type {
    return @typeInfo(T).Optional.child;
}

var vk_lib: ?std.DynLib = null;

var vkGetInstanceProcAddr: PFN(c.PFN_vkGetInstanceProcAddr) = undefined;
var vkCreateInstance: PFN(c.PFN_vkCreateInstance) = undefined;
var vkEnumerateInstanceExtensionProperties: PFN(c.PFN_vkEnumerateInstanceExtensionProperties) = undefined;
var vkEnumerateInstanceLayerProperties: PFN(c.PFN_vkEnumerateInstanceLayerProperties) = undefined;
var vkEnumerateInstanceVersion: PFN(c.PFN_vkEnumerateInstanceVersion) = undefined;

fn getInstanceProcAddr(instance: c.VkInstance, comptime name: []const u8) void {
    @field(@This(), name) = @ptrCast(vkGetInstanceProcAddr(instance, @ptrCast(name)));
}

pub fn init() Result {
    if (vk_lib != null) {
        return Error.InitializationFailed;
    }

    const vk_lib_name = if (builtin.abi == .android)
        "libvulkan.so.1"
    else switch (builtin.os.tag) {
        .ios, .macos => "libvulkan.1.dylib",
        .windows => "vulkan-1.dll",
        .linux => "libvulkan.so.1",
        else => @compileError("platform not supported."),
    };

    var dyn_lib = std.DynLib.open(vk_lib_name) catch |err| {
        std.log.err("{}\n", .{err});
        return Error.InitializationFailed;
    };
    vk_lib = dyn_lib;

    vkGetInstanceProcAddr = dyn_lib.lookup(c.PFN_vkGetInstanceProcAddr, "vkGetInstanceProcAddr") orelse {
        return Error.InitializationFailed;
    } orelse {
        return Error.InitializationFailed;
    };

    getInstanceProcAddr(null, "vkCreateInstance");
    getInstanceProcAddr(null, "vkEnumerateInstanceExtensionProperties");
    getInstanceProcAddr(null, "vkEnumerateInstanceLayerProperties");
    getInstanceProcAddr(null, "vkEnumerateInstanceVersion");

    return .Success;
}

var vkEnumeratePhysicalDevices: PFN(c.PFN_vkEnumeratePhysicalDevices) = undefined;
var vkDestroySurfaceKHR: PFN(c.PFN_vkDestroySurfaceKHR) = undefined;
var vkDestroyInstance: PFN(c.PFN_vkDestroyInstance) = undefined;
var vkGetPhysicalDeviceQueueFamilyProperties: PFN(c.PFN_vkGetPhysicalDeviceQueueFamilyProperties) = undefined;
var vkEnumerateDeviceExtensionProperties: PFN(c.PFN_vkEnumerateDeviceExtensionProperties) = undefined;
var vkGetPhysicalDeviceSurfaceSupportKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR) = undefined;
var vkGetPhysicalDeviceProperties2: PFN(c.PFN_vkGetPhysicalDeviceProperties2) = undefined;
var vkGetPhysicalDeviceFeatures2: PFN(c.PFN_vkGetPhysicalDeviceFeatures2) = undefined;
var vkGetPhysicalDeviceSurfaceCapabilitiesKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR) = undefined;
var vkGetPhysicalDeviceSurfaceFormatsKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR) = undefined;
var vkGetPhysicalDeviceSurfacePresentModesKHR: PFN(c.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR) = undefined;
var vkCreateDevice: PFN(c.PFN_vkCreateDevice) = undefined;
var vkGetDeviceProcAddr: PFN(c.PFN_vkGetDeviceProcAddr) = undefined;

var vkCreateDebugUtilsMessengerEXT: PFN(c.PFN_vkCreateDebugUtilsMessengerEXT) = undefined;
var vkDestroyDebugUtilsMessengerEXT: PFN(c.PFN_vkDestroyDebugUtilsMessengerEXT) = undefined;
var vkGetPhysicalDeviceMemoryProperties: PFN(c.PFN_vkGetPhysicalDeviceMemoryProperties) = undefined;

var vkQueueSubmit: PFN(c.PFN_vkQueueSubmit) = undefined;
var vkQueueSubmit2KHR: PFN(c.PFN_vkQueueSubmit2KHR) = undefined;
var vkQueueWaitIdle: PFN(c.PFN_vkQueueWaitIdle) = undefined;
var vkQueueBindSparse: PFN(c.PFN_vkQueueBindSparse) = undefined;
var vkQueuePresentKHR: PFN(c.PFN_vkQueuePresentKHR) = undefined;

fn getDeviceProcAddr(device: c.VkDevice, comptime name: []const u8) void {
    @field(@This(), name) = @ptrCast(vkGetDeviceProcAddr(device, @ptrCast(name)));
}

pub inline fn createInstance(
    create_info: *const c.VkInstanceCreateInfo,
    allocator: ?*const c.VkAllocationCallbacks,
) !Instance {
    var self: Instance = undefined;
    try vkCheck(vkCreateInstance(create_info, allocator, @ptrCast(&self)));

    getInstanceProcAddr(self.handle(), "vkDestroyInstance");
    getInstanceProcAddr(self.handle(), "vkDestroySurfaceKHR");
    getInstanceProcAddr(self.handle(), "vkEnumeratePhysicalDevices");
    getInstanceProcAddr(self.handle(), "vkEnumerateDeviceExtensionProperties");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceQueueFamilyProperties");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceSurfaceSupportKHR");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceProperties2");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceFeatures2");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceSurfaceFormatsKHR");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceSurfacePresentModesKHR");
    getInstanceProcAddr(self.handle(), "vkGetPhysicalDeviceMemoryProperties");

    // TODO guard if debug utils enabled
    getInstanceProcAddr(self.handle(), "vkCreateDebugUtilsMessengerEXT");
    getInstanceProcAddr(self.handle(), "vkDestroyDebugUtilsMessengerEXT");

    getInstanceProcAddr(self.handle(), "vkCreateDevice");
    getInstanceProcAddr(self.handle(), "vkGetDeviceProcAddr");
    getInstanceProcAddr(self.handle(), "vkQueueSubmit");
    getInstanceProcAddr(self.handle(), "vkQueueSubmit2KHR");
    getInstanceProcAddr(self.handle(), "vkQueueWaitIdle");
    getInstanceProcAddr(self.handle(), "vkQueueBindSparse");
    getInstanceProcAddr(self.handle(), "vkQueuePresentKHR");

    return self;
}

pub fn enumerateInstanceVersion() !u32 {
    var instance_version: u32 = undefined;
    try vkCheck(vkEnumerateInstanceVersion(&instance_version));
    return instance_version;
}

pub fn enumerateInstanceExtensionProperties(
    allocator: std.mem.Allocator,
    layer_name: ?CString,
) ![]c.VkExtensionProperties {
    var instance_extension_count: u32 = undefined;
    try vkCheck(vkEnumerateInstanceExtensionProperties(
        @ptrCast(layer_name),
        &instance_extension_count,
        null,
    ));

    const instance_extensions = try allocator.alloc(
        c.VkExtensionProperties,
        instance_extension_count,
    );
    try vkCheck(vkEnumerateInstanceExtensionProperties(
        @ptrCast(layer_name),
        &instance_extension_count,
        instance_extensions.ptr,
    ));
    return instance_extensions;
}

pub fn enumerateInstanceLayerProperties(
    allocator: std.mem.Allocator,
) ![]c.VkLayerProperties {
    var instance_layer_count: u32 = undefined;
    try vkCheck(vkEnumerateInstanceLayerProperties(
        &instance_layer_count,
        null,
    ));

    const supported_validation_layers = try allocator.alloc(
        c.VkLayerProperties,
        instance_layer_count,
    );
    try vkCheck(vkEnumerateInstanceLayerProperties(
        &instance_layer_count,
        supported_validation_layers.ptr,
    ));
    return supported_validation_layers;
}

pub const Instance = *align(@alignOf(c.VkInstance)) opaque {
    pub inline fn handle(self: Instance) c.VkInstance {
        return @ptrCast(self);
    }

    pub inline fn enumeratePhysicalDevices(
        self: Instance,
        allocator: std.mem.Allocator,
    ) ![]PhysicalDevice {
        var gpu_count: u32 = 0;
        try vkCheck(vkEnumeratePhysicalDevices(self.handle(), &gpu_count, null));

        if (gpu_count < 1) {
            return error.VulkanNoSuitablePhysicalDevice;
        }

        const gpus = try allocator.alloc(PhysicalDevice, gpu_count);
        try vkCheck(vkEnumeratePhysicalDevices(
            self.handle(),
            &gpu_count,
            @ptrCast(gpus.ptr),
        ));
        return gpus;
    }

    pub inline fn destroySurfaceKHR(
        self: Instance,
        surface: SurfaceKHR,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroySurfaceKHR(self.handle(), surface, allocator);
    }

    pub inline fn createDebugUtilsMessengerEXT(
        self: Instance,
        info: *const c.VkDebugUtilsMessengerCreateInfoEXT,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !DebugUtilsMessengerEXT {
        var messenger: DebugUtilsMessengerEXT = undefined;

        try vkCheck(vkCreateDebugUtilsMessengerEXT(
            self.handle(),
            info,
            allocator,
            &messenger,
        ));
        return messenger;
    }

    pub inline fn destroyDebugUtilsMessengerEXT(
        self: Instance,
        debug_messenger: DebugUtilsMessengerEXT,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !void {
        vkDestroyDebugUtilsMessengerEXT(
            self.handle(),
            debug_messenger,
            allocator,
        );
    }

    pub inline fn destroy(
        self: Instance,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyInstance(self.handle(), allocator);
    }
};

pub const PhysicalDevice = *align(@alignOf(c.VkPhysicalDevice)) opaque {
    pub inline fn handle(self: PhysicalDevice) c.VkPhysicalDevice {
        return @ptrCast(self);
    }

    pub inline fn getQueueFamilyProperties(
        self: PhysicalDevice,
        allocator: std.mem.Allocator,
    ) ![]c.VkQueueFamilyProperties {
        var queue_family_count: u32 = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(
            self.handle(),
            &queue_family_count,
            null,
        );

        if (queue_family_count < 1) {
            std.log.err("No queue family found.\n", .{});
            return error.VulkanDeviceNoQueueFamily;
        }

        const queue_family_properties = try allocator.alloc(
            c.VkQueueFamilyProperties,
            queue_family_count,
        );
        vkGetPhysicalDeviceQueueFamilyProperties(
            self.handle(),
            &queue_family_count,
            queue_family_properties.ptr,
        );
        return queue_family_properties;
    }

    pub inline fn enumerateDeviceExtensionProperties(
        self: PhysicalDevice,
        allocator: std.mem.Allocator,
    ) ![]const c.VkExtensionProperties {
        var device_extension_count: u32 = undefined;
        try vkCheck(vkEnumerateDeviceExtensionProperties(
            self.handle(),
            null,
            &device_extension_count,
            null,
        ));

        const device_extensions = try allocator.alloc(
            c.VkExtensionProperties,
            device_extension_count,
        );
        try vkCheck(vkEnumerateDeviceExtensionProperties(
            self.handle(),
            null,
            &device_extension_count,
            device_extensions.ptr,
        ));
        return device_extensions;
    }

    pub inline fn getSurfaceSupportKHR(
        self: PhysicalDevice,
        i: u32,
        surface: SurfaceKHR,
    ) !bool {
        var supports_present: c.VkBool32 = undefined;
        try vkCheck(vkGetPhysicalDeviceSurfaceSupportKHR(
            self.handle(),
            i,
            surface,
            &supports_present,
        ));
        return supports_present != 0;
    }

    pub inline fn getMemoryProperties(
        self: PhysicalDevice,
    ) c.VkPhysicalDeviceMemoryProperties {
        var properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        vkGetPhysicalDeviceMemoryProperties(self.handle(), &properties);
        return properties;
    }

    pub inline fn getProperties2(
        self: PhysicalDevice,
        next: ?*anyopaque,
    ) c.VkPhysicalDeviceProperties {
        var props = c.VkPhysicalDeviceProperties2{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
            .pNext = next,
        };

        vkGetPhysicalDeviceProperties2(self.handle(), @ptrCast(&props));
        return props.properties;
    }

    pub inline fn getFeatures2(
        self: PhysicalDevice,
        next: ?*anyopaque,
    ) c.VkPhysicalDeviceFeatures {
        var features = c.VkPhysicalDeviceFeatures2{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
            .pNext = next,
        };
        vkGetPhysicalDeviceFeatures2(self.handle(), @ptrCast(&features));
        return features.features;
    }

    pub inline fn getSurfaceCapabilitiesKHR(
        self: PhysicalDevice,
        surface: SurfaceKHR,
    ) !c.VkSurfaceCapabilitiesKHR {
        var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        try vkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
            self.handle(),
            surface,
            &capabilities,
        ));
        return capabilities;
    }

    pub inline fn getSurfaceFormatsKHR(
        self: PhysicalDevice,
        surface: SurfaceKHR,
        allocator: std.mem.Allocator,
    ) ![]const c.VkSurfaceFormatKHR {
        var format_count: u32 = undefined;
        try vkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(
            self.handle(),
            surface,
            &format_count,
            null,
        ));

        const formats = try allocator.alloc(
            c.VkSurfaceFormatKHR,
            format_count,
        );
        try vkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(
            self.handle(),
            surface,
            &format_count,
            formats.ptr,
        ));
        return formats;
    }

    pub inline fn getSurfacePresentModesKHR(
        self: PhysicalDevice,
        surface: SurfaceKHR,
        allocator: std.mem.Allocator,
    ) ![]const c.VkPresentModeKHR {
        var mode_count: u32 = undefined;
        try vkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(
            self.handle(),
            surface,
            &mode_count,
            null,
        ));

        const modes = try allocator.alloc(
            c.VkPresentModeKHR,
            mode_count,
        );
        try vkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(
            self.handle(),
            surface,
            &mode_count,
            modes.ptr,
        ));
        return modes;
    }

    pub inline fn createDevice(
        self: PhysicalDevice,
        device_info: *const c.VkDeviceCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Device {
        var device: Device = undefined;
        try vkCheck(vkCreateDevice(
            self.handle(),
            device_info,
            allocator,
            @ptrCast(&device),
        ));

        getDeviceProcAddr(device.handle(), "vkGetDeviceQueue");
        getDeviceProcAddr(device.handle(), "vkCreateSwapchainKHR");
        getDeviceProcAddr(device.handle(), "vkDestroySwapchainKHR");
        getDeviceProcAddr(device.handle(), "vkCreateShaderModule");
        getDeviceProcAddr(device.handle(), "vkCreatePipelineLayout");
        getDeviceProcAddr(device.handle(), "vkDestroyShaderModule");
        getDeviceProcAddr(device.handle(), "vkDestroyPipelineLayout");
        getDeviceProcAddr(device.handle(), "vkCreateComputePipelines");
        getDeviceProcAddr(device.handle(), "vkCreateGraphicsPipelines");
        getDeviceProcAddr(device.handle(), "vkDestroyPipeline");
        getDeviceProcAddr(device.handle(), "vkCreateImageView");
        getDeviceProcAddr(device.handle(), "vkDestroyImageView");
        getDeviceProcAddr(device.handle(), "vkGetSwapchainImagesKHR");
        getDeviceProcAddr(device.handle(), "vkGetSwapchainImagesKHR");
        getDeviceProcAddr(device.handle(), "vkGetSwapchainImagesKHR");
        getDeviceProcAddr(device.handle(), "vkCreateDescriptorPool");
        getDeviceProcAddr(device.handle(), "vkResetDescriptorPool");
        getDeviceProcAddr(device.handle(), "vkDestroyDescriptorPool");
        getDeviceProcAddr(device.handle(), "vkAllocateDescriptorSets");
        getDeviceProcAddr(device.handle(), "vkCreateCommandPool");
        getDeviceProcAddr(device.handle(), "vkAllocateCommandBuffers");
        getDeviceProcAddr(device.handle(), "vkCreateDescriptorSetLayout");
        getDeviceProcAddr(device.handle(), "vkDestroyDescriptorSetLayout");
        getDeviceProcAddr(device.handle(), "vkUpdateDescriptorSets");
        getDeviceProcAddr(device.handle(), "vkDeviceWaitIdle");
        getDeviceProcAddr(device.handle(), "vkDestroyCommandPool");
        getDeviceProcAddr(device.handle(), "vkCreateFence");
        getDeviceProcAddr(device.handle(), "vkDestroyFence");
        getDeviceProcAddr(device.handle(), "vkCreateSemaphore");
        getDeviceProcAddr(device.handle(), "vkDestroySemaphore");
        getDeviceProcAddr(device.handle(), "vkWaitForFences");
        getDeviceProcAddr(device.handle(), "vkResetFences");
        getDeviceProcAddr(device.handle(), "vkGetBufferDeviceAddress");
        getDeviceProcAddr(device.handle(), "vkAcquireNextImageKHR");
        getDeviceProcAddr(device.handle(), "vkDestroyDevice");

        getDeviceProcAddr(device.handle(), "vkCreateBuffer");
        getDeviceProcAddr(device.handle(), "vkDestroyBuffer");
        getDeviceProcAddr(device.handle(), "vkGetBufferMemoryRequirements");
        getDeviceProcAddr(device.handle(), "vkBindBufferMemory");

        getDeviceProcAddr(device.handle(), "vkCreateImage");
        getDeviceProcAddr(device.handle(), "vkDestroyImage");
        getDeviceProcAddr(device.handle(), "vkGetImageMemoryRequirements");
        getDeviceProcAddr(device.handle(), "vkBindImageMemory");

        getDeviceProcAddr(device.handle(), "vkAllocateMemory");
        getDeviceProcAddr(device.handle(), "vkFreeMemory");
        getDeviceProcAddr(device.handle(), "vkMapMemory");
        getDeviceProcAddr(device.handle(), "vkUnmapMemory");

        getDeviceProcAddr(device.handle(), "vkBeginCommandBuffer");
        getDeviceProcAddr(device.handle(), "vkResetCommandBuffer");
        getDeviceProcAddr(device.handle(), "vkCmdPipelineBarrier2KHR");
        getDeviceProcAddr(device.handle(), "vkCmdClearColorImage");
        getDeviceProcAddr(device.handle(), "vkEndCommandBuffer");
        getDeviceProcAddr(device.handle(), "vkCmdCopyBuffer");
        getDeviceProcAddr(device.handle(), "vkCmdBlitImage2KHR");
        getDeviceProcAddr(device.handle(), "vkCmdBindPipeline");
        getDeviceProcAddr(device.handle(), "vkCmdBindIndexBuffer");
        getDeviceProcAddr(device.handle(), "vkCmdBindDescriptorSets");
        getDeviceProcAddr(device.handle(), "vkCmdSetViewport");
        getDeviceProcAddr(device.handle(), "vkCmdSetScissor");
        getDeviceProcAddr(device.handle(), "vkCmdDispatch");
        getDeviceProcAddr(device.handle(), "vkCmdBeginRenderingKHR");
        getDeviceProcAddr(device.handle(), "vkCmdDraw");
        getDeviceProcAddr(device.handle(), "vkCmdDrawIndexed");
        getDeviceProcAddr(device.handle(), "vkCmdEndRenderingKHR");
        getDeviceProcAddr(device.handle(), "vkCmdPushConstants");

        return device;
    }
};

var vkGetDeviceQueue: PFN(c.PFN_vkGetDeviceQueue) = undefined;
var vkCreateSwapchainKHR: PFN(c.PFN_vkCreateSwapchainKHR) = undefined;
var vkDestroySwapchainKHR: PFN(c.PFN_vkDestroySwapchainKHR) = undefined;
var vkCreateShaderModule: PFN(c.PFN_vkCreateShaderModule) = undefined;
var vkCreatePipelineLayout: PFN(c.PFN_vkCreatePipelineLayout) = undefined;
var vkDestroyShaderModule: PFN(c.PFN_vkDestroyShaderModule) = undefined;
var vkDestroyPipelineLayout: PFN(c.PFN_vkDestroyPipelineLayout) = undefined;

var vkCreateComputePipelines: PFN(c.PFN_vkCreateComputePipelines) = undefined;
var vkCreateGraphicsPipelines: PFN(c.PFN_vkCreateGraphicsPipelines) = undefined;
var vkDestroyPipeline: PFN(c.PFN_vkDestroyPipeline) = undefined;
var vkCreateImageView: PFN(c.PFN_vkCreateImageView) = undefined;
var vkDestroyImageView: PFN(c.PFN_vkDestroyImageView) = undefined;
var vkGetSwapchainImagesKHR: PFN(c.PFN_vkGetSwapchainImagesKHR) = undefined;
var vkCreateDescriptorPool: PFN(c.PFN_vkCreateDescriptorPool) = undefined;
var vkResetDescriptorPool: PFN(c.PFN_vkResetDescriptorPool) = undefined;
var vkDestroyDescriptorPool: PFN(c.PFN_vkDestroyDescriptorPool) = undefined;
var vkAllocateDescriptorSets: PFN(c.PFN_vkAllocateDescriptorSets) = undefined;
var vkCreateCommandPool: PFN(c.PFN_vkCreateCommandPool) = undefined;
var vkAllocateCommandBuffers: PFN(c.PFN_vkAllocateCommandBuffers) = undefined;
var vkCreateDescriptorSetLayout: PFN(c.PFN_vkCreateDescriptorSetLayout) = undefined;
var vkDestroyDescriptorSetLayout: PFN(c.PFN_vkDestroyDescriptorSetLayout) = undefined;
var vkUpdateDescriptorSets: PFN(c.PFN_vkUpdateDescriptorSets) = undefined;
var vkDeviceWaitIdle: PFN(c.PFN_vkDeviceWaitIdle) = undefined;
var vkDestroyCommandPool: PFN(c.PFN_vkDestroyCommandPool) = undefined;
var vkCreateFence: PFN(c.PFN_vkCreateFence) = undefined;
var vkDestroyFence: PFN(c.PFN_vkDestroyFence) = undefined;
var vkCreateSemaphore: PFN(c.PFN_vkCreateSemaphore) = undefined;
var vkDestroySemaphore: PFN(c.PFN_vkDestroySemaphore) = undefined;
var vkWaitForFences: PFN(c.PFN_vkWaitForFences) = undefined;
var vkResetFences: PFN(c.PFN_vkResetFences) = undefined;
var vkGetBufferDeviceAddress: PFN(c.PFN_vkGetBufferDeviceAddress) = undefined;
var vkAcquireNextImageKHR: PFN(c.PFN_vkAcquireNextImageKHR) = undefined;
var vkDestroyDevice: PFN(c.PFN_vkDestroyDevice) = undefined;

var vkCreateBuffer: PFN(c.PFN_vkCreateBuffer) = undefined;
var vkDestroyBuffer: PFN(c.PFN_vkDestroyBuffer) = undefined;
var vkGetBufferMemoryRequirements: PFN(c.PFN_vkGetBufferMemoryRequirements) = undefined;
var vkBindBufferMemory: PFN(c.PFN_vkBindBufferMemory) = undefined;

var vkCreateImage: PFN(c.PFN_vkCreateImage) = undefined;
var vkDestroyImage: PFN(c.PFN_vkDestroyImage) = undefined;
var vkGetImageMemoryRequirements: PFN(c.PFN_vkGetImageMemoryRequirements) = undefined;
var vkBindImageMemory: PFN(c.PFN_vkBindImageMemory) = undefined;

var vkAllocateMemory: PFN(c.PFN_vkAllocateMemory) = undefined;
var vkFreeMemory: PFN(c.PFN_vkFreeMemory) = undefined;
var vkMapMemory: PFN(c.PFN_vkMapMemory) = undefined;
var vkUnmapMemory: PFN(c.PFN_vkUnmapMemory) = undefined;

var vkBeginCommandBuffer: PFN(c.PFN_vkBeginCommandBuffer) = undefined;
var vkResetCommandBuffer: PFN(c.PFN_vkResetCommandBuffer) = undefined;
var vkCmdPipelineBarrier2KHR: PFN(c.PFN_vkCmdPipelineBarrier2KHR) = undefined;
var vkCmdClearColorImage: PFN(c.PFN_vkCmdClearColorImage) = undefined;
var vkEndCommandBuffer: PFN(c.PFN_vkEndCommandBuffer) = undefined;
var vkCmdCopyBuffer: PFN(c.PFN_vkCmdCopyBuffer) = undefined;
var vkCmdBlitImage2KHR: PFN(c.PFN_vkCmdBlitImage2KHR) = undefined;
var vkCmdBindPipeline: PFN(c.PFN_vkCmdBindPipeline) = undefined;
var vkCmdBindIndexBuffer: PFN(c.PFN_vkCmdBindIndexBuffer) = undefined;
var vkCmdBindDescriptorSets: PFN(c.PFN_vkCmdBindDescriptorSets) = undefined;
var vkCmdSetViewport: PFN(c.PFN_vkCmdSetViewport) = undefined;
var vkCmdSetScissor: PFN(c.PFN_vkCmdSetScissor) = undefined;
var vkCmdDispatch: PFN(c.PFN_vkCmdDispatch) = undefined;
var vkCmdBeginRenderingKHR: PFN(c.PFN_vkCmdBeginRenderingKHR) = undefined;
var vkCmdDraw: PFN(c.PFN_vkCmdDraw) = undefined;
var vkCmdDrawIndexed: PFN(c.PFN_vkCmdDrawIndexed) = undefined;
var vkCmdEndRenderingKHR: PFN(c.PFN_vkCmdEndRenderingKHR) = undefined;
var vkCmdPushConstants: PFN(c.PFN_vkCmdPushConstants) = undefined;

pub const Device = *align(@alignOf(c.VkDevice)) opaque {
    pub inline fn handle(self: Device) c.VkDevice {
        return @ptrCast(self);
    }

    pub inline fn getQueue(self: Device, family_index: u32, index: u32) !Queue {
        var queue: Queue = undefined;
        vkGetDeviceQueue(self.handle(), family_index, index, @ptrCast(&queue));
        return queue;
    }

    pub inline fn createSwapchainKHR(
        self: Device,
        info: *const c.VkSwapchainCreateInfoKHR,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !SwapchainKHR {
        var swapchain: SwapchainKHR = undefined;
        try vkCheck(vkCreateSwapchainKHR(
            self.handle(),
            info,
            allocator,
            &swapchain,
        ));
        return swapchain;
    }

    pub inline fn createBuffer(
        self: Device,
        info: *const c.VkBufferCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Buffer {
        var buffer: Buffer = undefined;
        try vkCheck(vkCreateBuffer(self.handle(), info, allocator, &buffer));
        return buffer;
    }

    pub inline fn bindBufferMemory(
        self: Device,
        buffer: Buffer,
        memory: VkDeviceMemory,
        memory_offset: c.VkDeviceSize,
    ) !void {
        return vkCheck(vkBindBufferMemory(self.handle(), buffer, memory, memory_offset));
    }

    pub inline fn destroyBuffer(
        self: Device,
        buffer: Buffer,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyBuffer(self.handle(), buffer, allocator);
    }

    pub inline fn createImage(
        self: Device,
        info: *const c.VkImageCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Image {
        var image: Image = undefined;
        try vkCheck(vkCreateImage(self.handle(), info, allocator, &image));
        return image;
    }

    pub inline fn bindImageMemory(
        self: Device,
        image: Image,
        memory: VkDeviceMemory,
        memory_offset: c.VkDeviceSize,
    ) !void {
        return vkCheck(vkBindImageMemory(self.handle(), image, memory, memory_offset));
    }

    pub inline fn destroyImage(
        self: Device,
        image: Image,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyImage(self.handle(), image, allocator);
    }

    pub inline fn allocateMemory(
        self: Device,
        info: *const c.VkMemoryAllocateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !VkDeviceMemory {
        var memory: VkDeviceMemory = undefined;
        try vkCheck(vkAllocateMemory(self.handle(), info, allocator, &memory));
        return memory;
    }

    pub inline fn freeMemory(
        self: Device,
        memory: VkDeviceMemory,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkFreeMemory(self.handle(), memory, allocator);
    }

    pub inline fn destroySwapchainKHR(
        self: Device,
        swapchain: SwapchainKHR,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroySwapchainKHR(self.handle(), swapchain, allocator);
    }

    pub inline fn createShaderModule(
        self: Device,
        info: *const c.VkShaderModuleCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !ShaderModule {
        var mod: ShaderModule = undefined;
        try vkCheck(vkCreateShaderModule(
            self.handle(),
            info,
            allocator,
            &mod,
        ));
        return mod;
    }

    pub inline fn destroyShaderModule(
        self: Device,
        shader: ShaderModule,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyShaderModule(self.handle(), shader, allocator);
    }

    pub inline fn createPipelineLayout(
        self: Device,
        info: *const c.VkPipelineLayoutCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !PipelineLayout {
        var layout: PipelineLayout = undefined;
        try vkCheck(vkCreatePipelineLayout(
            self.handle(),
            info,
            allocator,
            &layout,
        ));
        return layout;
    }

    pub inline fn destroyPipelineLayout(
        self: Device,
        layout: PipelineLayout,
        allocator: ?*c.VkAllocationCallbacks,
    ) void {
        vkDestroyPipelineLayout(self.handle(), layout, allocator);
    }

    pub inline fn createComputePipelines(
        self: Device,
        cache: ?PipelineCache,
        infos: []const c.VkComputePipelineCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Pipeline {
        var pipeline: Pipeline = undefined;
        try vkCheck(vkCreateComputePipelines(
            self.handle(),
            if (cache) |value| value else null,
            @intCast(infos.len),
            @ptrCast(infos.ptr),
            allocator,
            &pipeline,
        ));
        return pipeline;
    }

    pub inline fn createGraphicsPipelines(
        self: Device,
        cache: ?PipelineCache,
        infos: []const c.VkGraphicsPipelineCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Pipeline {
        var pipeline: Pipeline = undefined;
        try vkCheck(vkCreateGraphicsPipelines(
            self.handle(),
            if (cache) |value| value else null,
            @intCast(infos.len),
            @ptrCast(infos.ptr),
            allocator,
            &pipeline,
        ));
        return pipeline;
    }

    pub inline fn destroyPipeline(
        self: Device,
        pipeline: Pipeline,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyPipeline(self.handle(), pipeline, allocator);
    }

    pub inline fn createImageView(
        self: Device,
        create_info: *const c.VkImageViewCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !ImageView {
        var view: ImageView = undefined;
        try vkCheck(vkCreateImageView(
            self.handle(),
            create_info,
            allocator,
            &view,
        ));
        return view;
    }

    pub inline fn destroyImageView(
        self: Device,
        image_view: ImageView,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyImageView(self.handle(), image_view, allocator);
    }

    pub inline fn getSwapchainImageCount(self: Device, swapchain: SwapchainKHR) !u32 {
        var image_count: u32 = undefined;
        try vkCheck(vkGetSwapchainImagesKHR(
            self.handle(),
            swapchain,
            &image_count,
            null,
        ));
        return image_count;
    }

    pub inline fn getSwapchainImagesKHR(
        self: Device,
        swapchain: SwapchainKHR,
        allocator: std.mem.Allocator,
    ) ![]Image {
        var image_count: u32 = undefined;

        try vkCheck(vkGetSwapchainImagesKHR(
            self.handle(),
            swapchain,
            &image_count,
            null,
        ));

        const swapchain_images = try allocator.alloc(
            Image,
            image_count,
        );

        try vkCheck(vkGetSwapchainImagesKHR(
            self.handle(),
            swapchain,
            &image_count,
            @ptrCast(swapchain_images.ptr),
        ));
        return swapchain_images;
    }

    pub inline fn getSwapchainImagesKHRBuffered(
        self: Device,
        swapchain: SwapchainKHR,
        list: *std.ArrayList(Image),
    ) !void {
        var image_count: u32 = undefined;

        try vkCheck(vkGetSwapchainImagesKHR(
            self.handle(),
            swapchain,
            &image_count,
            null,
        ));

        try list.ensureUnusedCapacity(image_count);
        try vkCheck(vkGetSwapchainImagesKHR(
            self.handle(),
            swapchain,
            &image_count,
            list.unusedCapacitySlice().ptr,
        ));
        list.items.len += image_count;
    }

    pub inline fn createDescriptorPool(
        self: Device,
        info: *const c.VkDescriptorPoolCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !DescriptorPool {
        var pool: DescriptorPool = undefined;
        try vkCheck(vkCreateDescriptorPool(
            self.handle(),
            info,
            allocator,
            &pool,
        ));
        return pool;
    }

    pub inline fn resetDescriptorPool(
        self: Device,
        pool: DescriptorPool,
        flags: c.VkDescriptorPoolResetFlags,
    ) Result {
        return result(vkResetDescriptorPool(
            self.handle(),
            pool,
            flags,
        ));
    }

    pub inline fn destroyDescriptorPool(
        self: Device,
        pool: DescriptorPool,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyDescriptorPool(
            self.handle(),
            pool,
            allocator,
        );
    }

    pub inline fn allocateDescriptorSet(
        self: Device,
        info: *const struct {
            pNext: ?*const anyopaque = std.mem.zeroes(?*const anyopaque),
            descriptorPool: DescriptorPool = std.mem.zeroes(DescriptorPool),
            layout: DescriptorSetLayout = std.mem.zeroes(DescriptorSetLayout),
        },
    ) !DescriptorSet {
        return (try self.allocateDescriptorSets(1, &.{
            .pNext = info.pNext,
            .descriptorPool = info.descriptorPool,
            .layouts = .{info.layout},
        }))[0];
    }

    pub inline fn allocateDescriptorSets(
        self: Device,
        comptime count: comptime_int,
        info: *const struct {
            pNext: ?*const anyopaque = std.mem.zeroes(?*const anyopaque),
            descriptorPool: DescriptorPool = std.mem.zeroes(DescriptorPool),
            layouts: [count]DescriptorSetLayout = std.mem.zeroes([count]DescriptorSetLayout),
        },
    ) ![count]DescriptorSet {
        var descriptor_sets: [count]DescriptorSet = undefined;
        try check(self.allocateDescriptorSetsDynamic(&.{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .pNext = info.pNext,
            .descriptorPool = info.descriptorPool,
            .descriptorSetCount = count,
            .pSetLayouts = &info.layouts,
        }, &descriptor_sets));
        return descriptor_sets;
    }

    pub inline fn allocateDescriptorSetsDynamic(
        self: Device,
        info: *const c.VkDescriptorSetAllocateInfo,
        out_descriptor_sets: [*]DescriptorSet,
    ) Result {
        return result(vkAllocateDescriptorSets(
            self.handle(),
            info,
            out_descriptor_sets,
        ));
    }

    pub inline fn createCommandPool(
        self: Device,
        info: *const c.VkCommandPoolCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !CommandPool {
        var pool: CommandPool = undefined;
        try vkCheck(vkCreateCommandPool(
            self.handle(),
            info,
            allocator,
            &pool,
        ));
        return pool;
    }

    pub inline fn allocateCommandBuffers(
        self: Device,
        info: *const c.VkCommandBufferAllocateInfo,
    ) !CommandBuffer {
        var buffer: CommandBuffer = undefined;
        try vkCheck(vkAllocateCommandBuffers(
            self.handle(),
            info,
            @ptrCast(&buffer),
        ));
        return buffer;
    }

    pub inline fn createDescriptorSetLayout(
        self: Device,
        info: *const c.VkDescriptorSetLayoutCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !DescriptorSetLayout {
        var layout: DescriptorSetLayout = undefined;
        try vkCheck(vkCreateDescriptorSetLayout(
            self.handle(),
            info,
            allocator,
            &layout,
        ));
        return layout;
    }

    pub inline fn destroyDescriptorSetLayout(
        self: Device,
        layout: DescriptorSetLayout,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyDescriptorSetLayout(self.handle(), layout, allocator);
    }

    pub inline fn updateDescriptorSets(
        self: Device,
        descriptor_writes: []const c.VkWriteDescriptorSet,
        descriptor_copies: []const c.VkCopyDescriptorSet,
    ) void {
        vkUpdateDescriptorSets(
            self.handle(),
            @intCast(descriptor_writes.len),
            @ptrCast(descriptor_writes.ptr),
            @intCast(descriptor_copies.len),
            @ptrCast(descriptor_copies.ptr),
        );
    }

    pub inline fn waitIdle(self: Device) Result {
        return result(vkDeviceWaitIdle(self.handle()));
    }

    pub inline fn destroyCommandPool(
        self: Device,
        command_pool: CommandPool,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyCommandPool(self.handle(), command_pool, allocator);
    }

    pub inline fn createFence(
        self: Device,
        info: *const c.VkFenceCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Fence {
        var fence: Fence = undefined;
        try vkCheck(vkCreateFence(
            self.handle(),
            info,
            allocator,
            &fence,
        ));
        return fence;
    }

    pub inline fn destroyFence(
        self: Device,
        fence: Fence,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyFence(self.handle(), fence, allocator);
    }

    pub inline fn createSemaphore(
        self: Device,
        info: *const c.VkSemaphoreCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Semaphore {
        var semaphore: Semaphore = undefined;
        try vkCheck(vkCreateSemaphore(
            self.handle(),
            info,
            allocator,
            &semaphore,
        ));
        return semaphore;
    }

    pub inline fn destroySemaphore(
        self: Device,
        semaphore: Semaphore,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroySemaphore(self.handle(), semaphore, allocator);
    }

    pub inline fn waitForFences(
        self: Device,
        fences: []const Fence,
        wait_all: bool,
        timeout: u64,
    ) Result {
        return result(vkWaitForFences(
            self.handle(),
            @intCast(fences.len),
            @ptrCast(fences.ptr),
            vkBool32(wait_all),
            timeout,
        ));
    }

    pub inline fn resetFences(self: Device, fences: []const Fence) Result {
        return result(vkResetFences(
            self.handle(),
            @intCast(fences.len),
            @ptrCast(fences.ptr),
        ));
    }

    pub inline fn mapMemory(
        self: Device,
        memory: VkDeviceMemory,
        offset: c.VkDeviceSize,
        size: c.VkDeviceSize,
        flags: c.VkMemoryMapFlags,
    ) !*anyopaque {
        var data: ?*anyopaque = undefined;
        try vkCheck(vkMapMemory(
            self.handle(),
            memory,
            offset,
            size,
            flags,
            &data,
        ));

        return data orelse error.MappedToNullMemory;
    }

    pub inline fn unmapMemory(self: Device, memory: VkDeviceMemory) void {
        vkUnmapMemory(self.handle(), memory);
    }

    pub inline fn getBufferDeviceAddress(
        self: Device,
        info: *const c.VkBufferDeviceAddressInfo,
    ) c.VkDeviceAddress {
        return vkGetBufferDeviceAddress(self.handle(), info);
    }

    pub inline fn getBufferMemoryRequirements(
        self: Device,
        buffer: Buffer,
    ) c.VkMemoryRequirements {
        var requirements: c.VkMemoryRequirements = undefined;
        vkGetBufferMemoryRequirements(
            self.handle(),
            buffer,
            &requirements,
        );
        return requirements;
    }

    pub inline fn getImageMemoryRequirements(
        self: Device,
        image: Image,
    ) c.VkMemoryRequirements {
        var requirements: c.VkMemoryRequirements = undefined;
        vkGetImageMemoryRequirements(
            self.handle(),
            image,
            &requirements,
        );
        return requirements;
    }

    pub inline fn acquireNextImageKHR(
        self: Device,
        swapchain: SwapchainKHR,
        timeout: u64,
        semaphore: ?Semaphore,
        fence: ?Fence,
    ) !u32 {
        var index: u32 = undefined;
        try vkCheck(vkAcquireNextImageKHR(
            self.handle(),
            swapchain,
            timeout,
            if (semaphore) |value| value else null,
            if (fence) |value| value else null,
            &index,
        ));
        return index;
    }

    pub inline fn destroy(
        self: Device,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        vkDestroyDevice(self.handle(), allocator);
    }
};

pub const Queue = *align(@alignOf(c.VkQueue)) opaque {
    pub inline fn handle(self: Queue) c.VkQueue {
        return @ptrCast(self);
    }

    pub inline fn submit(
        self: Queue,
        info: []const c.VkSubmitInfo,
        fence: ?Fence,
    ) Result {
        return result(vkQueueSubmit(
            self.handle(),
            @intCast(info.len),
            @ptrCast(info.ptr),
            if (fence) |f| f else null,
        ));
    }

    pub inline fn submit2(
        self: Queue,
        info: []const c.VkSubmitInfo2KHR,
        fence: ?Fence,
    ) Result {
        return result(vkQueueSubmit2KHR(
            self.handle(),
            @intCast(info.len),
            @ptrCast(info.ptr),
            if (fence) |f| f else null,
        ));
    }

    pub inline fn waitIdle(self: Queue) Result {
        return result(vkQueueWaitIdle(self.handle()));
    }

    pub inline fn bindSparse(
        self: Queue,
        info: []const c.VkBindSparseInfo,
        fence: ?Fence,
    ) Result {
        return result(vkQueueBindSparse(
            self.handle(),
            @intCast(info.len),
            @ptrCast(info.ptr),
            if (fence) |f| f else null,
        ));
    }

    pub inline fn presentKHR(
        self: Queue,
        info: *const c.VkPresentInfoKHR,
    ) Result {
        return result(vkQueuePresentKHR(self.handle(), info));
    }

    // c.vkQueueSignalReleaseImageANDROID
};

pub const CommandBuffer = *align(@alignOf(c.VkCommandBuffer)) opaque {
    pub inline fn handle(self: CommandBuffer) c.VkCommandBuffer {
        return @ptrCast(self);
    }

    pub inline fn begin(
        self: CommandBuffer,
        info: *const c.VkCommandBufferBeginInfo,
    ) Result {
        return result(vkBeginCommandBuffer(self.handle(), info));
    }

    pub inline fn reset(
        self: CommandBuffer,
        flags: c.VkCommandBufferResetFlags,
    ) Result {
        return result(vkResetCommandBuffer(self.handle(), flags));
    }

    pub inline fn pipelineBarrier2(
        self: CommandBuffer,
        info: *const c.VkDependencyInfo,
    ) void {
        vkCmdPipelineBarrier2KHR(self.handle(), info);
    }

    pub inline fn clearColorImage(
        self: CommandBuffer,
        image: Image,
        image_layout: c.VkImageLayout,
        color: *const c.VkClearColorValue,
        ranges: []const c.VkImageSubresourceRange,
    ) void {
        vkCmdClearColorImage(
            self.handle(),
            image,
            image_layout,
            color,
            @intCast(ranges.len),
            @ptrCast(ranges.ptr),
        );
    }

    pub inline fn end(self: CommandBuffer) Result {
        return result(vkEndCommandBuffer(self.handle()));
    }

    pub inline fn copyBuffer(
        self: CommandBuffer,
        src: Buffer,
        dst: Buffer,
        regions: []const c.VkBufferCopy,
    ) void {
        vkCmdCopyBuffer(
            self.handle(),
            src,
            dst,
            @intCast(regions.len),
            @ptrCast(regions.ptr),
        );
    }

    pub inline fn blitImage2(
        self: CommandBuffer,
        info: *const c.VkBlitImageInfo2KHR,
    ) void {
        vkCmdBlitImage2KHR(self.handle(), info);
    }

    pub inline fn bindPipeline(
        self: CommandBuffer,
        bind_point: c.VkPipelineBindPoint,
        pipeline: Pipeline,
    ) void {
        vkCmdBindPipeline(self.handle(), bind_point, pipeline);
    }

    pub inline fn bindIndexBuffer(
        self: CommandBuffer,
        buffer: Buffer,
        offset: c.VkDeviceSize,
        index_type: c.VkIndexType,
    ) void {
        vkCmdBindIndexBuffer(self.handle(), buffer, offset, index_type);
    }

    // c.vkCmdBindDescriptorSets
    pub inline fn bindDescriptorSets(
        self: CommandBuffer,
        bind_point: c.VkPipelineBindPoint,
        layout: PipelineLayout,
        first_set: u32,
        descriptor_sets: []const DescriptorSet,
        dynamic_offsets: []const u32,
    ) void {
        vkCmdBindDescriptorSets(
            self.handle(),
            bind_point,
            layout,
            first_set,
            @intCast(descriptor_sets.len),
            @ptrCast(descriptor_sets.ptr),
            @intCast(dynamic_offsets.len),
            @ptrCast(dynamic_offsets.ptr),
        );
    }

    pub inline fn setViewport(
        self: CommandBuffer,
        first_viewport: u32,
        viewports: []const c.VkViewport,
    ) void {
        vkCmdSetViewport(
            self.handle(),
            first_viewport,
            @intCast(viewports.len),
            @ptrCast(viewports.ptr),
        );
    }

    pub inline fn setScissor(
        self: CommandBuffer,
        first_scissor: u32,
        scissors: []const c.VkRect2D,
    ) void {
        vkCmdSetScissor(
            self.handle(),
            first_scissor,
            @intCast(scissors.len),
            @ptrCast(scissors.ptr),
        );
    }

    pub inline fn dispatch(
        self: CommandBuffer,
        group_count_x: u32,
        group_count_y: u32,
        group_count_z: u32,
    ) void {
        vkCmdDispatch(
            self.handle(),
            group_count_x,
            group_count_y,
            group_count_z,
        );
    }

    pub inline fn beginRendering(
        self: CommandBuffer,
        info: *const c.VkRenderingInfoKHR,
    ) void {
        vkCmdBeginRenderingKHR(self.handle(), info);
    }

    pub inline fn draw(
        self: CommandBuffer,
        vertex_count: u32,
        instance_count: u32,
        first_vertex: u32,
        first_instance: u32,
    ) void {
        vkCmdDraw(
            self.handle(),
            vertex_count,
            instance_count,
            first_vertex,
            first_instance,
        );
    }

    pub inline fn drawIndexed(
        self: CommandBuffer,
        index_count: u32,
        instance_count: u32,
        first_index: u32,
        vertex_offset: i32,
        first_instance: u32,
    ) void {
        vkCmdDrawIndexed(
            self.handle(),
            index_count,
            instance_count,
            first_index,
            vertex_offset,
            first_instance,
        );
    }

    pub inline fn endRendering(self: CommandBuffer) void {
        vkCmdEndRenderingKHR(self.handle());
    }

    pub inline fn pushConstants(
        self: CommandBuffer,
        layout: PipelineLayout,
        stage_flags: c.VkShaderStageFlags,
        offset: u32,
        size: u32,
        values: ?*const anyopaque,
    ) void {
        vkCmdPushConstants(
            self.handle(),
            layout,
            stage_flags,
            offset,
            size,
            values,
        );
    }
};

pub const SurfaceKHR = c.VkSurfaceKHR;
pub const SwapchainKHR = c.VkSwapchainKHR;
pub const Image = c.VkImage;
pub const ImageView = c.VkImageView;
pub const CommandPool = c.VkCommandPool;
pub const Buffer = c.VkBuffer;
pub const BufferView = c.VkBufferView;
pub const ShaderModule = c.VkShaderModule;
pub const Pipeline = c.VkPipeline;
pub const PipelineLayout = c.VkPipelineLayout;
pub const Sampler = c.VkSampler;
pub const DescriptorSet = c.VkDescriptorSet;
pub const DescriptorSetLayout = c.VkDescriptorSetLayout;
pub const DescriptorPool = c.VkDescriptorPool;
pub const Fence = c.VkFence;
pub const Semaphore = c.VkSemaphore;
pub const Framebuffer = c.VkFramebuffer;
pub const RenderPass = c.VkRenderPass;
pub const PipelineCache = c.VkPipelineCache;
pub const DebugUtilsMessengerEXT = c.VkDebugUtilsMessengerEXT;
pub const VkDeviceMemory = c.VkDeviceMemory;

pub inline fn vkBool32(value: bool) c.VkBool32 {
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

pub inline fn check(r: Result) !void {
    if (r) |value| {
        if (value != .Success) {
            return error.Unsuccessful;
        }
    } else |err| return err;
}

inline fn vkCheck(r: c.VkResult) !void {
    return check(result(r));
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
