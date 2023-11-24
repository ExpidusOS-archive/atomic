pub const kernel = @import("atomic/kernel.zig");
pub const options = @import("atomic-options");
pub const os = @import("atomic/os.zig");

comptime {
    _ = kernel.start;
}
