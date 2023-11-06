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
    mem.phys.init(memprofile, @constCast(&memprofile.fixed_allocator).allocator());

    const kernel_vmm = mem.virt.init(memprofile, @constCast(&memprofile.fixed_allocator).allocator()) catch |e| panic("Failed to initialize VMM: {s}", .{@errorName(e)});

    arch.paging.init(memprofile);

    var heap_size = memprofile.mem_kb / 10 * 1024;
    if (!std.math.isPowerOfTwo(heap_size)) heap_size = std.math.floorPowerOfTwo(usize, heap_size);

    var kernel_heap = mem.heap.init(arch.VmmPayload, kernel_vmm, .{ .kernel = true, .writable = true, .cachable = true }, heap_size) catch |e| panic("Failed to initialize kernel heap: {s}", .{@errorName(e)});

    _ = console.writer().print("Memory: {} kB\n", .{memprofile.mem_kb}) catch unreachable;

    const pci = fio.pci.bus.x86.create(.{
        .allocator = kernel_heap.allocator(),
    }) catch |e| panic("Failed to init PCI: {s}", .{@errorName(e)});
    defer pci.deinit();

    const devices = pci.enumerate() catch |e| panic("Failed to enumerate PCI: {s}", .{@errorName(e)});
    defer devices.deinit();

    for (devices.items) |dev| {
        _ = console.writer().print("{}\n", .{dev}) catch |e| panic("Failed to print: {s}", .{@errorName(e)});
    }
}
