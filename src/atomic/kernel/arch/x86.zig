pub const Gdt = @import("x86/gdt.zig");
pub const Idt = @import("x86/idt.zig");
pub const cpu = @import("x86/cpu.zig");
pub const io = @import("x86/io.zig");
pub const isr = @import("x86/isr.zig");
pub const irq = @import("x86/irq.zig");
pub const pic = @import("x86/pic.zig");
pub const paging = @import("x86/paging.zig");
pub const serial = @import("x86/serial.zig");

pub const VmmPayload = *paging.Directory;
pub const KERNEL_VMM_PAYLOAD = &paging.kernel_directory;
