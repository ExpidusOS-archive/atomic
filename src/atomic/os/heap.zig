const std = @import("std");
const mem = @import("../kernel/mem.zig");

fn alloc(_: *anyopaque, n: usize, log2_align: u8, ra: usize) ?[*]u8 {
    return mem.allocator.rawAlloc(n, log2_align, ra);
}

fn resize(
    _: *anyopaque,
    buf_unaligned: []u8,
    log2_buf_align: u8,
    new_size: usize,
    return_address: usize,
) bool {
    return mem.allocator.rawResize(buf_unaligned, log2_buf_align, new_size, return_address);
}

fn free(_: *anyopaque, slice: []u8, log2_buf_align: u8, return_address: usize) void {
    return mem.allocator.rawFree(slice, log2_buf_align, return_address);
}

pub const page_allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    },
};
