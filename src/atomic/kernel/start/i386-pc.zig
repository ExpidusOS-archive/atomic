const arch = @import("../arch.zig");
const mem = @import("../mem.zig");
const std = @import("std");

const console = arch.serial.Console{
    .port = .COM1,
    .baud = arch.serial.DEFAULT_BAUDRATE,
};

pub fn bootstrapStage1() void {
    console.reset() catch unreachable;

    arch.Gdt.init();
    arch.Idt.init();
    arch.pic.init();
    arch.isr.init();
    arch.irq.init();

    asm volatile ("cli");

    _ = console.writer().print("Hello, world!\n", .{}) catch unreachable;
}

pub fn bootstrapStage2(memprofile: *const mem.Profile) void {
    _ = console.writer().print("Memory: {} kB\n", .{memprofile.mem_kb}) catch unreachable;
}
