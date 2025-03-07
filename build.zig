const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable = b.option(bool, "enable", "enable tracy profiling") orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "enable", enable);

    const tracy_client_cpp_module = b.createModule(.{
        .root_source_file = b.path("public/tracy.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    tracy_client_cpp_module.addCSourceFile(.{
        .file = b.path("public/TracyClient.cpp"),
        .flags = &.{ "-fno-sanitize=undefined", "-std=c++11" },
    });
    if (enable) {
        tracy_client_cpp_module.addCMacro("TRACY_ENABLE", "ON");
    }
    switch (target.result.os.tag) {
        .windows => if (target.result.abi.isGnu()) {
            tracy_client_cpp_module.linkSystemLibrary("ws2_32", .{});
            tracy_client_cpp_module.linkSystemLibrary("dbghelp", .{});
        },
        else => {
            tracy_client_cpp_module.linkSystemLibrary("pthread", .{});
        },
    }
    tracy_client_cpp_module.addIncludePath(b.path("public"));

    const tracy_client = b.addLibrary(.{
        .name = "TracyClient",
        .linkage = .static,
        .root_module = tracy_client_cpp_module,
    });

    b.installArtifact(tracy_client);

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
    });
    if (enable) {
        module.linkLibrary(tracy_client);
    }

    const exe = b.addExecutable(.{
        .name = "example-tracy-profiling",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("tracy", module);
    b.installArtifact(exe);
}
