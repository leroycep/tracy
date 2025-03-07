const std = @import("std");
const build_options = @import("build_options");

pub const enabled = build_options.enable;
pub const delayed_init = build_options.enable and build_options.delayed_init;
pub const manual_lifetime = build_options.enable and build_options.manual_lifetime;

pub inline fn frame(name: ?[*:0]const u8) Frame {
    if (build_options.enable) Frame.___tracy_emit_frame_mark_start(name);
    return Frame{
        .name = name,
    };
}

pub inline fn trace(src: std.builtin.SourceLocation, name: ?[*:0]const u8) ZoneContext {
    const loc = SourceLocationData{
        .name = name,
        .function = src.fn_name.ptr,
        .file = src.file.ptr,
        .line = src.line,
        .color = 0,
    };
    if (build_options.enable) {
        return ZoneContext.___tracy_emit_zone_begin_callstack(&loc, 1, 1);
    } else {
        return undefined;
    }
}

pub const Frame = struct {
    name: ?[*:0]const u8,

    pub extern fn ___tracy_emit_frame_mark_start(name: ?[*:0]const u8) void;
    pub extern fn ___tracy_emit_frame_mark_end(name: ?[*:0]const u8) void;

    pub inline fn end(self: Frame) void {
        if (build_options.enable) {
            ___tracy_emit_frame_mark_end(self.name);
        }
    }
};

const SourceLocationData = extern struct {
    name: ?[*:0]const u8,
    function: ?[*:0]const u8,
    file: ?[*:0]const u8,
    line: u32,
    color: u32,
};

const ZoneContext = extern struct {
    id: u32,
    active: c_int,

    pub extern fn ___tracy_emit_zone_begin_callstack(srcloc: *const SourceLocationData, depth: c_int, active: c_int) @This();
    pub extern fn ___tracy_emit_zone_end(@This()) void;

    // Alias `___tracy_emit_zone_end` to `end`
    pub inline fn end(this: @This()) void {
        if (build_options.enable) {
            ___tracy_emit_zone_end(this);
        }
    }
};

pub extern fn ___tracy_startup_profiler() void;
pub extern fn ___tracy_shutdown_profiler() void;
pub extern fn ___tracy_profiler_started() c_int;
