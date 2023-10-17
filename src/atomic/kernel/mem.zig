const std = @import("std");

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

pub fn virtToPhys(virt: anytype) @TypeOf(virt) {
    const T = @TypeOf(virt);
    return switch (@typeInfo(T)) {
        .Pointer => @ptrFromInt(@intFromPtr(virt) - ADDR_OFFSET),
        .Int => virt - ADDR_OFFSET,
        else => @compileError("Only pointers and integers are supported"),
    };
}

pub fn physToVirt(phys: anytype) @TypeOf(phys) {
    const T = @TypeOf(phys);
    return switch (@typeInfo(T)) {
        .Pointer => @ptrFromInt(@intFromPtr(phys) + ADDR_OFFSET),
        .Int => phys + ADDR_OFFSET,
        else => @compileError("Only pointers and integers are supported"),
    };
}
