const AppConfig = @import("app_config.zig").AppConfig;

pub const AppPtr = *opaque {};
pub const CreateFn = *const fn () callconv(.C) AppPtr;
pub const InitFn = *const fn (AppPtr, *AppConfig) callconv(.C) u32;
pub const ReloadFn = *const fn (AppPtr) callconv(.C) u32;
pub const UpdateFn = *const fn (AppPtr, f32) callconv(.C) u32;
pub const FixedUpdateFn = *const fn (AppPtr, f32) callconv(.C) u32;
pub const OnGuiFn = *const fn (AppPtr) callconv(.C) u32;
pub const DeinitFn = *const fn (AppPtr) callconv(.C) void;
pub const DestroyFn = *const fn (AppPtr) callconv(.C) void;

pub const App = struct {
    _ptr: AppPtr,
    _init: InitFn = undefined,
    _reload: ReloadFn = undefined,
    _update: UpdateFn = undefined,
    _fixedUpdate: FixedUpdateFn = undefined,
    _onGui: ReloadFn = undefined,
    _deinit: DeinitFn = undefined,

    pub inline fn init(self: *App, out_config: *AppConfig) u32 {
        return self._init(self._ptr, out_config);
    }

    pub inline fn reload(self: *App) u32 {
        return self._reload(self._ptr);
    }

    pub inline fn update(self: *App, dt: f32) u32 {
        return self._update(self._ptr, dt);
    }

    pub inline fn fixedUpdate(self: *App, dt: f32) u32 {
        return self._fixedUpdate(self._ptr, dt);
    }

    pub inline fn onGui(self: *App) u32 {
        return self._onGui(self._ptr);
    }

    pub inline fn deinit(self: *App) void {
        self._deinit(self._ptr);
    }
};
