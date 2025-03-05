const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable = b.option(bool, "enable", "enable tracy profiling") orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "enable", enable);

    const module = b.addModule("tracy", .{
        .root_source_file = b.path("public/tracy.zig"),
        .imports = &.{
            .{
                .name = "build_options",
                .module = build_options.createModule(),
            },
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "tracy",
        .target = target,
        .optimize = optimize,
    });
    lib.installHeadersDirectory(b.path("public"), "", .{});
    lib.addCSourceFile(.{
        .file = b.path("public/TracyClient.cpp"),
        .flags = &.{"-fno-sanitize=undefined"},
    });
    if (enable) {
        lib.defineCMacro("TRACY_ENABLE", "ON");
    }
    lib.linkLibCpp();

    switch (target.result.os.tag) {
        .windows => {
            lib.linkSystemLibrary("ws2_32");
            lib.linkSystemLibrary("dbghelp");
        },
        else => {
            lib.linkSystemLibrary("pthread");
        },
    }

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "example-tracy-profiling",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("tracy", module);
    exe.linkLibrary(lib);
    b.installArtifact(exe);
}
