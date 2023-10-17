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

export var multiboot_hdr align(4) linksection(".rodata.boot") = MultiBootHeader.init(MultiBootHeader.Flags.ALIGN | MultiBootHeader.Flags.MEMINFO);

export var kernel_stack: [16 * 1024]u8 align(16) linksection(".bss.stack") = undefined;
extern var KERNEL_ADDR_OFFSET: *u32;

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

extern fn bootstrap_main() void;

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

export fn _start_higher() noreturn {
    asm volatile (
        \\.extern KERNEL_STACK_END
        \\mov $KERNEL_STACK_END, %%esp
        \\sub $32, %%esp
        \\mov %%esp, %%ebp
    );

    bootstrap_main();
    while (true) {}
}

comptime {
    _ = @import("../i386-pc.zig");
}
