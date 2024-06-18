const std = @import("std");
const c = @import("c");
const common = @import("common.zig");
const CString = common.CString;

pub fn init() Result {
    return result(c.volkInitialize());
}

pub inline fn createInstance(
    create_info: *const c.VkInstanceCreateInfo,
    allocator: ?*const c.VkAllocationCallbacks,
) !Instance {
    var self: Instance = undefined;
    try vkCheck(c.vkCreateInstance.?(create_info, allocator, @ptrCast(&self)));
    c.volkLoadInstance(self.handle());
    return self;
}

pub fn enumerateInstanceVersion() !u32 {
    var instance_version: u32 = undefined;
    if (c.vkEnumerateInstanceVersion) |fun| {
        try vkCheck(fun(&instance_version));
        return instance_version;
    }
    return error.VkCommandNotSupported;
}

pub fn enumerateInstanceExtensionProperties(
    allocator: std.mem.Allocator,
    layer_name: ?CString,
) ![]c.VkExtensionProperties {
    var instance_extension_count: u32 = undefined;
    try vkCheck(c.vkEnumerateInstanceExtensionProperties.?(
        @ptrCast(layer_name),
        &instance_extension_count,
        null,
    ));

    const instance_extensions = try allocator.alloc(
        c.VkExtensionProperties,
        instance_extension_count,
    );
    try vkCheck(c.vkEnumerateInstanceExtensionProperties.?(
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
    try vkCheck(c.vkEnumerateInstanceLayerProperties.?(
        &instance_layer_count,
        null,
    ));

    const supported_validation_layers = try allocator.alloc(
        c.VkLayerProperties,
        instance_layer_count,
    );
    try vkCheck(c.vkEnumerateInstanceLayerProperties.?(
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
        const vkEnumeratePhysicalDevices = c.vkEnumeratePhysicalDevices.?;

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
        c.vkDestroySurfaceKHR.?(self.handle(), surface, allocator);
    }

    pub inline fn createDebugUtilsMessengerEXT(
        self: Instance,
        info: *const c.VkDebugUtilsMessengerCreateInfoEXT,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !DebugUtilsMessengerEXT {
        if (c.vkCreateDebugUtilsMessengerEXT) |func| {
            var messenger: DebugUtilsMessengerEXT = undefined;
            try vkCheck(func(
                self.handle(),
                info,
                allocator,
                &messenger,
            ));
            return messenger;
        }
        return Error.ExtensionNotPresent;
    }

    pub inline fn destroyDebugUtilsMessengerEXT(
        self: Instance,
        debug_messenger: DebugUtilsMessengerEXT,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !void {
        if (c.vkDestroyDebugUtilsMessengerEXT) |func| {
            func(
                self.handle(),
                debug_messenger,
                allocator,
            );
        } else {
            return Error.ExtensionNotPresent;
        }
    }

    pub inline fn destroy(
        self: Instance,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        c.vkDestroyInstance.?(self.handle(), allocator);
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
        c.vkGetPhysicalDeviceQueueFamilyProperties.?(
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
        c.vkGetPhysicalDeviceQueueFamilyProperties.?(
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
        try vkCheck(c.vkEnumerateDeviceExtensionProperties.?(
            self.handle(),
            null,
            &device_extension_count,
            null,
        ));

        const device_extensions = try allocator.alloc(
            c.VkExtensionProperties,
            device_extension_count,
        );
        try vkCheck(c.vkEnumerateDeviceExtensionProperties.?(
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
        try vkCheck(c.vkGetPhysicalDeviceSurfaceSupportKHR.?(
            self.handle(),
            i,
            surface,
            &supports_present,
        ));
        return supports_present != 0;
    }

    pub inline fn getProperties2(
        self: PhysicalDevice,
        next: ?*anyopaque,
    ) c.VkPhysicalDeviceProperties {
        var props = c.VkPhysicalDeviceProperties2{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
            .pNext = next,
        };

        c.vkGetPhysicalDeviceProperties2.?(self.handle(), @ptrCast(&props));
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
        c.vkGetPhysicalDeviceFeatures2.?(self.handle(), @ptrCast(&features));
        return features.features;
    }

    pub inline fn getSurfaceCapabilitiesKHR(
        self: PhysicalDevice,
        surface: SurfaceKHR,
    ) !c.VkSurfaceCapabilitiesKHR {
        var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        try vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(
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
        try vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR.?(
            self.handle(),
            surface,
            &format_count,
            null,
        ));

        const formats = try allocator.alloc(
            c.VkSurfaceFormatKHR,
            format_count,
        );
        try vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR.?(
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
        try vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR.?(
            self.handle(),
            surface,
            &mode_count,
            null,
        ));

        const modes = try allocator.alloc(
            c.VkPresentModeKHR,
            mode_count,
        );
        try vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR.?(
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
        try vkCheck(c.vkCreateDevice.?(
            self.handle(),
            device_info,
            allocator,
            @ptrCast(&device),
        ));

        c.volkLoadDevice(device.handle());
        return device;
    }
};

pub const Device = *align(@alignOf(c.VkDevice)) opaque {
    pub inline fn handle(self: Device) c.VkDevice {
        return @ptrCast(self);
    }

    pub inline fn getQueue(self: Device, family_index: u32, index: u32) !Queue {
        var queue: Queue = undefined;
        c.vkGetDeviceQueue.?(self.handle(), family_index, index, @ptrCast(&queue));
        return queue;
    }

    pub inline fn createSwapchainKHR(
        self: Device,
        info: *const c.VkSwapchainCreateInfoKHR,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !SwapchainKHR {
        var swapchain: SwapchainKHR = undefined;
        try vkCheck(c.vkCreateSwapchainKHR.?(
            self.handle(),
            info,
            allocator,
            &swapchain,
        ));
        return swapchain;
    }

    pub inline fn destroySwapchainKHR(
        self: Device,
        swapchain: SwapchainKHR,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        c.vkDestroySwapchainKHR.?(self.handle(), swapchain, allocator);
    }

    pub inline fn createShaderModule(
        self: Device,
        info: *const c.VkShaderModuleCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !ShaderModule {
        var mod: ShaderModule = undefined;
        try vkCheck(c.vkCreateShaderModule.?(
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
        c.vkDestroyShaderModule.?(self.handle(), shader, allocator);
    }

    pub inline fn createPipelineLayout(
        self: Device,
        info: *const c.VkPipelineLayoutCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !PipelineLayout {
        var layout: PipelineLayout = undefined;
        try vkCheck(c.vkCreatePipelineLayout.?(
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
        c.vkDestroyPipelineLayout.?(self.handle(), layout, allocator);
    }

    pub inline fn createComputePipelines(
        self: Device,
        cache: ?PipelineCache,
        infos: []const c.VkComputePipelineCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Pipeline {
        var pipeline: Pipeline = undefined;
        try vkCheck(c.vkCreateComputePipelines.?(
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
        try vkCheck(c.vkCreateGraphicsPipelines.?(
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
        c.vkDestroyPipeline.?(self.handle(), pipeline, allocator);
    }

    pub inline fn createImageView(
        self: Device,
        create_info: *const c.VkImageViewCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !ImageView {
        var view: ImageView = undefined;
        try vkCheck(c.vkCreateImageView.?(
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
        c.vkDestroyImageView.?(self.handle(), image_view, allocator);
    }

    pub inline fn getSwapchainImageCount(self: Device, swapchain: SwapchainKHR) !u32 {
        var image_count: u32 = undefined;
        try vkCheck(c.vkGetSwapchainImagesKHR.?(
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

        try vkCheck(c.vkGetSwapchainImagesKHR.?(
            self.handle(),
            swapchain,
            &image_count,
            null,
        ));

        const swapchain_images = try allocator.alloc(
            Image,
            image_count,
        );

        try vkCheck(c.vkGetSwapchainImagesKHR.?(
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

        try vkCheck(c.vkGetSwapchainImagesKHR.?(
            self.handle(),
            swapchain,
            &image_count,
            null,
        ));

        try list.ensureUnusedCapacity(image_count);
        try vkCheck(c.vkGetSwapchainImagesKHR.?(
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
        try vkCheck(c.vkCreateDescriptorPool.?(
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
        return result(c.vkResetDescriptorPool.?(
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
        c.vkDestroyDescriptorPool.?(
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
        return result(c.vkAllocateDescriptorSets.?(
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
        try vkCheck(c.vkCreateCommandPool.?(
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
        try vkCheck(c.vkAllocateCommandBuffers.?(
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
        try vkCheck(c.vkCreateDescriptorSetLayout.?(
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
        c.vkDestroyDescriptorSetLayout.?(self.handle(), layout, allocator);
    }

    pub inline fn updateDescriptorSets(
        self: Device,
        descriptor_writes: []const c.VkWriteDescriptorSet,
        descriptor_copies: []const c.VkCopyDescriptorSet,
    ) void {
        c.vkUpdateDescriptorSets.?(
            self.handle(),
            @intCast(descriptor_writes.len),
            @ptrCast(descriptor_writes.ptr),
            @intCast(descriptor_copies.len),
            @ptrCast(descriptor_copies.ptr),
        );
    }

    pub inline fn waitIdle(self: Device) Result {
        return result(c.vkDeviceWaitIdle.?(self.handle()));
    }

    pub inline fn destroyCommandPool(
        self: Device,
        command_pool: CommandPool,
        allocator: ?*const c.VkAllocationCallbacks,
    ) void {
        c.vkDestroyCommandPool.?(self.handle(), command_pool, allocator);
    }

    pub inline fn createFence(
        self: Device,
        info: *const c.VkFenceCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Fence {
        var fence: Fence = undefined;
        try vkCheck(c.vkCreateFence.?(
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
        c.vkDestroyFence.?(self.handle(), fence, allocator);
    }

    pub inline fn createSemaphore(
        self: Device,
        info: *const c.VkSemaphoreCreateInfo,
        allocator: ?*const c.VkAllocationCallbacks,
    ) !Semaphore {
        var semaphore: Semaphore = undefined;
        try vkCheck(c.vkCreateSemaphore.?(
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
        c.vkDestroySemaphore.?(self.handle(), semaphore, allocator);
    }

    pub inline fn waitForFences(
        self: Device,
        fences: []const Fence,
        wait_all: bool,
        timeout: u64,
    ) Result {
        return result(c.vkWaitForFences.?(
            self.handle(),
            @intCast(fences.len),
            @ptrCast(fences.ptr),
            vkBool32(wait_all),
            timeout,
        ));
    }

    pub inline fn resetFences(self: Device, fences: []const Fence) Result {
        return result(c.vkResetFences.?(
            self.handle(),
            @intCast(fences.len),
            @ptrCast(fences.ptr),
        ));
    }

    pub inline fn getBufferDeviceAddress(
        self: Device,
        info: *const c.VkBufferDeviceAddressInfo,
    ) c.VkDeviceAddress {
        return c.vkGetBufferDeviceAddress.?(self.handle(), info);
    }

    pub inline fn acquireNextImageKHR(
        self: Device,
        swapchain: SwapchainKHR,
        timeout: u64,
        semaphore: ?Semaphore,
        fence: ?Fence,
    ) !u32 {
        var index: u32 = undefined;
        try vkCheck(c.vkAcquireNextImageKHR.?(
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
        c.vkDestroyDevice.?(self.handle(), allocator);
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
        return result(c.vkQueueSubmit.?(
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
        return result(c.vkQueueSubmit2KHR.?(
            self.handle(),
            @intCast(info.len),
            @ptrCast(info.ptr),
            if (fence) |f| f else null,
        ));
    }

    pub inline fn waitIdle(self: Queue) Result {
        return result(c.vkQueueWaitIdle.?(self.handle()));
    }

    pub inline fn bindSparse(
        self: Queue,
        info: []const c.VkBindSparseInfo,
        fence: ?Fence,
    ) Result {
        return result(c.vkQueueBindSparse.?(
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
        return result(c.vkQueuePresentKHR.?(self.handle(), info));
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
        return result(c.vkBeginCommandBuffer.?(self.handle(), info));
    }

    pub inline fn reset(
        self: CommandBuffer,
        flags: c.VkCommandBufferResetFlags,
    ) Result {
        return result(c.vkResetCommandBuffer.?(self.handle(), flags));
    }

    pub inline fn pipelineBarrier2(
        self: CommandBuffer,
        info: *const c.VkDependencyInfo,
    ) void {
        c.vkCmdPipelineBarrier2KHR.?(self.handle(), info);
    }

    pub inline fn clearColorImage(
        self: CommandBuffer,
        image: Image,
        image_layout: c.VkImageLayout,
        color: *const c.VkClearColorValue,
        ranges: []const c.VkImageSubresourceRange,
    ) void {
        c.vkCmdClearColorImage.?(
            self.handle(),
            image,
            image_layout,
            color,
            @intCast(ranges.len),
            @ptrCast(ranges.ptr),
        );
    }

    pub inline fn end(self: CommandBuffer) Result {
        return result(c.vkEndCommandBuffer.?(self.handle()));
    }

    pub inline fn copyBuffer(
        self: CommandBuffer,
        src: Buffer,
        dst: Buffer,
        regions: []const c.VkBufferCopy,
    ) void {
        c.vkCmdCopyBuffer.?(
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
        c.vkCmdBlitImage2KHR.?(self.handle(), info);
    }

    pub inline fn bindPipeline(
        self: CommandBuffer,
        bind_point: c.VkPipelineBindPoint,
        pipeline: Pipeline,
    ) void {
        c.vkCmdBindPipeline.?(self.handle(), bind_point, pipeline);
    }

    pub inline fn bindIndexBuffer(
        self: CommandBuffer,
        buffer: Buffer,
        offset: c.VkDeviceSize,
        index_type: c.VkIndexType,
    ) void {
        c.vkCmdBindIndexBuffer.?(self.handle(), buffer, offset, index_type);
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
        c.vkCmdBindDescriptorSets.?(
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
        c.vkCmdSetViewport.?(
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
        c.vkCmdSetScissor.?(
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
        c.vkCmdDispatch.?(
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
        c.vkCmdBeginRenderingKHR.?(self.handle(), info);
    }

    pub inline fn draw(
        self: CommandBuffer,
        vertex_count: u32,
        instance_count: u32,
        first_vertex: u32,
        first_instance: u32,
    ) void {
        c.vkCmdDraw.?(
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
        c.vkCmdDrawIndexed.?(
            self.handle(),
            index_count,
            instance_count,
            first_index,
            vertex_offset,
            first_instance,
        );
    }

    pub inline fn endRendering(self: CommandBuffer) void {
        c.vkCmdEndRenderingKHR.?(self.handle());
    }

    pub inline fn pushConstants(
        self: CommandBuffer,
        layout: PipelineLayout,
        stage_flags: c.VkShaderStageFlags,
        offset: u32,
        size: u32,
        values: ?*const anyopaque,
    ) void {
        c.vkCmdPushConstants.?(
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
