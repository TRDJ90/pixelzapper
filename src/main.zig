const std = @import("std");

const c = @cImport({
    @cInclude("emscripten.h");
    @cInclude("emscripten/html5.h");
    @cInclude("emscripten/html5_webgpu.h");
    @cInclude("webgpu/webgpu.h");
});

pub const std_options = std.Options{
    .logFn = log,
};

const WGPUContext = struct {
    instance: c.WGPUInstance = null,
    device: c.WGPUDevice = null,
    queue: c.WGPUQueue = null,
    swapchain: c.WGPUSwapChain = null,
    pipeline: c.WGPURenderPipeline = null,
};

const Mesh = struct {
    vertex_buffer: c.WGPUBuffer,
    index_buffer: c.WGPUBuffer,
};

var wgpu: WGPUContext = undefined;
var mesh: Mesh = undefined;

var canvas_width: i32 = 0;
var canvas_height: i32 = 0;

const wgsl_triangle =
    \\  /* attribute/uniform decls */
    \\
    \\  struct VertexIn {
    \\      @location(0) position : vec2<f32>,
    \\      @location(1) color : vec3<f32>,
    \\  };
    \\  struct VertexOut {
    \\      @location(0) color : vec3<f32>,
    \\      @builtin(position) position : vec4<f32>,
    \\  };
    \\
    \\  @vertex
    \\  fn vs_main(input : VertexIn) -> VertexOut {
    \\      var output : VertexOut;
    \\      output.position = vec4<f32>(input.position, 1.0, 1.0);
    \\      output.color = input.color;
    \\      return output;
    \\  }
    \\
    \\  /* fragment shader */
    \\
    \\  @fragment
    \\  fn fs_main(@location(0) color : vec3<f32>) -> @location(0) vec4<f32> {
    \\      return vec4<f32>(color, 1.0);
    \\  }
;

pub fn main() !void {
    wgpu.instance = c.wgpuCreateInstance(null);
    wgpu.device = c.emscripten_webgpu_get_device();
    wgpu.queue = c.wgpuDeviceGetQueue(wgpu.device);

    // _ = resize(0, null, null);

    // Create triangle shader
    const shader = c.WGPUShaderModuleWGSLDescriptor{
        .chain = .{ .sType = c.WGPUSType_ShaderModuleWGSLDescriptor },
        .code = wgsl_triangle,
    };

    const shader_triangle = c.wgpuDeviceCreateShaderModule(wgpu.device, &c.WGPUShaderModuleDescriptor{
        .nextInChain = @ptrCast(&shader),
        .label = "triangle",
    });

    // Describe buffer layouts
    const vertex_attributes = [2]c.WGPUVertexAttribute{
        .{
            .format = c.WGPUVertexFormat_Float32x2,
            .offset = 0,
            .shaderLocation = 0,
        },
        .{
            .format = c.WGPUVertexFormat_Float32x3,
            .offset = 2 * @sizeOf(f32),
            .shaderLocation = 1,
        },
    };

    const vertex_buffer_layout = c.WGPUVertexBufferLayout{
        .arrayStride = 5 * @sizeOf(f32),
        .attributeCount = 2,
        .attributes = &vertex_attributes,
    };

    // Create pipeline
    const pipeline_desc: c.WGPURenderPipelineDescriptor = .{
        .primitive = .{
            .frontFace = c.WGPUFrontFace_CCW,
            .cullMode = c.WGPUCullMode_None,
            .topology = c.WGPUPrimitiveTopology_TriangleList,
            .stripIndexFormat = c.WGPUIndexFormat_Undefined,
        },
        .vertex = .{
            .module = shader_triangle,
            .entryPoint = "vs_main",
            .bufferCount = 1,
            .buffers = &vertex_buffer_layout,
        },
        .fragment = &c.WGPUFragmentState{
            .module = shader_triangle,
            .entryPoint = "fs_main",
            .targetCount = 1,
            .targets = &c.WGPUColorTargetState{
                .format = c.WGPUTextureFormat_BGRA8Unorm,
                .writeMask = c.WGPUColorWriteMask_All,
                .blend = &c.WGPUBlendState{
                    .color = .{
                        .operation = c.WGPUBlendOperation_Add,
                        .srcFactor = c.WGPUBlendFactor_One,
                        .dstFactor = c.WGPUBlendFactor_One,
                    },
                    .alpha = .{
                        .operation = c.WGPUBlendOperation_Add,
                        .srcFactor = c.WGPUBlendFactor_One,
                        .dstFactor = c.WGPUBlendFactor_One,
                    },
                },
            },
        },
        .multisample = .{
            .count = 1,
            .mask = 0xFFFFFFFF,
            .alphaToCoverageEnabled = 0,
        },
        .depthStencil = null,
    };

    wgpu.pipeline = c.wgpuDeviceCreateRenderPipeline(wgpu.device, &pipeline_desc);

    // Can clean up pipeline creation resources.
    c.wgpuShaderModuleRelease(shader_triangle);

    // Create mesh data
    const vertex_data = [_]f32{
        // x, y          // r, g, b
        -0.5, -0.5, 1.0, 0.0, 0.0, // bottom-left
        0.5, -0.5, 0.0, 1.0, 0.0, // bottom-right
        0.5, 0.5, 0.0, 0.0, 1.0, // top-right
        -0.5, 0.5, 1.0, 1.0, 0.0, // top-left
    };
    const index_data = [_]u16{
        0, 1, 2,
        0, 2, 3,
    };

    mesh.vertex_buffer = createBuffer(&vertex_data, @sizeOf(@TypeOf(vertex_data)), c.WGPUBufferUsage_Vertex);
    mesh.index_buffer = createBuffer(&index_data, @sizeOf(@TypeOf(index_data)), c.WGPUBufferUsage_Index);

    // Main loop
    c.emscripten_set_main_loop(draw, 0, true);

    // Clean up resources.
}

fn createBuffer(data: ?*const anyopaque, size: usize, usage: c.WGPUBufferUsage) c.WGPUBuffer {
    const buffer = c.wgpuDeviceCreateBuffer(wgpu.device, &c.WGPUBufferDescriptor{
        .usage = @as(c.enum_WGPUBufferUsage, c.WGPUBufferUsage_CopyDst) | usage,
        .size = size,
    });

    c.wgpuQueueWriteBuffer(wgpu.queue, buffer, 0, data, size);
    return buffer;
}

fn createSwapChain() c.WGPUSwapChain {
    std.log.info("Creating swapchain", .{});

    const surface = c.wgpuInstanceCreateSurface(wgpu.instance, &c.WGPUSurfaceDescriptor{
        .nextInChain = @ptrCast(&c.WGPUSurfaceDescriptorFromCanvasHTMLSelector{
            .chain = .{ .sType = c.WGPUSType_SurfaceDescriptorFromCanvasHTMLSelector },
            .selector = "canvas",
        }),
    });

    return c.wgpuDeviceCreateSwapChain(wgpu.device, surface, &c.WGPUSwapChainDescriptor{
        .usage = c.WGPUTextureUsage_RenderAttachment,
        .format = c.WGPUTextureFormat_BGRA8Unorm,
        .width = @intCast(canvas_width),
        .height = @intCast(canvas_height),
        .presentMode = c.WGPUPresentMode_Fifo,
    });
}

fn createShaderModule(code: [*:0]const u8, label: [*:0]const u8) c.WGPUShaderModule {
    const shader: c.WGPUShaderModuleWGSLDescriptor = .{
        .chain = .{ .sType = c.WGPUSType_ShaderModuleWGSLDescriptor },
        .code = code,
    };

    return c.wgpuDeviceCreateShaderModule(wgpu.device, &c.WGPUShaderModuleDescriptor{
        .nextInChain = @ptrCast(&shader),
        .label = label,
    });
}

fn createRenderPipeline() void {
    std.log.info("Creating renderpipline", .{});
    const shader_module = createShaderModule(wgsl_triangle, "triangle");
    const color_target = c.WGPUColorTargetState{
        .format = c.WGPUTextureFormat_BGRA8Unorm,
    };
    const fragment_state = c.WGPUFragmentState{
        .module = shader_module,
        .targetCount = 1,
        .targets = &color_target,
    };

    const pipeline_desc = c.WGPURenderPipelineDescriptor{
        .vertex = .{ .module = shader_module },
        .fragment = &fragment_state,
        .multisample = .{
            .count = 1,
            .mask = 0xFFFFFF,
            .alphaToCoverageEnabled = 0,
        },
        .depthStencil = null,
    };

    wgpu.pipeline = c.wgpuDeviceCreateRenderPipeline(wgpu.device, &pipeline_desc);
}

fn draw() callconv(.C) void {
    var width: f64 = 0;
    var height: f64 = 0;
    _ = c.emscripten_get_element_css_size("canvas", &width, &height);

    const new_width: i32 = @intFromFloat(width);
    const new_height: i32 = @intFromFloat(height);

    // recreate swapchain, if canvas dimensions don't match new dimensions.
    if (canvas_width != new_width or canvas_height != new_height) {
        canvas_width = new_width;
        canvas_height = new_height;

        // Check if swapchain already exist, if so recreate it.
        if (wgpu.swapchain != null) {
            c.wgpuSwapChainRelease(wgpu.swapchain);
            wgpu.swapchain = null;
        }

        wgpu.swapchain = createSwapChain();
    }

    // Get current framebuffer
    const framebuffer_view = c.wgpuSwapChainGetCurrentTextureView(wgpu.swapchain);
    defer c.wgpuTextureViewRelease(framebuffer_view);

    // Create command encoder
    const encoder = c.wgpuDeviceCreateCommandEncoder(wgpu.device, null);
    defer c.wgpuCommandEncoderRelease(encoder);

    // Begin render pass
    const render_pass = c.wgpuCommandEncoderBeginRenderPass(encoder, &c.WGPURenderPassDescriptor{
        .colorAttachmentCount = 1,
        .colorAttachments = &c.WGPURenderPassColorAttachment{
            .view = framebuffer_view,
            .loadOp = c.WGPULoadOp_Clear,
            .storeOp = c.WGPUStoreOp_Store,
            .clearValue = c.WGPUColor{ .r = 0.2, .g = 0.2, .b = 0.3, .a = 1.0 },
            .depthSlice = c.WGPU_DEPTH_SLICE_UNDEFINED,
        },
    });
    defer c.wgpuRenderPassEncoderRelease(render_pass);

    // Draw triangle
    c.wgpuRenderPassEncoderSetPipeline(render_pass, wgpu.pipeline);
    c.wgpuRenderPassEncoderSetVertexBuffer(render_pass, 0, mesh.vertex_buffer, 0, c.WGPU_WHOLE_SIZE);
    c.wgpuRenderPassEncoderSetIndexBuffer(render_pass, mesh.index_buffer, c.WGPUIndexFormat_Uint16, 0, c.WGPU_WHOLE_SIZE);
    c.wgpuRenderPassEncoderDrawIndexed(render_pass, 6, 1, 0, 0, 0);

    // End render pass
    c.wgpuRenderPassEncoderEnd(render_pass);

    // Create command buffer
    const cmd_buffer = c.wgpuCommandEncoderFinish(encoder, null);
    defer c.wgpuCommandBufferRelease(cmd_buffer);

    // submit commands
    c.wgpuQueueSubmit(wgpu.queue, 1, &cmd_buffer);
}

// Borrowed from zemscripten.
// TODO: move to platform layer(?)
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const prefix = level_txt ++ prefix2;

    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrintZ(buf[0 .. buf.len - 1], prefix ++ format, args) catch |err| {
        switch (err) {
            error.NoSpaceLeft => {
                c.emscripten_console_error("log message too long, skipped.");
                return;
            },
        }
    };
    switch (level) {
        .err => c.emscripten_console_error(@ptrCast(msg.ptr)),
        .warn => c.emscripten_console_warn(@ptrCast(msg.ptr)),
        else => c.emscripten_console_log(@ptrCast(msg.ptr)),
    }
}
