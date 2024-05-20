const std = @import("std");
const c = @import("../../c.zig");
const vk = @import("vulkan.zig");
const common = @import("common.zig");
const CString = common.CString;

const PhysicalDevice = @This();

pub const Suitable = enum {
    yes,
    partial,
    no,
};

pub const PreferredDeviceType = enum(i32) {
    other = 0,
    integrated = 1,
    discrete = 2,
    virtual_gpu = 3,
    cpu = 4,
};

pub const DeviceSelectionMode = enum {
    partially_and_fully_suitable,
    only_fully_suitable,
};

name: CString,
physical_device: vk.PhysicalDevice,
surface: vk.SurfaceKHR,
features: c.VkPhysicalDeviceFeatures = .{},
properties: c.VkPhysicalDeviceProperties = .{},
memory_properties: c.VkPhysicalDeviceMemoryProperties = .{},

has_dedicated_compute_queue: bool,
has_dedicated_transfer_queue: bool,

has_seperate_compute_queue: bool,
has_seperate_transfer_queue: bool,

instance_version: u32 = c.VK_API_VERSION_1_0,
extensions_to_enable: []const CString,
available_extensions: []const CString,
queue_families: []const c.VkQueueFamilyProperties,
defer_surface_initialization: bool = false,
properties2_ext_enabled: bool = false,
suitable: Suitable = .yes,

// detail::GenericFeatureChain extended_features_chain;
//
// bool enable_features_node_if_present(detail::GenericFeaturesPNextNode const& node);

// fn getQueueFamilies() []const c.VkQueueFamilyProperties {}
// fn getExtensions() string {}
// fn getAvailableExtensions() string {}
// fn isExtensionPresent() bool {}
// fn enableExtensionIfPresent(ext: string) bool {}
// fn enableExtensionsIfPresent(ext: []const CString) bool {}
// fn enableFeaturesIfPresent(features_to_enable: *const c.VkPhysicalDeviceFeatures) bool {}

//
// // If the features from the provided features struct are all present, make all of the features be enable on the
// // device. Returns true all of the features are present.
// template <typename T> bool enable_extension_features_if_present(T const& features) {
//     return enable_features_node_if_present(detail::GenericFeaturesPNextNode(features));
// }
//
//

pub fn create(
    allocator: std.mem.Allocator,
    selection: DeviceSelectionMode,
    instance_info: *const struct {
        instance: vk.Instance,
        surface: vk.SurfaceKHR,
        version: u32 = c.VK_API_VERSION_1_0,
        headless: bool = false,
        properties2_ext_enabled: bool = false,
    },
    criteria: *const struct {
        name: CString,
        preferred_type: PreferredDeviceType = .discrete,
        allow_any_type: bool = true,
        require_present: bool = true,
        require_dedicated_transfer_queue: bool = false,
        require_dedicated_compute_queue: bool = false,
        require_separate_transfer_queue: bool = false,
        require_separate_compute_queue: bool = false,
        required_mem_size: c.VkDeviceSize = 0,
        desired_mem_size: c.VkDeviceSize = 0,

        required_extensions: []const CString,
        desired_extensions: []const CString,

        required_version: u32 = c.VK_API_VERSION_1_0,
        desired_version: u32 = c.VK_API_VERSION_1_0,

        required_features: c.VkPhysicalDeviceFeatures = .{},
        required_features2: c.VkPhysicalDeviceFeatures2 = .{},

        // detail::GenericFeatureChain extended_features_chain;
        defer_surface_initialization: bool = false,
        use_first_gpu_unconditionally: bool = false,
        enable_portability_subset: bool = true,
    },
) !PhysicalDevice {
    _ = selection; // autofix

    if (criteria.require_present and !criteria.defer_surface_initialization) {
        if (instance_info.surface.handle == null) {
            return error.NoSurfaceProvided;
        }
    }
    const vk_physical_devices =
        try instance_info.instance.enumeratePhysicalDevices(allocator);

    if (criteria.use_first_gpu_unconditionally and vk_physical_devices.len > 0) {
        // PhysicalDevice physical_device;;;; = populate_device_details(vk_physical_devices[0], criteria.extended_features_chain);
        // fill_out_phys_dev_with_criteria(physical_device);
        // return std:;;;;;;:vector<PhysicalDevice>{ physical_device };
    }
    // #if !defined(NDEBUG)
    //     // Validation
    //     for (const auto& node : criteria.extended_features_chain.nodes) {
    //         assert(node.sType != static_cast<VkStructureType>(0) &&
    //                "Features struct sType must be filled with the struct's "
    //                "corresponding VkStructureType enum");
    //         assert(node.sType != VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 &&
    //                "Do not pass VkPhysicalDeviceFeatures2 as a required extension feature structure. An "
    //                "instance of this is managed internally for selection criteria and device creation.");
    //     }
    // #endif
    //
    //
    //     auto fill_out_phys_dev_with_criteria = [&](PhysicalDevice& phys_dev) {
    //         phys_dev.features = criteria.required_features;
    //         phys_dev.extended_features_chain = criteria.extended_features_chain;
    //         bool portability_ext_available = false;
    //         for (const auto& ext : phys_dev.available_extensions)
    //             if (criteria.enable_portability_subset && ext == "VK_KHR_portability_subset")
    //                 portability_ext_available = true;
    //
    //         auto desired_extensions_supported =
    //             detail::check_device_extension_support(phys_dev.available_extensions, criteria.desired_extensions);
    //
    //         phys_dev.extensions_to_enable.clear();
    //         phys_dev.extensions_to_enable.insert(
    //             phys_dev.extensions_to_enable.end(), criteria.required_extensions.begin(), criteria.required_extensions.end());
    //         phys_dev.extensions_to_enable.insert(
    //             phys_dev.extensions_to_enable.end(), desired_extensions_supported.begin(), desired_extensions_supported.end());
    //         if (portability_ext_available) {
    //             phys_dev.extensions_to_enable.push_back("VK_KHR_portability_subset");
    //         }
    //     };
    //
    //     // if this option is set, always return only the first physical device found
    //     if (criteria.use_first_gpu_unconditionally && vk_physical_devices.size() > 0) {
    //         PhysicalDevice physical_device = populate_device_details(vk_physical_devices[0], criteria.extended_features_chain);
    //         fill_out_phys_dev_with_criteria(physical_device);
    //         return std::vector<PhysicalDevice>{ physical_device };
    //     }
    //
    //     // Populate their details and check their suitability
    //     std::vector<PhysicalDevice> physical_devices;
    //     for (auto& vk_physical_device : vk_physical_devices) {
    //         PhysicalDevice phys_dev = populate_device_details(vk_physical_device, criteria.extended_features_chain);
    //         phys_dev.suitable = is_device_suitable(phys_dev);
    //         if (phys_dev.suitable != PhysicalDevice::Suitable::no) {
    //             physical_devices.push_back(phys_dev);
    //         }
    //     }
    //
    //     // sort the list into fully and partially suitable devices. use stable_partition to maintain relative order
    //     const auto partition_index = std::stable_partition(physical_devices.begin(), physical_devices.end(), [](auto const& pd) {
    //         return pd.suitable == PhysicalDevice::Suitable::yes;
    //     });
    //
    //     // Remove the partially suitable elements if they aren't desired
    //     if (selection == DeviceSelectionMode::only_fully_suitable) {
    //         physical_devices.erase(partition_index, physical_devices.end());
    //     }
    //
    //     // Make the physical device ready to be used to create a Device from it
    //     for (auto& physical_device : physical_devices) {
    //         fill_out_phys_dev_with_criteria(physical_device);
    //     }
    //
    //     return physical_devices;
    //
    // auto const selected_devices = select_impl(selection);
    //
    // if (!selected_devices) return Result<PhysicalDevice>{ selected_devices.error() };
    // if (selected_devices.value().size() == 0) {
    //     return Result<PhysicalDevice>{ PhysicalDeviceError::no_suitable_device };
    // }
    //
    // return selected_devices.value().at(0);

    return std.mem.zeroes(PhysicalDevice);
}

// PhysicalDevice PhysicalDeviceSelector::populate_device_details(
//     VkPhysicalDevice vk_phys_device, detail::GenericFeatureChain const& src_extended_features_chain) const {
//     PhysicalDevice physical_device{};
//     physical_device.physical_device = vk_phys_device;
//     physical_device.surface = instance_info.surface;
//     physical_device.defer_surface_initialization = criteria.defer_surface_initialization;
//     physical_device.instance_version = instance_info.version;
//     auto queue_families = detail::get_vector_noerror<VkQueueFamilyProperties>(
//         detail::vulkan_functions().fp_vkGetPhysicalDeviceQueueFamilyProperties, vk_phys_device);
//     physical_device.queue_families = queue_families;
//
//     detail::vulkan_functions().fp_vkGetPhysicalDeviceProperties(vk_phys_device, &physical_device.properties);
//     detail::vulkan_functions().fp_vkGetPhysicalDeviceFeatures(vk_phys_device, &physical_device.features);
//     detail::vulkan_functions().fp_vkGetPhysicalDeviceMemoryProperties(vk_phys_device, &physical_device.memory_properties);
//
//     physical_device.name = physical_device.properties.deviceName;
//
//     std::vector<VkExtensionProperties> available_extensions;
//     auto available_extensions_ret = detail::get_vector<VkExtensionProperties>(
//         available_extensions, detail::vulkan_functions().fp_vkEnumerateDeviceExtensionProperties, vk_phys_device, nullptr);
//     if (available_extensions_ret != VK_SUCCESS) return physical_device;
//     for (const auto& ext : available_extensions) {
//         physical_device.available_extensions.push_back(&ext.extensionName[0]);
//     }
//
//     physical_device.properties2_ext_enabled = instance_info.properties2_ext_enabled;
//
//     auto fill_chain = src_extended_features_chain;
//
//     bool instance_is_1_1 = instance_info.version >= VKB_VK_API_VERSION_1_1;
//     if (!fill_chain.nodes.empty() && (instance_is_1_1 || instance_info.properties2_ext_enabled)) {
//         VkPhysicalDeviceFeatures2 local_features{};
//         fill_chain.chain_up(local_features);
//         // Use KHR function if not able to use the core function
//         if (instance_is_1_1) {
//             detail::vulkan_functions().fp_vkGetPhysicalDeviceFeatures2(vk_phys_device, &local_features);
//         } else {
//             detail::vulkan_functions().fp_vkGetPhysicalDeviceFeatures2KHR(vk_phys_device, &local_features);
//         }
//         physical_device.extended_features_chain = fill_chain;
//     }
//
//     return physical_device;
// }
