const std = @import("std");
const Gdt = @This();
const io = @import("io.zig");

pub const AccessBits = packed struct {
    accessed: u1,
    read_write: u1,
    direction_conforming: u1,
    executable: u1,
    descriptor: u1,
    privilege: u2,
    present: u1,
};

pub const FlagBits = packed struct {
    reserved: u1 = 0,
    is_64bit: u1,
    is_32bit: u1,
    granularity: u1,
};

pub const Entry = packed struct {
    limit_low: u16,
    base_low: u24,
    access: AccessBits,
    limit_high: u4,
    flags: FlagBits,
    base_high: u8,

    pub fn init(base: u32, limit: u20, access: AccessBits, flags: FlagBits) Entry {
        std.debug.assert(flags.reserved == 0);
        return .{
            .limit_low = @truncate(limit),
            .base_low = @truncate(base),
            .access = .{
                .accessed = access.accessed,
                .read_write = access.read_write,
                .direction_conforming = access.direction_conforming,
                .executable = access.executable,
                .descriptor = access.descriptor,
                .privilege = access.privilege,
                .present = access.present,
            },
            .limit_high = @truncate(limit >> 16),
            .flags = .{
                .reserved = flags.reserved,
                .is_64bit = flags.is_64bit,
                .is_32bit = flags.is_32bit,
                .granularity = flags.granularity,
            },
            .base_high = @truncate(base >> 24),
        };
    }
};

pub const NULL_SEGMENT = AccessBits{
    .accessed = 0,
    .read_write = 0,
    .direction_conforming = 0,
    .executable = 0,
    .descriptor = 0,
    .privilege = 0,
    .present = 0,
};

pub const NULL_FLAGS = FlagBits{
    .is_64bit = 0,
    .is_32bit = 0,
    .granularity = 0,
};

pub const PAGING_32_BIT = FlagBits{
    .is_64bit = 0,
    .is_32bit = 1,
    .granularity = 1,
};

pub const KERNEL_SEGMENT_CODE = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conforming = 0,
    .executable = 1,
    .descriptor = 1,
    .privilege = 0,
    .present = 1,
};

pub const KERNEL_SEGMENT_DATA = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conforming = 0,
    .executable = 0,
    .descriptor = 1,
    .privilege = 0,
    .present = 1,
};

pub const USER_SEGMENT_CODE = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conforming = 0,
    .executable = 1,
    .descriptor = 1,
    .privilege = 3,
    .present = 1,
};

pub const USER_SEGMENT_DATA = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conforming = 0,
    .executable = 0,
    .descriptor = 1,
    .privilege = 3,
    .present = 1,
};

pub const Ptr = packed struct {
    limit: u16,
    base: u32,
};

pub const Offset = struct {
    code: u16 = 0,
    data: u16 = 0,
};

pub var entries = [_]Entry{
    Entry.init(0, 0, NULL_SEGMENT, NULL_FLAGS),
    Entry.init(0, 0xFFFFF, KERNEL_SEGMENT_CODE, PAGING_32_BIT),
    Entry.init(0, 0xFFFFF, KERNEL_SEGMENT_DATA, PAGING_32_BIT),
    Entry.init(0, 0xFFFFF, USER_SEGMENT_CODE, PAGING_32_BIT),
    Entry.init(0, 0xFFFFF, USER_SEGMENT_DATA, PAGING_32_BIT),
};

pub var ptr = Ptr{
    .limit = getTableSize(&entries),
    .base = undefined,
};

pub fn init() void {}

pub fn getTableSize(e: []Entry) u16 {
    return @sizeOf(Entry) * e.len - 1;
}
