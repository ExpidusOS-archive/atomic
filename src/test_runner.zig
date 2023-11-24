const builtin = @import("builtin");
const atomic = @import("atomic");
const std = @import("std");

pub usingnamespace if (builtin.os.tag == .freestanding) struct {
    pub const os = atomic.os;
} else struct {};

pub fn main() !void {
    const stdout = std.io.getStdOut();
    var failed: usize = 0;
    var skipped: usize = 0;
    var passed: usize = 0;

    for (builtin.test_functions) |test_fn| {
        stdout.writeAll(test_fn.name) catch {};
        stdout.writeAll("... ") catch {};

        test_fn.func() catch |err| {
            if (err != error.SkipZigTest) {
                stdout.writeAll("FAIL\n") catch {};
                failed += 1;
                continue;
            }

            stdout.writeAll("SKIP\n") catch {};
            skipped += 1;
            continue;
        };

        stdout.writeAll("PASS\n") catch {};
        passed += 1;
    }

    stdout.writer().print("{} passed, {} skipped, {} failed\n", .{ passed, skipped, failed }) catch {};
    while (true) {}
}
