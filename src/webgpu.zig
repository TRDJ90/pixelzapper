pub const wgpu = @cImport({
    @cInclude("emscripten/html5_webgpu.h");
});

pub const Instance = wgpu.WGPUInstance;
pub const Device = wgpu.WGPUDevice;
pub const Queue = wgpu.WGPUQueue;
pub const Swapchain = wgpu.WGPUSwapChain;
pub const RenderPipeline = wgpu.WGPURenderPipeline;
pub const Surface = wgpu.WGPUSurface;

//TODO: conver the below stuff into object to wrap all this BS.

// Instance
pub const createInstance = wgpu.wgpuCreateInstance;

// Device
pub const deviceGetQueue = wgpu.wgpuDeviceGetQueue;
