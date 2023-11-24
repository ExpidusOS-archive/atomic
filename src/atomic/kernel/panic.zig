const std = @import("std");
const arch = @import("arch.zig");

pub fn panicAt(addr: usize, comptime fmt: []const u8, args: anytype) noreturn {
    if (@hasDecl(arch, "serial")) {
        const console = arch.serial.Console{
            .port = .COM1,
            .baud = arch.serial.DEFAULT_BAUDRATE,
        };

        _ = console.writer().print("Kernel panic: " ++ fmt ++ "\n", args) catch 0;
        _ = console.writer().print("Address: 0x{x}\n", .{addr}) catch 0;
    }

    @trap();
}

pub inline fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    panicAt(@frameAddress(), fmt, args);
}
