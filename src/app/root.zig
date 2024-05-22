const std = @import("std");
const AppConfig = @import("gargoyle").AppConfig;

comptime {
    const root = @import("app_root");
    if (!@hasDecl(root, "App")) @compileError("expected to find `pub const App = struct...;` in root file");

    _ = Export(root.App);
}

// TODO seperate functions for interface validation and export
fn Export(comptime T: type) type {
    // if (@typeInfo(T).Struct.layout != .@"extern") {
    //     @compileError("App Type must be marked extern");
    // }

    return struct {
        export fn appCreate() callconv(.C) *T {
            assertDecl(T, "create", fn (std.mem.Allocator) anyerror!T);
            const allocator = std.heap.c_allocator;
            const self = allocator.create(T) catch @panic("oom");
            self.* = T.create(allocator) catch |err| std.debug.panic("error on app create: {}\n", .{err});
            return self;
        }
        export fn appInit(self: *T, out_config: *AppConfig) callconv(.C) u32 {
            assertDecl(T, "init", fn (*T, *AppConfig) anyerror!void);
            return if (self.init(out_config)) 0 else |err| @intFromError(err);
        }
        export fn appReload(self: *T) callconv(.C) u32 {
            assertDecl(T, "reload", fn (*T) anyerror!void);
            return if (self.reload()) 0 else |err| @intFromError(err);
        }
        export fn appUpdate(self: *T, dt: f32) callconv(.C) u32 {
            assertDecl(T, "update", fn (*T, f32) anyerror!void);
            return if (self.update(dt)) 0 else |err| @intFromError(err);
        }
        export fn appFixedUpdate(self: *T, dt: f32) callconv(.C) u32 {
            assertDecl(T, "fixedUpdate", fn (*T, f32) anyerror!void);
            return if (self.fixedUpdate(dt)) 0 else |err| @intFromError(err);
        }
        export fn appOnGui(self: *T) callconv(.C) u32 {
            assertDecl(T, "onGui", fn (*T) anyerror!void);
            return if (self.onGui()) 0 else |err| @intFromError(err);
        }
        export fn appDeinit(self: *T) callconv(.C) void {
            assertDecl(T, "deinit", fn (*T) void);
            self.deinit();
        }
        export fn appDestroy(self: *T) callconv(.C) void {
            const allocator = std.heap.c_allocator;
            allocator.destroy(self);
        }
    };
}

fn assertDecl(comptime T: anytype, comptime name: []const u8, comptime Decl: type) void {
    if (!@hasDecl(T, name)) @compileError("App missing declaration: " ++ @typeName(Decl));
    const FoundDecl = @TypeOf(@field(T, name));
    if (FoundDecl != Decl) @compileError("App field '" ++ name ++ "'\n\texpected type: " ++ @typeName(Decl) ++ "\n\t   found type: " ++ @typeName(FoundDecl));
}
