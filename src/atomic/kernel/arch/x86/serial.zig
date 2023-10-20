const std = @import("std");
const io = @import("io.zig");
const panic = @import("../../panic.zig").panic;

pub const Port = enum(u16) {
    COM1 = 0x3F8,
    COM2 = 0x2F8,
    COM3 = 0x3E8,
    COM4 = 0x2E8,
};

const LCR: u16 = 3;
const BAUD_MAX: u32 = 115200;
const CHAR_LEN: u8 = 8;
const SINGLE_STOP_BIT: bool = true;
const PARITY_BIT: bool = false;

pub const DEFAULT_BAUDRATE = 38400;

fn baudDivisor(baud: u32) error{InvalidBaudRate}!u16 {
    if (baud > BAUD_MAX or baud == 0)
        return error.InvalidBaudRate;
    return @truncate(BAUD_MAX / baud);
}

fn lcrValue(char_len: u8, stop_bit: bool, parity_bit: bool, msb: u1) error{InvalidCharacterLength}!u8 {
    if (char_len != 0 and (char_len < 5 or char_len > 8))
        return error.InvalidCharacterLength;
    return char_len & 0x3 |
        @as(u8, @intFromBool(stop_bit)) << 2 |
        @as(u8, @intFromBool(parity_bit)) << 3 |
        @as(u8, msb) << 7;
}

fn transmitIsEmpty(port: Port) bool {
    return io.in(u8, @intFromEnum(port) + 5) & 0x20 > 0;
}

pub const Console = struct {
    port: Port,
    baud: u32,

    pub const WriteError = error{};
    pub const Writer = std.io.Writer(Console, WriteError, write);

    pub fn init(port: Port, baud: u32) !Console {
        const self = Console{
            .port = port,
            .baud = baud,
        };
        try self.reset();
        return self;
    }

    pub fn reset(self: Console) !void {
        const divisor: u16 = try baudDivisor(self.baud);
        const port_int = @intFromEnum(self.port);
        io.out(port_int + LCR, lcrValue(0, false, false, 1) catch |e| {
            panic("Failed to initialise serial output setup: {}", .{e});
        });

        io.out(port_int, @as(u8, @truncate(divisor)));
        io.out(port_int + 1, @as(u8, @truncate(divisor >> 8)));
        io.out(port_int + LCR, lcrValue(CHAR_LEN, SINGLE_STOP_BIT, PARITY_BIT, 0) catch |e| {
            panic("Failed to setup serial properties: {}", .{e});
        });
        io.out(port_int + 1, @as(u8, 0));
    }

    pub fn writeByte(self: Console, byte: u8) void {
        while (!transmitIsEmpty(self.port)) {}
        io.out(@intFromEnum(self.port), byte);
    }

    pub fn write(self: Console, bytes: []const u8) WriteError!usize {
        var i: usize = 0;
        for (bytes) |ch| {
            self.writeByte(ch);
            i += 1;
        }
        return i;
    }

    pub fn writer(self: Console) Writer {
        return .{ .context = self };
    }
};
