const std = @import("std");
const Idt = @import("idt.zig");
const cpu = @import("cpu.zig");
const interrupts = @import("interrupts.zig");

pub const Handler = *const fn (*cpu.State) usize;
var handlers: [32]?Handler = [_]?Handler{null} ** 32;

export fn isrHandler(state: *cpu.State) usize {
    const isr = state.int_num;
    var ret_esp = @intFromPtr(state);

    if (isValid(isr)) {
        if (handlers[isr]) |handler| {
            ret_esp = handler(state);
        } else {
            std.debug.panic("Invalid ISR {}: the interrupt was triggered but not handled.", .{isr});
        }
    } else {
        std.debug.panic("Invalid ISR {}: entry is not within range", .{isr});
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
