pub const kernel = @import("atomic/kernel.zig");
pub const options = @import("atomic-options");

comptime {
    _ = kernel.start;
}
