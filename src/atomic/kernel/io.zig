const std = @import("std");
const mem = @import("mem.zig");
const fd_t = @import("../os/system.zig").fd_t;

const Entry = struct {
    ptr: *anyopaque,
    write: *const fn (*anyopaque, []const u8) anyerror!usize,
};

var binded: std.AutoHashMap(fd_t, Entry) = undefined;

pub fn init() void {
    binded = std.AutoHashMap(fd_t, Entry).init(mem.allocator);
}

pub fn bind(fd: fd_t, writer: anytype) !void {
    const T = @TypeOf(writer);
    try binded.put(fd, .{
        .ptr = @constCast(&writer),
        .write = (struct {
            fn callback(ptr: *anyopaque, buf: []const u8) anyerror!usize {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.write(buf);
            }
        }).callback,
    });
}

pub inline fn unbind(fd: fd_t) void {
    _ = binded.remove(fd);
}

pub inline fn write(fd: fd_t, buf: []const u8) usize {
    return if (binded.get(fd)) |entry| entry.write(entry.ptr, buf) catch @intFromEnum(std.os.E.IO) else @intFromEnum(std.os.E.BADF);
}
