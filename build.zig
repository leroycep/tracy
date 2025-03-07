const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable = b.option(bool, "enable", "enable tracy profiling") orelse false;
    const delayed_init = b.option(bool, "delayed_init", "Enable delayed initialization of the library (init on first call)") orelse false;
    const manual_lifetime = b.option(bool, "manual_lifetime", "Enable the manual lifetime management of the profile (requires delayed_init)") orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "enable", enable);
    build_options.addOption(bool, "delayed_init", delayed_init);
    build_options.addOption(bool, "manual_lifetime", manual_lifetime);

    const tracy_client_cpp_module = b.createModule(.{
        .root_source_file = b.path("public/tracy.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    tracy_client_cpp_module.addCSourceFile(.{
        .file = b.path("public/TracyClient.cpp"),
        .flags = &.{"-fno-sanitize=undefined"},
    });
    if (enable) tracy_client_cpp_module.addCMacro("TRACY_ENABLE", "ON");
    if (delayed_init) tracy_client_cpp_module.addCMacro("TRACY_DELAYED_INIT", "1");
    if (manual_lifetime) tracy_client_cpp_module.addCMacro("TRACY_MANUAL_LIFETIME", "1");

    switch (target.result.os.tag) {
        .windows => {
            tracy_client_cpp_module.addCMacro("WINVER", "0x0601");
            tracy_client_cpp_module.addCMacro("_WIN32_WINNT", "0x0601");
            if (target.result.abi.isGnu()) {
                tracy_client_cpp_module.link_libcpp = true;
                tracy_client_cpp_module.linkSystemLibrary("ws2_32", .{});
                tracy_client_cpp_module.linkSystemLibrary("dbghelp", .{});
            }
        },
        else => {
            tracy_client_cpp_module.link_libcpp = true;
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
