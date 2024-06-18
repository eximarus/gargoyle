const std = @import("std");
const c = @import("c");

pub const EventHandler = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        onQuit: *const fn (ctx: *anyopaque) void,
        onWindowResize: *const fn (ctx: *anyopaque, width: u32, height: u32) void,
        onWindowMinimized: *const fn (ctx: *anyopaque) void,
        onWindowRestored: *const fn (ctx: *anyopaque) void,
    };

    pub inline fn onWindowMinimized(self: EventHandler) void {
        self.vtable.onWindowMinimized(self.ptr);
    }
    pub inline fn onWindowRestored(self: EventHandler) void {
        self.vtable.onWindowRestored(self.ptr);
    }
    pub inline fn onQuit(self: EventHandler) void {
        self.vtable.onQuit(self.ptr);
    }
    pub inline fn onWindowResize(self: EventHandler, width: u32, height: u32) void {
        self.vtable.onWindowResize(self.ptr, width, height);
    }
};

pub fn poll(handler: EventHandler) void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_QUIT => handler.onQuit(),
            c.SDL_WINDOWEVENT => {
                switch (event.window.event) {
                    c.SDL_WINDOWEVENT_SIZE_CHANGED => {
                        handler.onWindowResize(
                            @intCast(event.window.data1),
                            @intCast(event.window.data2),
                        );
                    },
                    c.SDL_WINDOWEVENT_MINIMIZED => {
                        handler.onWindowMinimized();
                    },
                    c.SDL_WINDOWEVENT_RESTORED => {
                        handler.onWindowRestored();
                    },
                    else => {},
                }
            },
            else => {},
        }
        _ = c.ImGui_ImplSDL2_ProcessEvent(&event);
    }
}
