const atomic = @import("atomic");
const std = @import("std");

comptime {
    _ = atomic;
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, n: ?usize) noreturn {
    _ = error_return_trace;
    _ = n;
    @setCold(true);
    atomic.kernel.panic("{s}", .{msg});
}

pub fn main() void {
    std.debug.print("Hello, world!\n", .{});
}
