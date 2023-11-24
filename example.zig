const std = @import("std");
const atomic = @import("atomic");

pub fn main() !void {
    try std.io.getStdErr().writer().print("Hello, world\n{}\n", .{std.debug.getStderrMutex()});
    while (true) {}
}
