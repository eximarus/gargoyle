const std = @import("std");
const c = @import("c");
const vk = @import("vulkan.zig");
const common = @import("common.zig");
const CString = common.CString;
const SystemInfo = @import("SystemInfo.zig");

const Out = struct {
    vk.Instance,
    vk.DebugUtilsMessengerEXT,
    ?*c.VkAllocationCallbacks,
};

pub fn create(
    arena: std.mem.Allocator,
    info: *const struct {
        // VkApplicationInfo
        app_name: ?CString = null,
        app_ver: u32 = 0,

        min_inst_ver: u32 = 0,
        required_api_ver: u32 = c.VK_API_VERSION_1_0,
        desired_api_ver: u32 = c.VK_API_VERSION_1_0,

        // VkInstanceCreateInfo
        layers: []const CString = &.{},
        extensions: []const CString = &.{},
        flags: c.VkInstanceCreateFlags = 0,
        pNext_elements: []const *c.VkBaseOutStructure = &.{},

        debug_callback: c.PFN_vkDebugUtilsMessengerCallbackEXT = defaultDebugCallback,
        debug_message_severity: c.VkDebugUtilsMessageSeverityFlagsEXT =
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,

        debug_message_type: c.VkDebugUtilsMessageTypeFlagsEXT =
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,

        debug_user_data_pointer: ?*anyopaque = null,

        // validation features
        disabled_validation_checks: []const c.VkValidationCheckEXT = &.{},
        enabled_validation_features: []const c.VkValidationFeatureEnableEXT = &.{},
        disabled_validation_features: []const c.VkValidationFeatureDisableEXT = &.{},

        allocation_callbacks: ?*c.VkAllocationCallbacks = null,

        request_validation_layers: bool = false,
        enable_validation_layers: bool = false,
        use_debug_messenger: bool = false,
        headless_context: bool = false,
    },
) !Out {
    const system = try SystemInfo.init(arena);

    var instance_version = c.VK_API_VERSION_1_0;
    if (info.min_inst_ver > c.VK_API_VERSION_1_0 or
        info.required_api_ver > c.VK_API_VERSION_1_0 or
        info.desired_api_ver > c.VK_API_VERSION_1_0)
    {
        instance_version = try vk.enumerateInstanceVersion();

        if (instance_version < info.min_inst_ver or
            (info.min_inst_ver == 0 and
            instance_version < info.required_api_ver))
        {
            std.log.err(
                "Required Vulkan Version: {} is unavailable.\n",
                .{info.required_api_ver},
            );
            return error.RequiredVulkanVersionUnavailable;
        }
    }

    var api_version =
        if (instance_version < c.VK_API_VERSION_1_1)
        instance_version
    else
        info.required_api_ver;

    if (info.desired_api_ver > c.VK_API_VERSION_1_0 and
        instance_version >= info.desired_api_ver)
    {
        instance_version = info.desired_api_ver;
        api_version = info.desired_api_ver;
    }

    var app_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = @ptrCast(info.app_name orelse ""),
        .applicationVersion = info.app_ver,
        .pEngineName = "gargoyle",
        .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .apiVersion = api_version,
    };

    var extensions = std.ArrayList(CString).init(arena);
    var layers = std.ArrayList(CString).init(arena);
    try extensions.appendSlice(info.extensions);
    try extensions.append(c.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME);

    if (info.debug_callback != null and
        info.use_debug_messenger and
        system.debug_utils_available)
    {
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    var portability_enumeration_support = false;
    if (@hasDecl(c, "VK_KHR_portability_enumeration")) {
        if (system.isExtensionSupported(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)) {
            try extensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);
            portability_enumeration_support = true;
        }
    }

    try common.validateExtensions(
        system.available_extensions.items,
        extensions.items,
    );

    try layers.appendSlice(info.layers);

    if (info.enable_validation_layers or (info.request_validation_layers and
        system.validation_layers_available))
    {
        try layers.append(SystemInfo.validation_layer_name);
    }

    try common.validateLayers(system.available_layers, layers.items);

    var pNext_chain = std.ArrayList(*c.VkBaseOutStructure).init(arena);

    if (info.use_debug_messenger) {
        const messenger_create_info = c.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .pNext = null,
            .messageSeverity = info.debug_message_severity,
            .messageType = info.debug_message_type,
            .pfnUserCallback = info.debug_callback,
            .pUserData = info.debug_user_data_pointer,
        };
        try pNext_chain.append(@ptrCast(@constCast(&messenger_create_info)));
    }

    if (info.enabled_validation_features.len != 0 or
        info.disabled_validation_features.len > 0)
    {
        const features = c.VkValidationFeaturesEXT{
            .sType = c.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT,
            .pNext = null,
            .enabledValidationFeatureCount = @intCast(info.enabled_validation_features.len),
            .pEnabledValidationFeatures = @ptrCast(info.enabled_validation_features.ptr),
            .disabledValidationFeatureCount = @intCast(info.disabled_validation_features.len),
            .pDisabledValidationFeatures = @ptrCast(info.disabled_validation_features.ptr),
        };
        try pNext_chain.append(@ptrCast(@constCast(&features)));
    }

    if (info.disabled_validation_checks.len != 0) {
        const checks = c.VkValidationFlagsEXT{
            .sType = c.VK_STRUCTURE_TYPE_VALIDATION_FLAGS_EXT,
            .pNext = null,
            .disabledValidationCheckCount = @intCast(info.disabled_validation_checks.len),
            .pDisabledValidationChecks = @ptrCast(info.disabled_validation_checks.ptr),
        };
        try pNext_chain.append(@ptrCast(@constCast(&checks)));
    }

    var instance_create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .flags = info.flags,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @intCast(extensions.items.len),
        .ppEnabledExtensionNames = @ptrCast(extensions.items.ptr),
        .enabledLayerCount = @intCast(layers.items.len),
        .ppEnabledLayerNames = @ptrCast(layers.items.ptr),
    };

    for (info.pNext_elements) |node| {
        std.debug.assert(node.sType != c.VK_STRUCTURE_TYPE_APPLICATION_INFO);
    }

    instance_create_info.pNext = null;
    if (info.pNext_elements.len > 0) {
        for (info.pNext_elements[0 .. info.pNext_elements.len - 1], 0..) |next, i| {
            next.pNext = info.pNext_elements[i + 1];
        }
        instance_create_info.pNext = info.pNext_elements[0];
    }

    if (@hasDecl(c, "VK_KHR_portability_enumeration")) {
        if (portability_enumeration_support) {
            instance_create_info.flags |= c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;
        }
    }

    var self = Out{
        try vk.createInstance(&instance_create_info, info.allocation_callbacks),
        null,
        info.allocation_callbacks,
    };

    if (info.use_debug_messenger) {
        self[1] = try self[0].createDebugUtilsMessengerEXT(
            &.{
                .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                .pNext = null,
                .messageSeverity = info.debug_message_severity,
                .messageType = info.debug_message_type,
                .pfnUserCallback = info.debug_callback orelse defaultDebugCallback,
                .pUserData = info.debug_user_data_pointer,
            },
            info.allocation_callbacks,
        );
    }

    return self;
}

fn defaultDebugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_type: c.VkDebugUtilsMessageTypeFlagsEXT,
    cb_data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.C) c.VkBool32 {
    _ = user_data;

    const log = std.log.scoped(.vulkan);
    const message = cb_data.*.pMessage;
    const mt = messageTypeToString(message_type);
    if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT != 0) {
        log.err(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    } else if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT != 0) {
        log.warn(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    } else if (severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT != 0) {
        log.info(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    } else {
        log.debug(
            "[{s}]\n{s}\n",
            .{ mt, message },
        );
    }

    // for (0..cb_data.*.objectCount) |i| {
    //     std.log.info("{x}\n", .{cb_data.*.pObjects[i].objectHandle});
    // }

    return c.VK_FALSE;
}

fn messageTypeToString(s: c.VkDebugUtilsMessageTypeFlagsEXT) []const u8 {
    return switch (s) {
        7 => "General | Validation | Performance",
        6 => "Validation | Performance",
        5 => "General | Performance",
        4 => "Performance",
        3 => "General | Validation",
        2 => "Validation",
        1 => "General",
        else => "Unknown",
    };
}
