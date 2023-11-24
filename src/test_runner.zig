const builtin = @import("builtin");
const atomic = @import("atomic");
const std = @import("std");

pub usingnamespace if (builtin.os.tag == .freestanding) struct {
    pub const os = atomic.os;
} else struct {};

pub fn main() !void {
    const stderr = std.io.getStdErr();

    for (builtin.test_functions) |test_fn| {
        stderr.writeAll(test_fn.name) catch {};
        stderr.writeAll("...\n") catch {};
    }

    while (true) {}
}
