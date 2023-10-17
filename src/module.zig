pub const kernel = @import("kernel.zig");
pub const options = @import("atomic-options");

comptime {
    _ = kernel.start;
}
