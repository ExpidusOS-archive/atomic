const arch = @import("../arch.zig");
const mem = @import("../mem.zig");
const std = @import("std");

const console = arch.serial.Console{
    .port = .COM1,
    .baud = arch.serial.DEFAULT_BAUDRATE,
};

pub fn bootstrapMain(memprofile: mem.Profile) void {
    _ = memprofile;
    arch.Gdt.init();

    console.reset() catch unreachable;

    arch.Idt.init();
    arch.pic.init();
    arch.isr.init();
    arch.irq.init();
}
