pub usingnamespace @import("kernel/constants.zig");
pub usingnamespace @import("kernel/panic.zig"); 

pub const arch = @import("kernel/arch.zig");
pub const mem = @import("kernel/mem.zig");
pub const start = @import("kernel/start.zig");

comptime {
    _ = start;
}
