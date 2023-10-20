const std = @import("std");
const arch = @import("arch.zig");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    const console = arch.serial.Console{
        .port = .COM1,
        .baud = arch.serial.DEFAULT_BAUDRATE,
    };

    _ = console.writer().print(fmt, args) catch 0;
    _ = console.write("\n") catch 0;
    while (true) {}
}
