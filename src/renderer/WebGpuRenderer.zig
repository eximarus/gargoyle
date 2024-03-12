const std = @import("std");
const glfw = @import("mach-glfw");
const wgpu = @import("mach-gpu");
const shader = @import("shader.zig");
const builtin = @import("builtin");
const target = builtin.target;
const metal = @import("metal.zig");

const Window = @import("../window.zig");

const math = @import("../math.zig");
const camera = @import("camera.zig");
const Camera = camera.Camera;
const OrthoCamera = camera.OrthoCamera;
const DefaultShader = shader.DefaultShader;

const WebGpuRenderer = @This();

// render data
indices: []const u32,
vertices: []const DefaultShader.Vertex,
cam: *const Camera,

// renderer context
instance: *wgpu.Instance,
adapter: *wgpu.Adapter,
device: *wgpu.Device,
swap_chain: *wgpu.SwapChain,
device_lost_userdata: DeviceLostUserData = undefined,

// pipeline context
pipeline: *wgpu.RenderPipeline,
vertex_buffer_layout: *const wgpu.VertexBufferLayout,
vertex_buffer: *wgpu.Buffer,
index_buffer: *wgpu.Buffer,
uniform_buffer: *wgpu.Buffer,
bind_group_layout: *wgpu.BindGroupLayout,
bind_group: *wgpu.BindGroup,

const RequestAdapterResponse = struct {
    status: wgpu.RequestAdapterStatus,
    adapter: ?*wgpu.Adapter,
    message: ?[*:0]const u8,
};

inline fn requestAdapterCallback(
    context: *RequestAdapterResponse,
    status: wgpu.RequestAdapterStatus,
    adapter: ?*wgpu.Adapter,
    message: ?[*:0]const u8,
) void {
    context.* = RequestAdapterResponse{
        .status = status,
        .adapter = adapter,
        .message = message,
    };
}

inline fn uncapturedErrorCallback(
    _: void,
    typ: wgpu.ErrorType,
    message: [*:0]const u8,
) void {
    std.log.err(
        "Uncaptured device error.\ntype: {},\nerror: {s}\n",
        .{ typ, message },
    );
    @panic("");
}

const RequestDeviceResponse = struct {
    status: wgpu.RequestDeviceStatus,
    device: ?*wgpu.Device,
    message: ?[*:0]const u8,
};

inline fn requestDeviceCallback(
    context: *RequestDeviceResponse,
    status: wgpu.RequestDeviceStatus,
    device: ?*wgpu.Device,
    message: ?[*:0]const u8,
) void {
    context.* = RequestDeviceResponse{
        .status = status,
        .device = device,
        .message = message,
    };
}

const DeviceLostUserData = struct {
    reason: wgpu.Device.LostReason,
    message: [*:0]const u8,
};

fn deviceLostCallback(
    reason: wgpu.Device.LostReason,
    message: [*:0]const u8,
    userdata: ?*anyopaque,
) callconv(.C) void {
    const ctx = @as(*DeviceLostUserData, @ptrCast(@alignCast(userdata)));
    ctx.* = DeviceLostUserData{
        .reason = reason,
        .message = message,
    };
}

const WebGpuError = error{
    NotInitialized,
    AdapterNotCreated,
    DeviceNotCreated,
    NoNextSwapChainTexture,
};

fn createSurface(window: *const glfw.Window, instance: *wgpu.Instance) *wgpu.Surface {
    return switch (glfw.getPlatform()) {
        .win32 => if (target.os.tag == .windows) instance.createSurface(&.{
            .next_in_chain = .{
                .from_windows_hwnd = &.{
                    .hinstance = std.os.windows.kernel32.GetModuleHandleW(null).?,
                    .hwnd = glfw.Native(.{ .win32 = true })
                        .getWin32Window(window.*),
                },
            },
        }) else unreachable,
        .cocoa => if (target.isDarwin()) instance.createSurface(&.{
            .next_in_chain = .{
                .from_metal_layer = &.{
                    .layer = metal.getMetalLayer(window),
                },
            },
        }) else unreachable,
        .x11 => if (target.os.tag == .linux) instance.createSurface(&.{
            .next_in_chain = .{
                .from_xlib_window = &.{
                    .display = glfw.Native(.{ .x11 = true }).getX11Display(),
                    .window = glfw.Native(.{ .x11 = true })
                        .getX11Window(window.*),
                },
            },
        }) else unreachable,
        .wayland => if (target.os.tag == .linux) instance.createSurface(&.{
            .next_in_chain = .{
                .from_wayland_surface = &.{
                    .display = glfw.Native(.{ .wayland = true }).getWaylandDisplay(),
                    .surface = glfw.Native(.{ .wayland = true })
                        .getWaylandWindow(window.*),
                },
            },
        }) else unreachable,
        else => unreachable,
    };
}

pub fn init(window: *const glfw.Window) !WebGpuRenderer {
    var renderer: WebGpuRenderer = undefined;

    renderer.vertices = &[_]DefaultShader.Vertex{
        DefaultShader.Vertex{
            .pos = .{ .x = -0.5, .y = -0.5, .z = 0.0 },
            .color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 },
            .tex_coord = .{ .x = 1.0, .y = 0.0 },
        },
        DefaultShader.Vertex{
            .pos = .{ .x = 0.5, .y = -0.5, .z = 0.0 },
            .color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 },
            .tex_coord = .{ .x = 0.0, .y = 0.0 },
        },
        DefaultShader.Vertex{
            .pos = .{ .x = 0.5, .y = 0.5, .z = 0.0 },
            .color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 },
            .tex_coord = .{ .x = 0.0, .y = 1.0 },
        },
        DefaultShader.Vertex{
            .pos = .{ .x = -0.5, .y = 0.5, .z = 0.0 },
            .color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 },
            .tex_coord = .{ .x = 0.0, .y = 1.0 },
        },
    };
    const vertices = renderer.vertices;

    renderer.indices = &[_]u32{ 0, 1, 2, 0, 2, 3 };
    const indices = renderer.indices;

    renderer.cam = &Camera{
        .ortho = OrthoCamera.init(-1.6, 1.6, -0.9, 0.9, -1.0, 1.0),
    };

    const instance = wgpu.createInstance(&.{}) orelse {
        std.log.err("Could not initialize WebGPU!", .{});
        return WebGpuError.NotInitialized;
    };
    errdefer instance.release();

    const surface = createSurface(window, instance);
    var adapter_resp: RequestAdapterResponse = undefined;
    instance.requestAdapter(&.{
        .compatible_surface = surface,
    }, &adapter_resp, requestAdapterCallback);

    if (adapter_resp.status != .success) {
        std.log.err("failed to create GPU adapter: {s}\n", .{adapter_resp.message.?});
        return WebGpuError.AdapterNotCreated;
    }

    const adapter = adapter_resp.adapter.?;
    errdefer adapter.release();

    var device_resp: RequestDeviceResponse = undefined;
    adapter.requestDevice(
        &.{
            .label = "My Device",
            .default_queue = .{
                .label = "The default queue",
            },
            .device_lost_callback = deviceLostCallback,
            .device_lost_userdata = &renderer.device_lost_userdata,
            // .required_limits = &.{}, // TODO limits?
        },
        &device_resp,
        requestDeviceCallback,
    );

    if (device_resp.status != .success) {
        std.log.err("failed to create GPU device: {s}\n", .{device_resp.message.?});
        return WebGpuError.DeviceNotCreated;
    }

    const device = device_resp.device.?;
    device.setUncapturedErrorCallback({}, uncapturedErrorCallback);

    const swap_chain = device.createSwapChain(surface, &.{
        .width = window.getSize().width,
        .height = window.getSize().height,
        .usage = .{
            .render_attachment = true,
        },
        .format = .bgra8_unorm,
        .present_mode = .fifo,
    });
    errdefer swap_chain.release();

    const vs_module = device.createShaderModuleWGSL(
        null,
        @embedFile("shaders/vs.wgsl"),
    );
    const fs_module = device.createShaderModuleWGSL(
        null,
        @embedFile("shaders/fs.wgsl"),
    );

    renderer.vertex_buffer_layout = &DefaultShader.makeVertexBufferLayout();
    const vertex_buffer_layout = renderer.vertex_buffer_layout;

    const vertex_buffer = DefaultShader.createVertexBuffer(device, vertices);
    const index_buffer = DefaultShader.createIndexBuffer(device, indices);
    const uniform_buffer = DefaultShader.createUniformBuffer(
        device,
        &renderer.cam.calcViewProjMat(),
    );

    const bind_group_layout = device.createBindGroupLayout(&.{
        .entry_count = 1,
        .entries = &[_]wgpu.BindGroupLayout.Entry{
            wgpu.BindGroupLayout.Entry.buffer(
                0,
                .{ .vertex = true },
                .uniform,
                false,
                @sizeOf(math.Mat),
            ),
        },
    });

    const pipeline = device.createRenderPipeline(
        &.{
            .vertex = .{
                .module = vs_module,
                .entry_point = "main",
                .buffer_count = 1,
                .buffers = &[_]wgpu.VertexBufferLayout{vertex_buffer_layout.*},
            },
            .fragment = &.{
                .module = fs_module,
                .entry_point = "main",
                .target_count = 1,
                .targets = &[_]wgpu.ColorTargetState{
                    .{
                        .format = .bgra8_unorm,
                        .blend = &.{
                            .color = .{
                                .src_factor = .src_alpha,
                                .dst_factor = .one_minus_src_alpha,
                                .operation = .add,
                            },
                            .alpha = .{
                                .src_factor = .zero,
                                .dst_factor = .one,
                                .operation = .add,
                            },
                        },
                    },
                },
            },
            .layout = device.createPipelineLayout(&.{
                .bind_group_layout_count = 1,
                .bind_group_layouts = &[_]*wgpu.BindGroupLayout{
                    bind_group_layout,
                },
            }),
        },
    );
    errdefer pipeline.release();

    const bind_group = device.createBindGroup(&.{
        .layout = bind_group_layout,
        .entry_count = 1,
        .entries = &[_]wgpu.BindGroup.Entry{
            wgpu.BindGroup.Entry.buffer(
                0,
                uniform_buffer,
                0,
                @sizeOf(math.Mat),
            ),
        },
    });

    vs_module.release();
    fs_module.release();

    renderer.instance = instance;
    renderer.adapter = adapter;
    renderer.device = device;
    renderer.swap_chain = swap_chain;

    renderer.pipeline = pipeline;
    renderer.vertex_buffer = vertex_buffer;
    renderer.index_buffer = index_buffer;
    renderer.bind_group_layout = bind_group_layout;
    renderer.uniform_buffer = uniform_buffer;
    renderer.bind_group = bind_group;

    return renderer;
}

pub fn draw(self: *const WebGpuRenderer) !void {
    const next_texture = self.swap_chain.getCurrentTextureView() orelse {
        std.log.err("Cannot acquire next swap chain texture", .{});
        return WebGpuError.NoNextSwapChainTexture;
    };

    const encoder = self.device.createCommandEncoder(&.{
        .label = "Command Encoder",
    });

    const render_pass = encoder.beginRenderPass(&.{
        .color_attachment_count = 1,
        .color_attachments = &[_]wgpu.RenderPassColorAttachment{
            .{
                .view = next_texture,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ .r = 0.05, .g = 0.05, .b = 0.05, .a = 1.0 },
            },
        },
    });

    render_pass.setPipeline(self.pipeline);
    render_pass.setVertexBuffer(
        0,
        self.vertex_buffer,
        0,
        self.vertex_buffer.getSize(),
    );
    render_pass.setIndexBuffer(
        self.index_buffer,
        .uint32,
        0,
        self.index_buffer.getSize(),
    );

    render_pass.setBindGroup(0, self.bind_group, null);
    render_pass.drawIndexed(@as(u32, @intCast(self.indices.len)), 1, 0, 0, 0);
    render_pass.end();
    render_pass.release();

    next_texture.release();

    const command = encoder.finish(&.{
        .label = "Command buffer",
    });
    encoder.release();
    self.device.getQueue().submit(&.{command});
    command.release();

    self.swap_chain.present();
    self.device.tick();

    //     const view_proj_mat = self.cam.calcViewProjMat();
    //     var trans = math.identity();
    //     trans = math.translation(0.5, -0.5, 0.5);
    //     trans = math.mul(trans, math.rotationZ(@as(f32, @floatCast(glfw.getTime()))));
    //     trans = math.mul(trans, math.scaling(0.5, 0.5, 0.5));
    //
    //     DefaultShader.setViewProjection(self.shader_program, view_proj_mat);
}

pub fn deinit(self: *WebGpuRenderer) void {
    self.bind_group_layout.release();
    self.bind_group.release();
    self.uniform_buffer.release();

    self.vertex_buffer.destroy();
    self.vertex_buffer.release();

    self.index_buffer.destroy();
    self.index_buffer.release();

    self.pipeline.release();
    self.swap_chain.release();
    self.device.release();
    self.adapter.release();
    self.instance.release();
}
