pub usingnamespace @import("kernel/constants.zig");

pub const arch = @import("kernel/arch.zig");
pub const start = @import("kernel/start.zig");

comptime {
    _ = start;
}