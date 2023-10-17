const Gdt = @import("gdt.zig");
const Idt = @import("idt.zig");

pub fn in(comptime Type: type, port: u16) Type {
    return switch (Type) {
        u8 => asm volatile ("inb %[port], %[result]"
            : [result] "={al}" (-> Type),
            : [port] "N{dx}" (port),
        ),
        u16 => asm volatile ("inw %[port], %[result]"
            : [result] "={ax}" (-> Type),
            : [port] "N{dx}" (port),
        ),
        u32 => asm volatile ("inl %[port], %[result]"
            : [result] "={eax}" (-> Type),
            : [port] "N{dx}" (port),
        ),
        else => @compileError("Invalid data type. Only u8, u16 or u32, found: " ++ @typeName(Type)),
    };
}

pub fn out(port: u16, data: anytype) void {
    switch (@TypeOf(data)) {
        u8 => asm volatile ("outb %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{al}" (data),
        ),
        u16 => asm volatile ("outw %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{ax}" (data),
        ),
        u32 => asm volatile ("outl %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{eax}" (data),
        ),
        else => @compileError("Invalid data type. Only u8, u16 or u32, found: " ++ @typeName(@TypeOf(data))),
    }
}

pub fn lgdt(gdt: *const Gdt.Ptr) void {
    asm volatile ("lgdt (%%eax)"
        :
        : [gdt] "{eax}" (gdt),
    );

    asm volatile ("mov %%bx, %%ds"
        :
        : [KERNEL_DATA_OFFSET] "{bx}" (Gdt.KERNEL_DATA_OFFSET),
    );

    asm volatile ("mov %%bx, %%es");
    asm volatile ("mov %%bx, %%fs");
    asm volatile ("mov %%bx, %%gs");
    asm volatile ("mov %%bx, %%ss");

    asm volatile (
        \\ljmp $0x08, $1f
        \\1:
    );
}

pub fn lidt(idt: *const Idt.Ptr) void {
    asm volatile ("lidt (%%eax)"
        :
        : [idt] "{eax}" (idt),
    );
}

pub fn sidt() Idt.Ptr {
    var idt = Idt.Ptr{ .limit = 0, .base = 0 };
    asm volatile ("sidt %[tab]"
        : [tab] "=m" (idt),
    );
    return idt;
}
