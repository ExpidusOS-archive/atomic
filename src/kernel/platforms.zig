const std = @import("std");
const options = @import("atomic-options");

const platforms = struct {
    pub const pc = @import("platforms/pc.zig");
};

const field: ?[]const u8 = blk: {
    if (options.platform) |platform| {
        var name: [platform.len]u8 = undefined;
        _ = std.mem.replace(u8, platform, "-", "_", &name);
        break :blk &name;
    }
    break :blk null;
};

pub usingnamespace blk: {
    if (field) |f| {
        break :blk @field(platforms, f);
    }
    break :blk {};
};
