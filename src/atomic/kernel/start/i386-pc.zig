const arch = @import("../arch.zig");
const std = @import("std");

const console = arch.serial.Console{
    .port = .COM1,
    .baud = arch.serial.DEFAULT_BAUDRATE,
};

pub fn bootstrapMain() callconv(.C) void {
    arch.Gdt.init();

    console.reset() catch unreachable;

    arch.Idt.init();
    arch.pic.init();
    arch.isr.init();
    arch.irq.init();
}

comptime {
    @export(bootstrapMain, .{ .name = "bootstrap_main" });
}
