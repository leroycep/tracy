const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable = b.option(bool, "enable", "enable performance profiling integration") orelse false;
    const python = b.option(bool, "python", "install Tracy python module (default: false)") orelse false;
    const linkage = b.option(std.builtin.LinkMode, "linkage", "whether to use static or dynamic linking for the TracyClient library (default: static)") orelse
        if (python)
        std.builtin.LinkMode.dynamic
    else
        std.builtin.LinkMode.static;

    if (python and linkage == .static) {
        // We need dynamic linking because otherwise we run into issues
        // with the TracyClient library being loaded multiple times.
        std.log.err("Python support requires dynamic linking.", .{});
        return error.InvalidOptions;
    }
    if (python and !enable) {
        // Since PyTracy doesn't know if it will running the profiler until runtime,
        // we need to build the TracyClient library with TRACY_ENABLE defined. The
        // Python module will then take responsibility for not starting profiling unless
        // it is asked for.
        std.log.err("Python support requires Tracy to be enabled.", .{});
        return error.InvalidOptions;
    }

    const tracy_client = buildTracyClientLibrary(b, .{
        .enable = enable,
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    b.installArtifact(tracy_client);

    // Create the native part of the Python module
    const pytracy = b.addSharedLibrary(.{
        .name = "PyTracyClient",
        .target = target,
        .optimize = optimize,
    });
    pytracy.addCSourceFile(.{
        .file = .{ .path = "public/PyTracyModule.c" },
    });
    pytracy.defineCMacro("TRACY_ENABLE", "1");
    pytracy.linkLibrary(tracy_client);
    pytracy.linkSystemLibrary("python");

    if (python) {
        const pytracy_install_module = b.addInstallArtifact(pytracy, .{
            .dest_dir = .{ .override = .{ .custom = "site-packages/" } },
            .dest_sub_path = if (target.result.os.tag == .windows) "PyTracyClient.pyd" else "PyTracyClient.so",
        });

        // Install the Python source code part of the Python module
        const install_python_source_files = b.addInstallDirectory(.{
            .source_dir = .{ .path = "public/tracy.py" },
            .install_dir = .{ .custom = "site-packages/" },
            .install_subdir = "tracy",
            .include_extensions = &.{".py"},
        });

        // b.getInstallStep().dependOn(&pytracy_install_dll.step);
        b.getInstallStep().dependOn(&pytracy_install_module.step);
        b.getInstallStep().dependOn(&install_python_source_files.step);
    }
}

pub fn buildTracyClientLibrary(b: *std.Build, options: struct {
    /// If true, defines the TRACY_ENABLE macro
    enable: bool,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
}) *std.Build.Step.Compile {
    const tracy_client = std.Build.Step.Compile.create(b, .{
        .name = "TracyClient",
        .root_module = .{
            .target = options.target,
            .optimize = options.optimize,
        },
        .kind = .lib,
        .linkage = options.linkage,
        .version = std.SemanticVersion{
            .major = 0,
            .minor = 10,
            .patch = 0,
        },
    });
    tracy_client.addCSourceFile(.{ .file = .{ .path = "public/TracyClient.cpp" } });
    tracy_client.addIncludePath(.{ .path = "public" });
    tracy_client.installHeadersDirectory(.{ .path = "public/tracy" }, "tracy", .{});
    tracy_client.installHeadersDirectory(.{ .path = "public/common" }, "common", .{});
    tracy_client.installHeadersDirectory(.{ .path = "public/client" }, "client", .{});
    tracy_client.installHeadersDirectory(.{ .path = "public/libbacktrace" }, "libbacktrace", .{});
    tracy_client.linkLibCpp();
    if (options.enable) {
        tracy_client.defineCMacro("TRACY_ENABLE", "1");
    }
    return tracy_client;
}
