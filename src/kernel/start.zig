const root = @import("root");
const std = @import("std");
const options = @import("atomic-options");

const starts = struct {
    pub const i386_pc_multiboot = @import("start/i386-pc/multiboot.zig");
};

const field: ?[]const u8 = blk: {
    if (options.device) |device| {
        var name: [device.len]u8 = undefined;
        _ = std.mem.replace(u8, device, "-", "_", &name);
        break :blk &name;
    }
    break :blk null;
};

pub usingnamespace blk: {
    if (field) |f| {
        break :blk @field(starts, f);
    }
    break :blk {};
};

comptime {
    if (field) |f| {
        _ = @field(starts, f);
    }

    _ = root;
}
