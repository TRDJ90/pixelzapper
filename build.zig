const std = @import("std");

pub fn build(b: *std.Build) !void {
    // const target = b.standardTargetOptions(.{});
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .emscripten });
    const optimize = b.standardOptimizeOption(.{});

    const wasm_test = b.addStaticLibrary(.{
        .name = "test",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    wasm_test.linkLibC();

    // Hardcode for now path to emscripten includes.
    const emscripten_include = "/opt/homebrew/Cellar/emscripten/4.0.9/libexec/cache/sysroot/include";
    wasm_test.addSystemIncludePath(.{ .cwd_relative = emscripten_include });

    // Define emscripten compile command
    const emcc_cmd = b.addSystemCommand(&[_][]const u8{"emcc"});
    emcc_cmd.addFileArg(wasm_test.getEmittedBin());
    emcc_cmd.addArgs(&[_][]const u8{
        "-o",
        b.fmt("web/{s}.html", .{wasm_test.name}),
        "-Oz",
        "--shell-file=src/shell.html",
        "-sASYNCIFY",
        "-sUSE_WEBGPU=1",
    });
    emcc_cmd.step.dependOn(&wasm_test.step);

    // 'emcc' flags necessary for debug builds.
    if (optimize == .Debug or optimize == .ReleaseSafe) {
        emcc_cmd.addArgs(&[_][]const u8{
            "-sUSE_OFFSET_CONVERTER",
            "-sASSERTIONS",
        });
    }

    b.getInstallStep().dependOn(&emcc_cmd.step);
}
