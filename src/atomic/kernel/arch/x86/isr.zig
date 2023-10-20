const std = @import("std");
const Idt = @import("idt.zig");
const cpu = @import("cpu.zig");
const interrupts = @import("interrupts.zig");
const panic = @import("../../panic.zig").panic;

pub const Handler = *const fn (*cpu.State) usize;
var handlers: [32]?Handler = [_]?Handler{null} ** 32;

const exception_msg: [32][]const u8 = [32][]const u8{
    "Divide By Zero",
    "Single Step (Debugger)",
    "Non Maskable Interrupt",
    "Breakpoint (Debugger)",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "No Coprocessor, Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid Task State Segment (TSS)",
    "Segment Not Present",
    "Stack Segment Overrun",
    "General Protection Fault",
    "Page Fault",
    "Unknown Interrupt",
    "x87 FPU Floating Point Error",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating Point",
    "Virtualization",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Security",
    "Reserved",
};

export fn isrHandler(state: *cpu.State) usize {
    const isr = state.int_num;
    var ret_esp = @intFromPtr(state);

    if (isValid(isr)) {
        if (handlers[isr]) |handler| {
            ret_esp = handler(state);
        } else {
            panic("Invalid ISR {} ({s}): the interrupt was triggered but not handled.\nCPU State: {}", .{ isr, exception_msg[isr], state });
        }
    } else {
        panic("Invalid ISR {}: entry is not within range", .{isr});
    }
    return ret_esp;
}

pub fn init() void {
    comptime var i = 0;
    inline while (i < 32) : (i += 1) {
        Idt.setGate(i, interrupts.getStub(i)) catch unreachable;
    }
}

pub fn isValid(i: u32) bool {
    return i < handlers.len;
}

pub fn set(i: u32, handler: Handler) error{ AlreadyExists, Invalid }!void {
    if (!isValid(i)) {
        return error.Invalid;
    }

    if (handlers[i]) |_| {
        return error.AlreadyExists;
    }

    handlers[i] = handler;
}
