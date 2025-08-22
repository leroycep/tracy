const std = @import("std");

const tracy = @import("tracy");

var count: usize = 0;

pub fn main() anyerror!void {
    const t = tracy.trace(@src(), null);
    defer t.end();

    std.log.info("All your codebase are belong to us.", .{});

    if (count >= 10) {
        return;
    }
    count += 1;

    const w = std.crypto.random.int(u64);

    std.posix.nanosleep(w % 5, 0);
    try main();
}
