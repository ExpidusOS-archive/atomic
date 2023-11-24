const std = @import("std");
const fio = @import("fio");

pub fn main() !void {
    const stderr = std.io.getStdErr();

    try stderr.writer().print("Hello, world\n", .{});

    const pci = try fio.pci.bus.x86.create(.{
        .allocator = std.heap.page_allocator,
    });
    defer pci.deinit();

    const devices = try pci.enumerate();
    defer devices.deinit();

    for (devices.items) |dev| {
        try stderr.writer().print("{}\n", .{dev});
    }

    while (true) {}
}
