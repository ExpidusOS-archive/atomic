const std = @import("std");
const arch = @import("../../arch.zig");
const mem = @import("../../mem.zig");
const panic = @import("../../panic.zig").panic;

const MultiBootHeader = extern struct {
    magic: i32 = MAGIC,
    flags: i32,
    checksum: i32,

    pub fn init(flags: i32) MultiBootHeader {
        return .{
            .flags = flags,
            .checksum = -(MAGIC + flags),
        };
    }

    pub const MAGIC = 0x1BADB002;
    pub const Flags = struct {
        pub const ALIGN = 1 << 0;
        pub const MEMINFO = 1 << 1;
    };
};

const MultiBootInfo = packed struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mods_count: u32,
    mods_addr: u32,
    binary: packed union {
        aout: packed struct {
            tabsize: u32,
            strsize: u32,
            addr: u32,
            reserved: u32,
        },
        elf: packed struct {
            num: u32,
            size: u32,
            addr: u32,
            shndx: u32,
        },
    },
    mmap_len: u32,
    mmap_addr: u32,
    drives_len: u32,
    drives_addr: u32,
    cfgtbl: u32,
    bootloader_name: u32,
    apm_table: u32,
};

const MultiBootMemoryMap = packed struct {
    size: u32,
    addr: u64,
    len: u64,
    type: u32,
};

const MultiBootModuleList = packed struct {
    mod_start: u32,
    mod_end: u32,
    cmdline: u32,
    pad: u32,
};

pub var multiboot_info: *const MultiBootInfo = undefined;

export var multiboot_hdr align(4) linksection(".rodata.boot") = MultiBootHeader.init(MultiBootHeader.Flags.ALIGN | MultiBootHeader.Flags.MEMINFO);

export var kernel_stack: [16 * 1024]u8 align(16) linksection(".bss.stack") = undefined;
extern var KERNEL_ADDR_OFFSET: *u32;
extern var KERNEL_VADDR_START: *u32;
extern var KERNEL_VADDR_END: *u32;
extern var KERNEL_PHYSADDR_START: *u32;
extern var KERNEL_PHYSADDR_END: *u32;
extern var KERNEL_STACK_START: *u32;
extern var KERNEL_STACK_END: *u32;

const KERNEL_PAGE_NUMBER = 0xC0000000 >> 22;
const KERNEL_NUM_PAGES = 1;

export var boot_page_directory: [1024]u32 align(4096) linksection(".rodata.boot") = init: {
    @setEvalBranchQuota(1024);
    var dir: [1024]u32 = undefined;

    dir[0] = 0x00000083;

    var i = 0;
    var idx = 1;

    while (i < KERNEL_PAGE_NUMBER - 1) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }

    i = 0;
    while (i < KERNEL_NUM_PAGES) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0x00000083 | (i << 22);
    }
    i = 0;
    while (i < 1024 - KERNEL_PAGE_NUMBER - KERNEL_NUM_PAGES) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }
    break :init dir;
};

export fn _start() align(16) linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\.extern boot_page_directory
        \\mov $boot_page_directory, %%ecx
        \\mov %%ecx, %%cr3
    );

    asm volatile (
        \\mov %%cr4, %%ecx
        \\or $0x00000010, %%ecx
        \\mov %%ecx, %%cr4
    );

    asm volatile (
        \\mov %%cr0, %%ecx
        \\or $0x80000000, %%ecx
        \\mov %%ecx, %%cr0
    );
    asm volatile ("jmp _start_higher");
    while (true) {}
}

fn initMem() std.mem.Allocator.Error!mem.Profile {
    const mods_count = multiboot_info.mods_count;
    mem.ADDR_OFFSET = @intFromPtr(&KERNEL_ADDR_OFFSET);

    const mmap_addr = multiboot_info.mmap_addr;
    const num_mmap_entries = multiboot_info.mmap_len / @sizeOf(MultiBootMemoryMap);

    const allocator = mem.fixed_buffer_allocator.allocator();
    var reserved_physical_mem = std.ArrayList(mem.Range).init(allocator);
    var reserved_virtual_mem = std.ArrayList(mem.Map).init(allocator);
    const mem_map = @as([*]MultiBootMemoryMap, @ptrFromInt(mmap_addr))[0..num_mmap_entries];

    for (mem_map) |entry| {
        if (entry.type != 1 and entry.len < std.math.maxInt(usize)) {
            const end: usize = if (entry.addr > std.math.maxInt(usize) - entry.len) std.math.maxInt(usize) else @intCast(entry.addr + entry.len);
            try reserved_physical_mem.append(.{
              .start = @intCast(entry.addr),
              .end = end,
            });
        }
    }

    const kernel_virt = mem.Range{
        .start = @intFromPtr(&KERNEL_VADDR_START),
        .end = @intFromPtr(&KERNEL_STACK_START),
    };
    const kernel_phy = mem.Range{
        .start = mem.virtToPhys(kernel_virt.start),
        .end = mem.virtToPhys(kernel_virt.end),
    };
    try reserved_virtual_mem.append(.{
        .virtual = kernel_virt,
        .physical = kernel_phy,
    });

    const mb_region = mem.Range{
        .start = @intFromPtr(multiboot_info),
        .end = @intFromPtr(multiboot_info) + @sizeOf(MultiBootInfo),
    };
    const mb_physical = mem.Range{
        .start = mem.virtToPhys(mb_region.start),
        .end = mem.virtToPhys(mb_region.end),
    };
    try reserved_virtual_mem.append(.{
        .virtual = mb_region,
        .physical = mb_physical,
    });

    const boot_modules = @as([*]MultiBootModuleList, @ptrFromInt(mem.physToVirt(multiboot_info.mods_addr)))[0..mods_count];
    var modules = std.ArrayList(mem.Module).init(allocator);
    for (boot_modules) |module| {
        const virtual = mem.Range{
            .start = mem.physToVirt(module.mod_start),
            .end = mem.physToVirt(module.mod_end),
        };
        const physical = mem.Range{
            .start = module.mod_start,
            .end = module.mod_end,
        };
        try modules.append(.{
            .region = virtual,
            .name = std.mem.span(mem.physToVirt(@as([*:0]u8, @ptrFromInt(module.cmdline)))),
        });
        try reserved_virtual_mem.append(.{
            .physical = physical,
            .virtual = virtual,
        });
    }

    const kernel_stack_virt = mem.Range{
        .start = @intFromPtr(&KERNEL_STACK_START),
        .end = @intFromPtr(&KERNEL_STACK_END),
    };
    const kernel_stack_phy = mem.Range{
        .start = mem.virtToPhys(kernel_stack_virt.start),
        .end = mem.virtToPhys(kernel_stack_virt.end),
    };
    try reserved_virtual_mem.append(.{
        .virtual = kernel_stack_virt,
        .physical = kernel_stack_phy,
    });

    // FIXME: why is it reporting 1016kB?
    return mem.Profile{
        .vaddr = .{
            .end = @as([*]u8, @ptrCast(&KERNEL_VADDR_END)),
            .start = @as([*]u8, @ptrCast(&KERNEL_VADDR_START)),
        },
        .physaddr = .{
            .end = @as([*]u8, @ptrCast(&KERNEL_PHYSADDR_END)),
            .start = @as([*]u8, @ptrCast(&KERNEL_PHYSADDR_START)),
        },
        .mem_kb = multiboot_info.mem_upper + multiboot_info.mem_lower + 1024,
        .modules = modules.items,
        .physical_reserved = reserved_physical_mem.items,
        .virtual_reserved = reserved_virtual_mem.items,
        .fixed_allocator = mem.fixed_buffer_allocator,
    };
}

export fn _start_higher() noreturn {
    asm volatile ("invlpg (0)");

    asm volatile (
        \\.extern KERNEL_STACK_END
        \\mov $KERNEL_STACK_END, %%esp
        \\sub $32, %%esp
        \\mov %%esp, %%ebp
    );

    const mb_info_addr = asm (
        \\mov %%ebx, %[res]
        : [res] "=r" (-> usize),
    ) + @intFromPtr(&KERNEL_ADDR_OFFSET);

    multiboot_info = @ptrFromInt(mb_info_addr);
    @import("../i386-pc.zig").bootstrapStage1();
    @import("../i386-pc.zig").bootstrapStage2(initMem() catch |e| panic("Failed to initialize memory info: {}", .{e}));
    while (true) {}
}
