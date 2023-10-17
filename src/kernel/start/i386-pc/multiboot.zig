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

extern fn bootstrap_main() void;

export fn _start() align(16) linksection(".text.boot") noreturn {
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
