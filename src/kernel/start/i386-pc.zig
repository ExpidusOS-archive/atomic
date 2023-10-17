const arch = @import("../arch.zig");

pub fn bootstrapMain() callconv(.C) noreturn {
    arch.Gdt.init();
    arch.Idt.init();
    arch.isr.init();
    arch.irq.init();

    while (true) {}
}

comptime {
    @export(bootstrapMain, .{ .name = "bootstrap_main" });
}
