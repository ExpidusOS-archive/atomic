const std = @import("std");

pub const virt = @import("mem/virt.zig");
pub const phys = @import("mem/phys.zig");

pub const Module = struct {
    region: Range,
    name: []const u8,
};

pub const Map = struct {
    virtual: Range,
    physical: ?Range,
};

pub const Range = struct {
    start: usize,
    end: usize,
};

pub const Block = struct {
    end: [*]u8,
    start: [*]u8,
};

pub const Profile = struct {
    vaddr: Block,
    physaddr: Block,
    mem_kb: usize,
    modules: []Module,
    virtual_reserved: []Map,
    physical_reserved: []Range,
    fixed_allocator: std.heap.FixedBufferAllocator,
};

pub var fixed_buffer: [1024 * 1024]u8 = undefined;
pub var fixed_buffer_allocator: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(fixed_buffer[0..]);
pub var ADDR_OFFSET: usize = undefined;

pub fn virtToPhys(v: anytype) @TypeOf(v) {
    const T = @TypeOf(v);
    return switch (@typeInfo(T)) {
        .Pointer => @ptrFromInt(@intFromPtr(v) - ADDR_OFFSET),
        .Int => v - ADDR_OFFSET,
        else => @compileError("Only pointers and integers are supported"),
    };
}

pub fn physToVirt(p: anytype) @TypeOf(p) {
    const T = @TypeOf(p);
    return switch (@typeInfo(T)) {
        .Pointer => @ptrFromInt(@intFromPtr(p) + ADDR_OFFSET),
        .Int => p + ADDR_OFFSET,
        else => @compileError("Only pointers and integers are supported"),
    };
}
