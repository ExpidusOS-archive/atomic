const atomic = @import("atomic");
const builtin = @import("builtin");
const std = @import("std");
const root = @import("atomic-root");
const Self = @This();

comptime {
    _ = atomic;
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, n: ?usize) noreturn {
    _ = error_return_trace;
    _ = n;
    @setCold(true);
    atomic.kernel.panicAt(@returnAddress(), "{s}", .{msg});
}

pub usingnamespace if (builtin.os.tag == .freestanding) struct {
    pub const os = atomic.os;
} else struct {};

pub fn main() !void {
    return root.main();
}
