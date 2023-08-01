const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("tracy", .{
        .source_file = .{ .path = "public/tracy.zig" },
    });
    _ = module;

    const lib = b.addStaticLibrary(.{
        .name = "tracy",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath("public");
    lib.addCSourceFile("public/TracyClient.cpp", &.{ "-DTRACY_ENABLE", "-fno-sanitize=undefined" });
    lib.linkLibCpp();
    lib.linkSystemLibrary("pthread");

    b.installArtifact(lib);
}
