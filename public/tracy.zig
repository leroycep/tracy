const std = @import("std");
const build_options = @import("build_options");

pub const enabled = build_options.enable;
pub const delayed_init = build_options.enable and build_options.delayed_init;
pub const manual_lifetime = build_options.enable and build_options.manual_lifetime;
pub const callstack = if (build_options.enable) build_options.callstack else 0;

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

pub const LockContext = struct {
    ctx: if (enabled) *__tracy_lockable_context_data else void,

    pub inline fn announce(comptime src: std.builtin.SourceLocation) @This() {
        if (!build_options.enable) return undefined;

        const ensure_its_not_on_stack = struct {
            const loc = SourceLocationData{
                .name = null,
                .function = src.fn_name.ptr,
                .file = src.file.ptr,
                .line = src.line,
                .color = 0,
            };
        };
        return .{ .ctx = ___tracy_announce_lockable_ctx(&ensure_its_not_on_stack.loc) };
    }

    pub inline fn terminate(this: @This()) void {
        if (build_options.enable) {
            ___tracy_terminate_lockable_ctx(this.ctx);
        }
    }

    /// Returns whether the profiler connection is active, and if `afterLock` needs to be called.
    pub inline fn beforeLock(this: @This()) bool {
        if (build_options.enable) {
            return ___tracy_before_lock_lockable_ctx(this.ctx);
        } else {
            return false;
        }
    }

    pub inline fn afterLock(this: @This()) void {
        if (build_options.enable) {
            ___tracy_after_lock_lockable_ctx(this.ctx);
        }
    }

    pub inline fn afterUnlock(this: @This()) void {
        if (build_options.enable) {
            ___tracy_after_unlock_lockable_ctx(this.ctx);
        }
    }

    pub inline fn afterTryLock(this: @This(), acquired: bool) void {
        if (build_options.enable) {
            ___tracy_after_unlock_lockable_ctx(this.ctx, @intFromBool(acquired));
        }
    }

    pub inline fn customName(this: @This(), name: []const u8) void {
        if (build_options.enable) {
            ___tracy_custom_name_lockable_ctx(this.ctx, name.ptr, name.len);
        }
    }
};

pub const __tracy_lockable_context_data = opaque {};
pub extern fn ___tracy_announce_lockable_ctx(srcloc: *const SourceLocationData) *__tracy_lockable_context_data;
pub extern fn ___tracy_terminate_lockable_ctx(*__tracy_lockable_context_data) void;
pub extern fn ___tracy_before_lock_lockable_ctx(*__tracy_lockable_context_data) c_int;
pub extern fn ___tracy_after_lock_lockable_ctx(*__tracy_lockable_context_data) void;
pub extern fn ___tracy_after_unlock_lockable_ctx(*__tracy_lockable_context_data) void;
pub extern fn ___tracy_after_try_lock_lockable_ctx(*__tracy_lockable_context_data, acquired: c_int) void;
pub extern fn ___tracy_mark_lockable_ctx(*__tracy_lockable_context_data, *const SourceLocationData) void;
pub extern fn ___tracy_custom_name_lockable_ctx(*__tracy_lockable_context_data, name_ptr: [*]const u8, name_len: usize) void;

// Manual profiler lifetime management

pub extern fn ___tracy_startup_profiler() void;
pub extern fn ___tracy_shutdown_profiler() void;
pub extern fn ___tracy_profiler_started() c_int;

// Memory allocation tracing

pub const Allocator = struct {
    backing_allocator: std.mem.Allocator,

    pub fn allocator(this: *@This()) std.mem.Allocator {
        if (enabled) {
            return .{
                .ptr = this,
                .vtable = &std.mem.Allocator.VTable{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        } else {
            return this.backing_allocator;
        }
    }

    fn alloc(this_opaque: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        if (this.backing_allocator.vtable.alloc(this.backing_allocator.ptr, len, alignment, ret_addr)) |ptr| {
            ___tracy_emit_memory_alloc(ptr, len, 0);
            return ptr;
        }
        return null;
    }

    fn resize(this_opaque: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        if (this.backing_allocator.vtable.resize(this.backing_allocator.ptr, memory, alignment, new_len, ret_addr)) {
            ___tracy_emit_memory_free(memory.ptr, 0);
            ___tracy_emit_memory_alloc(memory.ptr, new_len, 0);
            return true;
        } else {
            return false;
        }
    }

    fn remap(this_opaque: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        if (this.backing_allocator.vtable.remap(this.backing_allocator.ptr, memory, alignment, new_len, ret_addr)) |new_ptr| {
            ___tracy_emit_memory_free(memory.ptr, 0);
            ___tracy_emit_memory_alloc(new_ptr, new_len, 0);
            return new_ptr;
        } else {
            return null;
        }
    }

    fn free(this_opaque: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));

        this.backing_allocator.vtable.free(this.backing_allocator.ptr, memory, alignment, ret_addr);
        ___tracy_emit_memory_free(memory.ptr, 0);
    }
};

pub extern fn ___tracy_emit_memory_alloc(ptr: [*]const anyopaque, size: usize, secure: c_int) void;
pub extern fn ___tracy_emit_memory_alloc_callstack(ptr: [*]const anyopaque, size: usize, depth: c_int, secure: c_int) void;
pub extern fn ___tracy_emit_memory_free(ptr: [*]const anyopaque, secure: c_int) void;
pub extern fn ___tracy_emit_memory_free_callstack(ptr: [*]const anyopaque, depth: c_int, secure: c_int) void;

pub extern fn ___tracy_emit_memory_alloc_named(ptr: [*]const anyopaque, size: usize, secure: c_int, name: [*:0]const u8) void;
pub extern fn ___tracy_emit_memory_alloc_callstack_named(ptr: [*]const anyopaque, size: usize, depth: c_int, secure: c_int, name: [*:0]const u8) void;
pub extern fn ___tracy_emit_memory_free_named(ptr: [*]const anyopaque, secure: c_int, name: [*:0]const u8) void;
pub extern fn ___tracy_emit_memory_free_callstack_named(ptr: [*]const anyopaque, depth: c_int, secure: c_int, name: [*:0]const u8) void;

// TracyCMessage functions

pub inline fn message(text: []const u8) void {
    if (build_options.enable) {
        ___tracy_emit_message(text.ptr, text.size, callstack);
    }
}

pub inline fn messageL(comptime text: [:0]const u8) void {
    if (build_options.enable) {
        ___tracy_emit_messageL(text.ptr, callstack);
    }
}

pub inline fn messageC(text: []const u8, color: u32) void {
    if (build_options.enable) {
        ___tracy_emit_messageC(text.ptr, text.size, color, callstack);
    }
}

pub inline fn messageLC(comptime text: [:0]const u8, color: u32) void {
    if (build_options.enable) {
        ___tracy_emit_messageLC(text.ptr, color, callstack);
    }
}

pub extern fn ___tracy_emit_message(ptr: [*]const u8, size: usize, callstack: c_int) void;
pub extern fn ___tracy_emit_messageL(ptr: [*:0]const u8, callstack: c_int) void;
pub extern fn ___tracy_emit_messageC(ptr: [*]const u8, size: usize, color: u32, callstack: c_int) void;
pub extern fn ___tracy_emit_messageLC(ptr: [*:0]const u8, color: u32, callstack: c_int) void;
