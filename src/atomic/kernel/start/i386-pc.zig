const arch = @import("../arch.zig");
const mem = @import("../mem.zig");
const panic = @import("../panic.zig").panic;
const std = @import("std");
const fio = @import("fio");

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
    arch.paging.init(memprofile);

    _ = console.writer().print("Memory: {} kB\n", .{memprofile.mem_kb}) catch unreachable;

    const pci = fio.pci.bus.x86.create(.{
        .allocator = @constCast(&memprofile.fixed_allocator).allocator(),
    }) catch |e| panic("Failed to init PCI: {s}", .{@errorName(e)});
    defer pci.deinit();

    const devices = pci.enumerate() catch |e| panic("Failed to enumerate PCI: {s}", .{@errorName(e)});
    defer devices.deinit();

    for (devices.items) |dev| {
        _ = console.writer().print("{}\n", .{dev}) catch |e| panic("Failed to print: {s}", .{@errorName(e)});
    }
}
