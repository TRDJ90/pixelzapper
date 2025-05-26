const std = @import("std");
const emscripten = @cImport({
    @cInclude("emscripten.h");
    @cInclude("emscripten/html5.h");
    @cInclude("emscripten/html5_webgpu.h");
});

pub const setMainLoop = emscripten.emscripten_set_main_loop;

const wgpu = @import("../webgpu.zig");

pub fn getCanvasDimensions(width: *i32, height: *i32) void {
    var w: f64 = 0;
    var h: f64 = 0;
    _ = emscripten.emscripten_get_element_css_size("canvas", &w, &h);

    const new_width: i32 = @intFromFloat(w);
    const new_heigh: i32 = @intFromFloat(h);

    width.* = new_width;
    height.* = new_heigh;
}

pub fn getDevice() wgpu.Device {
    return @ptrCast(@alignCast(emscripten.emscripten_webgpu_get_device()));
}

pub fn getSurface(instance: wgpu.Instance) wgpu.Surface {
    const surface = emscripten.wgpuInstanceCreateSurface(@ptrCast(instance), &emscripten.WGPUSurfaceDescriptor{
        .nextInChain = @ptrCast(&emscripten.WGPUSurfaceDescriptorFromCanvasHTMLSelector{
            .chain = .{ .sType = emscripten.WGPUSType_SurfaceDescriptorFromCanvasHTMLSelector },
            .selector = "canvas",
        }),
    });

    return @ptrCast(@alignCast(surface));
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
                emscripten.emscripten_console_error("log message too long, skipped.");
                return;
            },
        }
    };
    switch (level) {
        .err => emscripten.emscripten_console_error(@ptrCast(msg.ptr)),
        .warn => emscripten.emscripten_console_warn(@ptrCast(msg.ptr)),
        else => emscripten.emscripten_console_log(@ptrCast(msg.ptr)),
    }
}
