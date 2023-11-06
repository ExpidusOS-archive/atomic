const cpu = @import("cpu.zig");
const io = @import("io.zig");
const isr = @import("isr.zig");
const mem = @import("../../mem.zig");
const panic = @import("../../panic.zig").panic;

const ENTRIES_PER_DIRECTORY: u32 = 1024;
const ENTRIES_PER_TABLE: u32 = 1024;
const PAGES_PER_DIR_ENTRY: u32 = 1024;
const PAGES_PER_DIR: u32 = ENTRIES_PER_DIRECTORY * PAGES_PER_DIR_ENTRY;

pub const Directory = extern struct {
    entries: [ENTRIES_PER_DIRECTORY]DirectoryEntry,
    tables: [ENTRIES_PER_DIRECTORY]?*Table,

    pub fn copy(self: *const Directory) Directory {
        return self.*;
    }
};

pub const Table = extern struct {
    entries: [ENTRIES_PER_TABLE]TableEntry,
};

pub const TableEntry = u32;
pub const DirectoryEntry = u32;

pub const PAGE_SIZE_4MB: usize = 0x400000;
pub const PAGE_SIZE_4KB: usize = PAGE_SIZE_4MB / 1024;

pub var kernel_directory: Directory align(@as(u29, @truncate(PAGE_SIZE_4KB))) = Directory{ .entries = [_]DirectoryEntry{0} ** ENTRIES_PER_DIRECTORY, .tables = [_]?*Table{null} ** ENTRIES_PER_DIRECTORY };

fn pageFault(state: *cpu.State) u32 {
    var cr0 = asm volatile ("mov %%cr0, %[cr0]"
        : [cr0] "=r" (-> u32),
    );
    var cr2 = asm volatile ("mov %%cr2, %[cr2]"
        : [cr2] "=r" (-> u32),
    );
    var cr3 = asm volatile ("mov %%cr3, %[cr3]"
        : [cr3] "=r" (-> u32),
    );
    var cr4 = asm volatile ("mov %%cr4, %[cr4]"
        : [cr4] "=r" (-> u32),
    );

    panic("Page fault! State: {}, CR0: 0x{x}, CR2: 0x{x}, CR3: 0x{x}, CR4: 0x{x}", .{ state, cr0, cr2, cr3, cr4 });
}

pub fn init(memprofile: *const mem.Profile) void {
    _ = memprofile;
    isr.set(14, pageFault) catch |e| panic("Failed to set ISR: {s}", .{@errorName(e)});

    const dir_physaddr = @intFromPtr(mem.virtToPhys(&kernel_directory));
    asm volatile ("mov %[addr], %%cr3"
        :
        : [addr] "{eax}" (dir_physaddr),
    );
    while (true) {}
}
