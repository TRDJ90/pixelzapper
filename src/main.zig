const std = @import("std");

const c = @cImport({
    @cInclude("emscripten.h");
    @cInclude("emscripten/html5.h");
});

pub const std_options = std.Options{
    .logFn = log,
};

pub fn main() !void {
    testLoop();
    // c.emscripten_set_main_loop(testLoop, 0, true);
}

fn testLoop() callconv(.C) void {
    std.log.info("Hello, world!!!!", .{});
}

// Borrowed from zemscripten.
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
