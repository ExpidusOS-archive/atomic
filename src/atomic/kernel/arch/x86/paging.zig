const io = @import("io.zig");

pub const Directory = packed struct {
    entries: [1024]DirectoryEntry,
    tables: [1024]?*Table,

    pub fn copy(self: *const Directory) Directory {
        return self.*;
    }
};

pub const Table = packed struct {
    entries: [1024]TableEntry,
};

pub const TableEntry = u32;
pub const DirectoryEntry = u32;

pub fn init() void {}
