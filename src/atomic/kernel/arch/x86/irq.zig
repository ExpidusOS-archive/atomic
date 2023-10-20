const std = @import("std");
const Idt = @import("idt.zig");
const cpu = @import("cpu.zig");
const pic = @import("pic.zig");
const interrupts = @import("interrupts.zig");
const panic = @import("../../panic.zig").panic;

pub const OFFSET = 32;

pub const Handler = *const fn (*cpu.State) usize;
var handlers: [16]?Handler = [_]?Handler{null} ** 16;

export fn irqHandler(state: *cpu.State) usize {
    if (state.int_num < OFFSET) {
        panic("Invaid IRQ {}: outside of range", .{state.int_num - OFFSET});
    }

    const irq: u8 = @truncate(state.int_num - OFFSET);
    var ret_esp = @intFromPtr(state);

    if (isValid(irq)) {
        if (handlers[irq]) |handler| {
            if (!pic.isSpuriousIrq(irq)) {
                ret_esp = handler(state);
                pic.sendEndOfInterrupt(irq);
            }
        } else {
            panic("Invalid IRQ {}: the interrupt was triggered but not handled.", .{irq});
        }
    } else {
        panic("Invalid IRQ {}: entry is not within range", .{irq});
    }
    return ret_esp;
}

pub fn init() void {
    comptime var i = 0;
    inline while (i < 16) : (i += 1) {
        Idt.setGate(i + OFFSET, interrupts.getStub(i + OFFSET)) catch unreachable;
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
