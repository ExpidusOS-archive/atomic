const arch = @import("../arch.zig");
const mem = @import("../mem.zig");
const io = @import("../io.zig");
const panic = @import("../panic.zig").panic;
const std = @import("std");
const fio = @import("fio");

const console = arch.serial.Console{
    .port = .COM1,
    .baud = arch.serial.DEFAULT_BAUDRATE,
};

var kernel_heap: mem.heap.FreeListAllocator = undefined;

pub fn bootstrapStage1() void {
    console.reset() catch unreachable;

    arch.Gdt.init();
    arch.Idt.init();
    arch.pic.init();
    arch.isr.init();
    arch.irq.init();

    asm volatile ("cli");
}

pub fn bootstrapStage2(memprofile: *const mem.Profile) void {
    mem.phys.init(memprofile, @constCast(&memprofile.fixed_allocator).allocator());

    const kernel_vmm = mem.virt.init(memprofile, @constCast(&memprofile.fixed_allocator).allocator()) catch |e| panic("Failed to initialize VMM: {s}", .{@errorName(e)});

    arch.paging.init(memprofile);

    var heap_size = memprofile.mem_kb / 10 * 1024;
    if (!std.math.isPowerOfTwo(heap_size)) heap_size = std.math.floorPowerOfTwo(usize, heap_size);

    kernel_heap = mem.heap.init(arch.VmmPayload, kernel_vmm, .{ .kernel = true, .writable = true, .cachable = true }, heap_size) catch |e| panic("Failed to initialize kernel heap: {s}", .{@errorName(e)});
    mem.allocator = kernel_heap.allocator();

    io.init();
    io.bind(2, console.writer(), null) catch |e| panic("Failed to bind serial console to stderr: {s}", .{@errorName(e)});
}
