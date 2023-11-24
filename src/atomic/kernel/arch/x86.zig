const mem = @import("../mem.zig");

pub const Gdt = @import("x86/gdt.zig");
pub const Idt = @import("x86/idt.zig");
pub const cpu = @import("x86/cpu.zig");
pub const io = @import("x86/io.zig");
pub const isr = @import("x86/isr.zig");
pub const irq = @import("x86/irq.zig");
pub const pic = @import("x86/pic.zig");
pub const paging = @import("x86/paging.zig");
pub const serial = @import("x86/serial.zig");
pub const tty = @import("x86/tty.zig");
pub const vga = @import("x86/vga.zig");

pub const VmmPayload = *paging.Directory;
pub const KERNEL_VMM_PAYLOAD = &paging.kernel_directory;
pub const MEMORY_BLOCK_SIZE: usize = paging.PAGE_SIZE_4KB;
pub const VMM_MAPPER = mem.virt.Mapper(VmmPayload){ .mapFn = paging.map, .unmapFn = paging.unmap };
