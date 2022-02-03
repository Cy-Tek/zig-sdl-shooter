const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(std.build.Builder.StandardTargetOptionsArgs{ .default_target = std.zig.CrossTarget{ .abi = std.Target.Abi.msvc } });

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-sdl", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addLibPath("deps/lib");

    exe.linkLibC();
    exe.addIncludeDir("deps/include/SDL2");
    exe.linkSystemLibrary("SDL2");
    b.installBinFile("deps/lib/SDL2.dll", "SDL2.dll");

    sdl2_image_setup: {
        exe.addIncludeDir("deps/include/SDLImage");
        exe.linkSystemLibrary("SDL2_Image");
        b.installBinFile("deps/lib/SDL2_Image.dll", "SDL2_Image.dll");

        const dll_files = .{
            "libjpeg-9.dll",
            "libpng16-16.dll",
            "libtiff-5.dll",
            "libwebp-7.dll",
            "zlib1.dll",
        };

        inline for (dll_files) |dll| {
            b.installBinFile("deps/lib/" ++ dll, dll);
        }

        break :sdl2_image_setup;
    }

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
