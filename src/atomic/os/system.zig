const builtin = @import("builtin");
const std = @import("std");
const io = @import("../kernel/io.zig");

pub const fd_t = usize;
pub const mode_t = usize;
pub const ino_t = usize;

pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;
pub const PATH_MAX = 4096;

pub const E = enum(u16) {
    SUCCESS,
    IO,
    BADF,
    AGAIN,
    WOULDBLOCK,
    DESTADDRREQ,
    DQUOT,
    FAULT,
    FBIG,
    INTR,
    INVAL,
    NOSPC,
    PIPE,
    PERM,
    CONNRESET,
    BUSY,
};

pub fn write(fd: fd_t, buf: [*]const u8, count: usize) usize {
    return io.write(fd, buf[0..count]);
}

pub fn getErrno(r: usize) E {
    const signed_r = @as(isize, @bitCast(r));
    const int = if (signed_r > -4096 and signed_r < 0) -signed_r else 0;
    return @as(E, @enumFromInt(int));
}

pub fn close(_: fd_t) usize {
    return @intFromEnum(E.INVAL);
}
