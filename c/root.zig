pub usingnamespace @cImport({
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_vulkan.h");
    @cInclude("SDL2/SDL_syswm.h");

    @cInclude("volk.h");

    @cDefine("VMA_STATIC_VULKAN_FUNCTIONS", "0");
    @cDefine("VMA_DYNAMIC_VULKAN_FUNCTIONS", "0");
    @cInclude("vk_mem_alloc.h");

    @cInclude("stb_image.h");

    @cInclude("cgltf.h");

    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "");
    @cDefine("CIMGUI_USE_VULKAN", "");
    @cDefine("CIMGUI_USE_SDL2", "");
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
});
