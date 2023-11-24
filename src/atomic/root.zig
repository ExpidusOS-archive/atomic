const atomic = @import("atomic");
const std = @import("std");
const root = @import("atomic-root");

comptime {
    _ = atomic;
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, n: ?usize) noreturn {
    _ = error_return_trace;
    _ = n;
    @setCold(true);
    atomic.kernel.panic("{s}", .{msg});
}

pub const os = atomic.os;

pub fn main() !void {
    return root.main();
}
