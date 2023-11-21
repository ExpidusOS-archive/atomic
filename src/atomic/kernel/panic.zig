const std = @import("std");
const arch = @import("arch.zig");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    if (@hasDecl(arch, "serial")) {
        const console = arch.serial.Console{
            .port = .COM1,
            .baud = arch.serial.DEFAULT_BAUDRATE,
        };

        _ = console.writer().print(fmt, args) catch 0;
        _ = console.write("\n") catch 0;
    }

    while (true) {}
}
