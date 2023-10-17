pub fn bootstrapMain() callconv(.C) noreturn {
    while (true) {}
}

comptime {
    @export(bootstrapMain, .{ .name = "bootstrap_main" });
}
