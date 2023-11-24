const std = @import("std");
const io = @import("io.zig");

const PORT_ADDRESS: u16 = 0x03D4;
const PORT_DATA: u16 = 0x03D5;

const REG_MAXIMUM_SCAN_LINE: u8 = 0x09;
const REG_CURSOR_START: u8 = 0x0A;
const REG_CURSOR_END: u8 = 0x0B;
const REG_CURSOR_LOCATION_HIGH: u8 = 0x0E;
const REG_CURSOR_LOCATION_LOW: u8 = 0x0F;

const CURSOR_SCANLINE_START: u8 = 0x0;
const CURSOR_SCANLINE_MIDDLE: u8 = 0xE;
const CURSOR_SCANLINE_END: u8 = 0xF;
const CURSOR_DISABLE: u8 = 0x20;

pub const WIDTH: u16 = 80;
pub const HEIGHT: u16 = 25;

pub const CursorShape = enum {
    underline,
    block,
};

var cursor_scanline: @Vector(2, u8) = undefined;

inline fn sendPort(index: u8) void {
    io.out(PORT_ADDRESS, index);
}

inline fn sendData(data: u8) void {
    io.out(PORT_DATA, data);
}

inline fn getData() u8 {
    return io.in(u8, PORT_DATA);
}

inline fn sendPortData(index: u8, data: u8) void {
    sendPort(index);
    sendData(data);
}

inline fn getPortData(index: u8) u8 {
    sendPort(index);
    return getData();
}

pub fn entryColor(fg: u4, bg: u4) u8 {
    return fg | @as(u8, bg) << 4;
}

pub fn entry(char: u8, colour: u8) u16 {
    return char | @as(u16, colour) << 8;
}

pub fn updateCursor(x: u16, y: u16) void {
    var pos: u16 = undefined;

    if (x < WIDTH and y < HEIGHT) {
        pos = y * WIDTH + x;
    } else {
        pos = (HEIGHT - 1) * WIDTH + (WIDTH - 1);
    }

    const pos_upper = (pos >> 8) & 0x00FF;
    const pos_lower = pos & 0x00FF;

    sendPortData(REG_CURSOR_LOCATION_LOW, @truncate(pos_lower));
    sendPortData(REG_CURSOR_LOCATION_HIGH, @truncate(pos_upper));
}

pub fn getCursor() u16 {
    var cursor: u16 = 0;

    cursor |= getPortData(REG_CURSOR_LOCATION_LOW);
    cursor |= @as(u16, getPortData(REG_CURSOR_LOCATION_HIGH)) << 8;

    return cursor;
}

pub fn enableCursor() void {
    sendPortData(REG_CURSOR_START, cursor_scanline[0]);
    sendPortData(REG_CURSOR_END, cursor_scanline[1]);
}

pub fn disableCursor() void {
    sendPortData(REG_CURSOR_START, CURSOR_DISABLE);
}

pub fn setCursorShape(shape: CursorShape) void {
    switch (shape) {
        CursorShape.underline => {
            cursor_scanline[0] = CURSOR_SCANLINE_MIDDLE;
            cursor_scanline[1] = CURSOR_SCANLINE_END;
        },
        CursorShape.block => {
            cursor_scanline[0] = CURSOR_SCANLINE_START;
            cursor_scanline[1] = CURSOR_SCANLINE_END;
        },
    }

    sendPortData(REG_CURSOR_START, cursor_scanline[0]);
    sendPortData(REG_CURSOR_END, cursor_scanline[1]);
}

pub fn init() void {
    sendPortData(REG_MAXIMUM_SCAN_LINE, CURSOR_SCANLINE_END);
    setCursorShape(.underline);
}
