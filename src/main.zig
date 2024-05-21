const std = @import("std");
const config = @import("config");
const g = @import("gargoyle");
const Engine = g.Engine;
const app_types = g.app_types;
const AppConfig = g.AppConfig;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var self_dir_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const self_dir = try std.fs.selfExeDirPath(&self_dir_buf);
    const lib_path = try std.fs.path.join(allocator, &[_][]const u8{
        self_dir,
        "..",
        "lib",
        config.app_lib_file,
    });
    defer allocator.free(lib_path);

    var lib = AppLib.init(lib_path);
    var symbols = try lib.load();
    var app = app_types.App{
        ._ptr = symbols.appCreate(),
    };

    updateAppPointers(symbols, &app);

    var app_conf: AppConfig = undefined;
    if (app.init(&app_conf) != 0) {
        @panic("App not initialized.");
    }

    var engine = try allocator.create(Engine);
    defer allocator.destroy(engine);

    engine.* = try Engine.init(allocator, &app_conf);
    defer engine.deinit();

    while (true) {
        // TODO file watcher
        var shouldReload = false;
        shouldReload = shouldReload;

        if (shouldReload) {
            try lib.unload();
            lib.recompile();
            symbols = try lib.load();
            updateAppPointers(symbols, &app);

            if (app.reload() != 0) {
                return error.AppReloadErr;
            }
        }

        if (!engine.next(&app)) {
            break;
        }
    }

    app.deinit();
    symbols.appDestroy(app._ptr);
}

pub const AppSymbols = struct {
    appCreate: app_types.CreateFn = undefined,
    appInit: app_types.InitFn = undefined,
    appReload: app_types.ReloadFn = undefined,
    appUpdate: app_types.UpdateFn = undefined,
    appFixedUpdate: app_types.FixedUpdateFn = undefined,
    appDeinit: app_types.DeinitFn = undefined,
    appDestroy: app_types.DestroyFn = undefined,
};

// TODO generic interface
const AppLib = struct {
    path: []const u8,
    _dyn_lib: ?std.DynLib = null,

    pub inline fn init(path: []const u8) AppLib {
        return AppLib{
            .path = path,
        };
    }

    pub fn load(self: *AppLib) !AppSymbols {
        if (self._dyn_lib != null) return error.AlreadyLoaded;
        self._dyn_lib = try std.DynLib.open(self.path);

        var symbols: AppSymbols = undefined;
        inline for (@typeInfo(@TypeOf(symbols)).Struct.fields) |field| {
            // const name = comptime "app" ++ &[_:0]u8{std.ascii.toUpper(field.name[0])} ++ field.name[1..];
            @field(symbols, field.name) = self._dyn_lib.?.lookup(
                field.type,
                field.name ++ &[_:0]u8{},
            ) orelse {
                std.log.err("failed to load symbol '{s}'\n", .{field.name});
                return error.MissingSymbol;
            };
        }
        return symbols;
    }

    pub fn unload(self: *AppLib) !void {
        if (self._dyn_lib) |*dyn_lib| {
            dyn_lib.close();
            self._dyn_lib = null;
        } else {
            return error.AlreadyUnloaded;
        }
    }

    pub fn recompile(self: *AppLib) void {
        _ = self;
        // TODO
        // const process_args = [_][]const u8{
        //     "zig",
        //     "build",
        //     "-Dgame_only=true",
        //     "--search-prefix",
        //     "C:/raylib/zig-out",
        // };
        // var build_process = std.ChildProcess.init(&process_args, allocator);
        // try build_process.spawn();
        // const term = try build_process.wait();
        // switch (term) {
        //     .Exited => |exited| {
        //         if (exited == 2) return error.RecompileFail;
        //     },
        //     else => return
        // }
    }
};

inline fn updateAppPointers(symbols: AppSymbols, app: *app_types.App) void {
    app._init = symbols.appInit;
    app._fixedUpdate = symbols.appFixedUpdate;
    app._update = symbols.appUpdate;
    app._reload = symbols.appReload;
    app._deinit = symbols.appDeinit;
}
