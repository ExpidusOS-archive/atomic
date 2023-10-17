pub usingnamespace @import("kernel/constants.zig");

pub const start = @import("kernel/start.zig");

comptime {
    _ = start;
}
