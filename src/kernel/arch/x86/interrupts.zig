const Idt = @import("idt.zig");
const cpu = @import("cpu.zig");
const irq = @import("irq.zig");

extern fn irqHandler(state: *cpu.State) usize;
extern fn isrHandler(state: *cpu.State) usize;

export fn handler(state: *cpu.State) usize {
    if (state.int_num < irq.OFFSET) {
        return isrHandler(state);
    } else {
        return irqHandler(state);
    }
}

export fn commonStub() callconv(.Naked) void {
    asm volatile (
        \\pusha
        \\push  %%ds
        \\push  %%es
        \\push  %%fs
        \\push  %%gs
        \\mov %%cr3, %%eax
        \\push %%eax
        \\mov   $0x10, %%ax
        \\mov   %%ax, %%ds
        \\mov   %%ax, %%es
        \\mov   %%ax, %%fs
        \\mov   %%ax, %%gs
        \\mov   %%esp, %%eax
        \\push  %%eax
        \\call  handler
        \\mov   %%eax, %%esp
    );

    asm volatile (
        \\pop   %%eax
        \\mov   %%cr3, %%ebx
        \\cmp   %%eax, %%ebx
        \\je    same_cr3
        \\mov   %%eax, %%cr3
        \\same_cr3:
        \\pop   %%gs
        \\pop   %%fs
        \\pop   %%es
        \\pop   %%ds
        \\popa
    );
    asm volatile (
        \\add   $0x1C, %%esp
        \\sub   $0x14, %%esp
        \\iret
    );
}

pub fn getStub(comptime i: u32) Idt.Handler {
    return (struct {
        fn func() callconv(.Naked) void {
            asm volatile ("cli");

            if (i != 8 and !(i >= 10 and i <= 14) and i != 17) {
                asm volatile ("pushl $0");
            }

            asm volatile (
                \\ pushl %[nr]
                \\ jmp commonStub
                :
                : [nr] "n" (i),
            );
        }
    }).func;
}
