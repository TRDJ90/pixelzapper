const std = @import("std");
const emscripten = @cImport({
    @cInclude("emscripten.h");
    @cInclude("emscripten/html5.h");
    @cInclude("emscripten/html5_webgpu.h");
});

pub const setMainLoop = emscripten.emscripten_set_main_loop;

const wgpu = @import("../webgpu.zig");

const EVENT_TARGET_WINDOW: [*c]const u8 = "2";
const TARGET_SAME_THREAD: c_int = 2;

pub fn registerCallbacks() void {
    _ = emscripten_set_keydown_callback_on_thread(EVENT_TARGET_WINDOW, null, true, keyboardCallback, TARGET_SAME_THREAD);
    _ = emscripten_set_keypress_callback_on_thread(EVENT_TARGET_WINDOW, null, true, keyboardCallback, TARGET_SAME_THREAD);
    _ = emscripten_set_keyup_callback_on_thread(EVENT_TARGET_WINDOW, null, true, keyboardCallback, TARGET_SAME_THREAD);
    _ = emscripten_set_resize_callback_on_thread(EVENT_TARGET_WINDOW, null, true, windowResizeCallback, TARGET_SAME_THREAD);

    _ = emscripten_set_mousedown_callback_on_thread(EVENT_TARGET_WINDOW, null, true, mouseCallback, TARGET_SAME_THREAD);
    _ = emscripten_set_mouseup_callback_on_thread(EVENT_TARGET_WINDOW, null, true, mouseCallback, TARGET_SAME_THREAD);
    _ = emscripten_set_mousemove_callback_on_thread(EVENT_TARGET_WINDOW, null, true, mouseCallback, TARGET_SAME_THREAD);
    _ = emscripten_set_mouseenter_callback_on_thread(EVENT_TARGET_WINDOW, null, true, mouseCallback, TARGET_SAME_THREAD);
    _ = emscripten_set_mouseleave_callback_on_thread(EVENT_TARGET_WINDOW, null, true, mouseCallback, TARGET_SAME_THREAD);
}

pub fn getCanvasDimensions(width: *i32, height: *i32) void {
    var w: f64 = 0;
    var h: f64 = 0;
    _ = emscripten_get_element_css_size("canvas", &w, &h);

    const new_width: i32 = @intFromFloat(w);
    const new_heigh: i32 = @intFromFloat(h);

    width.* = new_width;
    height.* = new_heigh;
}

pub fn getDevice() wgpu.Device {
    return @ptrCast(@alignCast(emscripten_webgpu_get_device()));
}

fn windowResizeCallback(_: c_int, event: [*c]const emscripten.EmscriptenUiEvent, _: ?*anyopaque) callconv(.c) bool {
    const width: i32 = event.*.windowInnerWidth;
    const height: i32 = event.*.windowInnerHeight;

    std.log.info("Window resize width: {any}px, height: {any}", .{ width, height });
    return true;
}

fn keyboardCallback(_: c_int, event: [*c]const emscripten.EmscriptenKeyboardEvent, _: ?*anyopaque) callconv(.C) bool {
    std.log.info("logging keyboard event: {any}", .{event.*});
    return true;
}

fn mouseCallback(_: c_int, event: [*c]const emscripten.EmscriptenMouseEvent, _: ?*anyopaque) callconv(.c) bool {
    std.log.info("logging mouse event: {any}", .{event.*});
    return true;
}

pub fn getSurface(instance: wgpu.Instance) wgpu.Surface {
    const surface = wgpuInstanceCreateSurface(@ptrCast(instance), &emscripten.WGPUSurfaceDescriptor{
        .nextInChain = @ptrCast(&emscripten.WGPUSurfaceDescriptorFromCanvasHTMLSelector{
            .chain = .{ .sType = emscripten.WGPUSType_SurfaceDescriptorFromCanvasHTMLSelector },
            .selector = "canvas",
        }),
    });

    return @ptrCast(@alignCast(surface));
}

// Browser input functions.
const key_callback_func = ?*const fn (c_int, [*c]const emscripten.EmscriptenKeyboardEvent, ?*anyopaque) callconv(.c) bool;
const mouse_callback_func = ?*const fn (c_int, [*c]const emscripten.EmscriptenMouseEvent, ?*anyopaque) callconv(.c) bool;

extern fn emscripten_set_keydown_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: key_callback_func, target_thread: c_int) c_int;
extern fn emscripten_set_keypress_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: key_callback_func, target_thread: c_int) c_int;
extern fn emscripten_set_keyup_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: key_callback_func, target_thread: c_int) c_int;

extern fn emscripten_set_mousedown_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: mouse_callback_func, targetThread: c_int) c_int;
extern fn emscripten_set_mouseup_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: mouse_callback_func, targetThread: c_int) c_int;
extern fn emscripten_set_mousemove_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: mouse_callback_func, targetThread: c_int) c_int;
extern fn emscripten_set_mouseenter_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: mouse_callback_func, targetThread: c_int) c_int;
extern fn emscripten_set_mouseleave_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: mouse_callback_func, targetThread: c_int) c_int;

// Browser window functions.
const ui_callback_func = ?*const fn (c_int, [*c]const emscripten.EmscriptenUiEvent, ?*anyopaque) callconv(.c) bool;

extern fn emscripten_get_element_css_size(target: [*c]const u8, width: [*c]f64, height: [*c]f64) c_int;
extern fn emscripten_set_resize_callback_on_thread(target: [*c]const u8, userData: ?*anyopaque, useCapture: bool, callback: ui_callback_func, targetThread: c_int) c_int;

// wgpu functions.
extern fn emscripten_webgpu_get_device() emscripten.WGPUDevice;
extern fn wgpuInstanceCreateSurface(instance: emscripten.WGPUInstance, descriptor: [*c]const emscripten.WGPUSurfaceDescriptor) emscripten.WGPUSurface;

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
                emscripten_console_error("log message too long, skipped.");
                return;
            },
        }
    };
    switch (level) {
        .err => emscripten_console_error(@ptrCast(msg.ptr)),
        .warn => emscripten_console_warn(@ptrCast(msg.ptr)),
        else => emscripten_console_log(@ptrCast(msg.ptr)),
    }
}

// Logging functions.
extern fn emscripten_console_error(msg: [*c]const u8) void;
extern fn emscripten_console_warn(msg: [*c]const u8) void;
extern fn emscripten_console_log(msg: [*c]const u8) void;
