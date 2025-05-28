const std = @import("std");

const platform = @import("platform/web.zig");
const wgpu = @import("webgpu.zig").wgpu;

const fu = @import("webgpu.zig");

pub const std_options = std.Options{
    .logFn = platform.log,
};

const WGPUContext = struct {
    instance: fu.Instance = null,
    device: fu.Device = null,
    queue: fu.Queue = null,
    swapchain: fu.Swapchain = null,
    pipeline: fu.RenderPipeline = null,
};

const Mesh = struct {
    vertex_buffer: wgpu.WGPUBuffer,
    index_buffer: wgpu.WGPUBuffer,
};

var wgpu_context: WGPUContext = undefined;
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
    wgpu_context.instance = fu.createInstance(null);
    wgpu_context.device = platform.getDevice();
    wgpu_context.queue = fu.deviceGetQueue(wgpu_context.device);

    platform.registerCallbacks();

    // Create triangle shader
    const shader = wgpu.WGPUShaderModuleWGSLDescriptor{
        .chain = .{ .sType = wgpu.WGPUSType_ShaderModuleWGSLDescriptor },
        .code = wgsl_triangle,
    };

    const shader_triangle = wgpu.wgpuDeviceCreateShaderModule(wgpu_context.device, &wgpu.WGPUShaderModuleDescriptor{
        .nextInChain = @ptrCast(&shader),
        .label = "triangle",
    });

    // Describe buffer layouts
    const vertex_attributes = [2]wgpu.WGPUVertexAttribute{
        .{
            .format = wgpu.WGPUVertexFormat_Float32x2,
            .offset = 0,
            .shaderLocation = 0,
        },
        .{
            .format = wgpu.WGPUVertexFormat_Float32x3,
            .offset = 2 * @sizeOf(f32),
            .shaderLocation = 1,
        },
    };

    const vertex_buffer_layout = wgpu.WGPUVertexBufferLayout{
        .arrayStride = 5 * @sizeOf(f32),
        .attributeCount = 2,
        .attributes = &vertex_attributes,
    };

    // Create pipeline
    const pipeline_desc: wgpu.WGPURenderPipelineDescriptor = .{
        .primitive = .{
            .frontFace = wgpu.WGPUFrontFace_CCW,
            .cullMode = wgpu.WGPUCullMode_None,
            .topology = wgpu.WGPUPrimitiveTopology_TriangleList,
            .stripIndexFormat = wgpu.WGPUIndexFormat_Undefined,
        },
        .vertex = .{
            .module = shader_triangle,
            .entryPoint = "vs_main",
            .bufferCount = 1,
            .buffers = &vertex_buffer_layout,
        },
        .fragment = &wgpu.WGPUFragmentState{
            .module = shader_triangle,
            .entryPoint = "fs_main",
            .targetCount = 1,
            .targets = &wgpu.WGPUColorTargetState{
                .format = wgpu.WGPUTextureFormat_BGRA8Unorm,
                .writeMask = wgpu.WGPUColorWriteMask_All,
                .blend = &wgpu.WGPUBlendState{
                    .color = .{
                        .operation = wgpu.WGPUBlendOperation_Add,
                        .srcFactor = wgpu.WGPUBlendFactor_One,
                        .dstFactor = wgpu.WGPUBlendFactor_One,
                    },
                    .alpha = .{
                        .operation = wgpu.WGPUBlendOperation_Add,
                        .srcFactor = wgpu.WGPUBlendFactor_One,
                        .dstFactor = wgpu.WGPUBlendFactor_One,
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

    wgpu_context.pipeline = wgpu.wgpuDeviceCreateRenderPipeline(wgpu_context.device, &pipeline_desc);

    // Can clean up pipeline creation resources.
    wgpu.wgpuShaderModuleRelease(shader_triangle);

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

    mesh.vertex_buffer = createBuffer(&vertex_data, @sizeOf(@TypeOf(vertex_data)), wgpu.WGPUBufferUsage_Vertex);
    mesh.index_buffer = createBuffer(&index_data, @sizeOf(@TypeOf(index_data)), wgpu.WGPUBufferUsage_Index);

    // Main loop
    platform.setMainLoop(draw, 0, true);

    // Clean up resources.
}

fn createBuffer(data: ?*const anyopaque, size: usize, usage: wgpu.WGPUBufferUsage) wgpu.WGPUBuffer {
    const buffer = wgpu.wgpuDeviceCreateBuffer(wgpu_context.device, &wgpu.WGPUBufferDescriptor{
        .usage = @as(wgpu.enum_WGPUBufferUsage, wgpu.WGPUBufferUsage_CopyDst) | usage,
        .size = size,
    });

    wgpu.wgpuQueueWriteBuffer(wgpu_context.queue, buffer, 0, data, size);
    return buffer;
}

fn createSwapChain() wgpu.WGPUSwapChain {
    std.log.info("Creating swapchain", .{});

    const surface = platform.getSurface(wgpu_context.instance);
    return wgpu.wgpuDeviceCreateSwapChain(wgpu_context.device, surface, &wgpu.WGPUSwapChainDescriptor{
        .usage = wgpu.WGPUTextureUsage_RenderAttachment,
        .format = wgpu.WGPUTextureFormat_BGRA8Unorm,
        .width = @intCast(canvas_width),
        .height = @intCast(canvas_height),
        .presentMode = wgpu.WGPUPresentMode_Fifo,
    });
}

fn createShaderModule(code: [*:0]const u8, label: [*:0]const u8) wgpu.WGPUShaderModule {
    const shader: wgpu.WGPUShaderModuleWGSLDescriptor = .{
        .chain = .{ .sType = wgpu.WGPUSType_ShaderModuleWGSLDescriptor },
        .code = code,
    };

    return wgpu.wgpuDeviceCreateShaderModule(wgpu_context.device, &wgpu.WGPUShaderModuleDescriptor{
        .nextInChain = @ptrCast(&shader),
        .label = label,
    });
}

fn createRenderPipeline() void {
    std.log.info("Creating renderpipline", .{});
    const shader_module = createShaderModule(wgsl_triangle, "triangle");
    const color_target = wgpu.WGPUColorTargetState{
        .format = wgpu.WGPUTextureFormat_BGRA8Unorm,
    };
    const fragment_state = wgpu.WGPUFragmentState{
        .module = shader_module,
        .targetCount = 1,
        .targets = &color_target,
    };

    const pipeline_desc = wgpu.WGPURenderPipelineDescriptor{
        .vertex = .{ .module = shader_module },
        .fragment = &fragment_state,
        .multisample = .{
            .count = 1,
            .mask = 0xFFFFFF,
            .alphaToCoverageEnabled = 0,
        },
        .depthStencil = null,
    };

    wgpu_context.pipeline = wgpu.wgpuDeviceCreateRenderPipeline(wgpu_context.device, &pipeline_desc);
}

fn draw() callconv(.C) void {
    var new_width: i32 = canvas_width;
    var new_height: i32 = canvas_height;

    // TODO: replace this all with state hold in platform web.
    platform.getCanvasDimensions(&new_width, &new_height);

    // recreate swapchain, if canvas dimensions don't match new dimensions.
    if (canvas_width != new_width or canvas_height != new_height) {
        canvas_width = new_width;
        canvas_height = new_height;

        // Check if swapchain already exist, if so recreate it.
        if (wgpu_context.swapchain != null) {
            wgpu.wgpuSwapChainRelease(wgpu_context.swapchain);
            wgpu_context.swapchain = null;
        }

        wgpu_context.swapchain = createSwapChain();
    }

    // Get current framebuffer
    const framebuffer_view = wgpu.wgpuSwapChainGetCurrentTextureView(wgpu_context.swapchain);
    defer wgpu.wgpuTextureViewRelease(framebuffer_view);

    // Create command encoder
    const encoder = wgpu.wgpuDeviceCreateCommandEncoder(wgpu_context.device, null);
    defer wgpu.wgpuCommandEncoderRelease(encoder);

    // Begin render pass
    const render_pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
        .colorAttachmentCount = 1,
        .colorAttachments = &wgpu.WGPURenderPassColorAttachment{
            .view = framebuffer_view,
            .loadOp = wgpu.WGPULoadOp_Clear,
            .storeOp = wgpu.WGPUStoreOp_Store,
            .clearValue = wgpu.WGPUColor{ .r = 0.2, .g = 0.2, .b = 0.3, .a = 1.0 },
            .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
        },
    });
    defer wgpu.wgpuRenderPassEncoderRelease(render_pass);

    // Draw triangle
    wgpu.wgpuRenderPassEncoderSetPipeline(render_pass, wgpu_context.pipeline);
    wgpu.wgpuRenderPassEncoderSetVertexBuffer(render_pass, 0, mesh.vertex_buffer, 0, wgpu.WGPU_WHOLE_SIZE);
    wgpu.wgpuRenderPassEncoderSetIndexBuffer(render_pass, mesh.index_buffer, wgpu.WGPUIndexFormat_Uint16, 0, wgpu.WGPU_WHOLE_SIZE);
    wgpu.wgpuRenderPassEncoderDrawIndexed(render_pass, 6, 1, 0, 0, 0);

    // End render pass
    wgpu.wgpuRenderPassEncoderEnd(render_pass);

    // Create command buffer
    const cmd_buffer = wgpu.wgpuCommandEncoderFinish(encoder, null);
    defer wgpu.wgpuCommandBufferRelease(cmd_buffer);

    // submit commands
    wgpu.wgpuQueueSubmit(wgpu_context.queue, 1, &cmd_buffer);
}
