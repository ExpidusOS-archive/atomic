const std = @import("std");
const mem = @import("mem.zig");
const os = @import("../os/system.zig");

const Entry = struct {
    writer: ?struct {
        ptr: *anyopaque,
        write: *const fn (*anyopaque, []const u8) anyerror!usize,
    },
    reader: ?struct {
        ptr: *anyopaque,
        read: *const fn (*anyopaque, []const u8) anyerror!usize,
    },

    pub inline fn write(self: Entry, buf: []const u8) usize {
        if (self.writer) |w| {
            return w.write(w.ptr, buf) catch os.err(.IO);
        }
        return os.err(.PERM);
    }

    pub inline fn read(self: Entry, buf: []const u8) usize {
        if (self.reader) |r| {
            return r.read(r.ptr, buf) catch os.err(.IO);
        }
        return os.err(.PERM);
    }
};

var binded: std.AutoHashMap(os.fd_t, Entry) = undefined;

pub fn init() void {
    binded = std.AutoHashMap(os.fd_t, Entry).init(mem.allocator);
}

pub fn bind(fd: os.fd_t, writer: anytype, reader: anytype) !void {
    const Writer = @TypeOf(writer);
    const Reader = @TypeOf(reader);

    const hasWriter = @typeInfo(Writer) != .Null;
    const hasReader = @typeInfo(Reader) != .Null;

    if (!hasWriter and !hasReader) {
        @compileError("Writer and reader cannot both be null");
    }

    try binded.put(fd, .{
        .writer = if (hasWriter) .{
            .ptr = @constCast(&writer),
            .write = (struct {
                fn callback(ptr: *anyopaque, buf: []const u8) anyerror!usize {
                    const self: *Writer = @ptrCast(@alignCast(ptr));
                    return self.write(buf);
                }
            }).callback,
        } else null,
        .reader = if (hasReader) .{
            .ptr = @constCast(&reader),
            .read = (struct {
                fn callback(ptr: *anyopaque, buf: []const u8) anyerror!usize {
                    const self: *Reader = @ptrCast(@alignCast(ptr));
                    return self.reader(buf);
                }
            }).callback,
        } else null,
    });
}

pub inline fn unbind(fd: os.fd_t) void {
    _ = binded.remove(fd);
}

pub inline fn write(fd: os.fd_t, buf: []const u8) usize {
    return if (binded.get(fd)) |entry| entry.write(buf) else os.err(.BADF);
}

pub inline fn read(fd: os.fd_t, buf: []const u8) usize {
    return if (binded.get(fd)) |entry| entry.read(buf) else os.err(.BADF);
}
