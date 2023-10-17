const std = @import("std");
const Device = @import("../device.zig");

fn path() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}

const target = std.zig.CrossTarget{
    .cpu_arch = .x86,
    .os_tag = .freestanding,
};

pub const i386_pc_multiboot = Device{
    .platform = "pc",
    .target = target,
    .linker_script = .{
        .path = path() ++ "/i386-pc/multiboot.ld",
    },
    .code_model = .kernel,
};
