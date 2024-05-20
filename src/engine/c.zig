pub usingnamespace @cImport({
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL.h");
    @cInclude("SDL_vulkan.h");
    @cInclude("SDL_syswm.h");

    @cInclude("volk.h");

    @cDefine("VMA_STATIC_VULKAN_FUNCTIONS", "0");
    @cDefine("VMA_DYNAMIC_VULKAN_FUNCTIONS", "0");
    @cInclude("vk_mem_alloc.h");

    @cInclude("stb_image.h");

    // @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "");
    // @cInclude("cimgui.h");
    // @cInclude("cimgui_impl.h");
});
