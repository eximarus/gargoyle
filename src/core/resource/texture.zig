pub const Format = enum {
    rgb32,
    rgb64,
    rgba32,
    rgba64,
};

// pub const VK_IMAGE_ASPECT_COLOR_BIT: c_int = 1;
// pub const VK_IMAGE_ASPECT_DEPTH_BIT: c_int = 2;
// pub const VK_IMAGE_ASPECT_STENCIL_BIT: c_int = 4;
// pub const VK_IMAGE_ASPECT_METADATA_BIT: c_int = 8;
// pub const VK_IMAGE_ASPECT_PLANE_0_BIT: c_int = 16;
// pub const VK_IMAGE_ASPECT_PLANE_1_BIT: c_int = 32;
// pub const VK_IMAGE_ASPECT_PLANE_2_BIT: c_int = 64;
// pub const VK_IMAGE_ASPECT_NONE: c_int = 0;
//
// pub const VK_IMAGE_USAGE_TRANSFER_SRC_BIT: c_int = 1;
// pub const VK_IMAGE_USAGE_TRANSFER_DST_BIT: c_int = 2;
// pub const VK_IMAGE_USAGE_SAMPLED_BIT: c_int = 4;
// pub const VK_IMAGE_USAGE_STORAGE_BIT: c_int = 8;
// pub const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT: c_int = 16;
// pub const VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT: c_int = 32;
// pub const VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT: c_int = 64;
// pub const VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT: c_int = 128;

pub const Texture = struct {
    width: u32,
    height: u32,
    format: Format,
    flags: u32,

    ptr: *anyopaque,
};
