const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable = b.option(bool, "enable", "enable tracy profiling") orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "enable", enable);

    const module = b.addModule("tracy", .{
        .root_source_file = b.path("public/tracy.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "build_options",
                .module = build_options.createModule(),
            },
        },
        .link_libcpp = true,
    });
    module.addCSourceFile(.{
        .file = b.path("public/TracyClient.cpp"),
        .flags = &.{"-fno-sanitize=undefined"},
    });
    if (enable) {
        module.addCMacro("TRACY_ENABLE", "ON");
    }
    switch (target.result.os.tag) {
        .windows => {
            module.linkSystemLibrary("ws2_32", .{});
            module.linkSystemLibrary("dbghelp", .{});
        },
        else => {
            module.linkSystemLibrary("pthread", .{});
        },
    }
    module.addIncludePath(b.path("public"));

    const lib = b.addLibrary(.{
        .name = "TracyClient",
        .linkage = .static,
        .root_module = module,
    });

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
