const atomic = @import("atomic");
const std = @import("std");

comptime {
    _ = atomic;
}

pub fn main() void {
    std.debug.print("Hello, world!\n", .{});
}
