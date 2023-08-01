const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable = b.option(bool, "enable", "enable tracy profiling") orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "enable", enable);

    const module = b.addModule("tracy", .{
        .source_file = .{ .path = "public/tracy.zig" },
        .dependencies = &.{
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
    lib.installHeadersDirectory("public", "");
    lib.addCSourceFile("public/TracyClient.cpp", &.{"-fno-sanitize=undefined"});
    if (enable) lib.defineCMacro("TRACY_ENABLE", "ON");
    lib.linkLibCpp();
    lib.linkSystemLibrary("pthread");

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "example-tracy-profiling",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("tracy", module);
    exe.linkLibrary(lib);
    b.installArtifact(exe);
}
