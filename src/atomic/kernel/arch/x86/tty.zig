const std = @import("std");
const vga = @import("vga.zig");
const panicAt = @import("../../panic.zig").panicAt;

const Error = error{OutOfBounds};

pub const Writer = std.io.Writer(*anyopaque, Error, write);

const ROW_MIN: u16 = 0;
const ROW_TOTAL: u16 = vga.HEIGHT - ROW_MIN;

const TOTAL_NUM_PAGES: u16 = 5;
const TOTAL_CHAR_ON_PAGE: u16 = vga.WIDTH * ROW_TOTAL;
const START_OF_DISPLAYABLE_REGION: u16 = vga.WIDTH * ROW_MIN;
const VIDEO_BUFFER_SIZE: u16 = vga.WIDTH * vga.HEIGHT;

extern var KERNEL_ADDR_OFFSET: *u32;

var column: u8 = 0;
var row: u8 = 0;
var color: u8 = undefined;
var video_buffer: []volatile u16 = undefined;
var blank: u16 = undefined;

var pages: [TOTAL_NUM_PAGES][TOTAL_CHAR_ON_PAGE]u16 = init: {
    var p: [TOTAL_NUM_PAGES][TOTAL_CHAR_ON_PAGE]u16 = undefined;

    for (&p) |*page| {
        page.* = [_]u16{0} ** TOTAL_CHAR_ON_PAGE;
    }

    break :init p;
};

var page_index: u8 = 0;

fn write(_: *anyopaque, bytes: []const u8) Error!usize {
    try writeString(bytes);
    return bytes.len;
}

fn videoCopy(video_buf_offset: u16, data: []const u16, size: u16) Error!void {
    if (video_buf_offset >= video_buffer.len and
        size > video_buffer.len - video_buf_offset and
        size > data.len)
    {
        return Error.OutOfBounds;
    }

    var i: u32 = 0;
    while (i < size) : (i += 1) {
        video_buffer[video_buf_offset + i] = data[i];
    }
}

fn pageMove(dest: []u16, src: []u16, size: u16) Error!void {
    if (dest.len < size or src.len < size) {
        return Error.OutOfBounds;
    }

    if (size == 0) return;

    if (@intFromPtr(&dest[0]) < @intFromPtr(&src[0])) {
        var i: u16 = 0;
        while (i != size) : (i += 1) {
            dest[i] = src[i];
        }
    } else {
        var i = size;
        while (i != 0) {
            i -= 1;
            dest[i] = src[i];
        }
    }
}

fn setVideoBuffer(c: u16, size: u16) Error!void {
    if (size > VIDEO_BUFFER_SIZE) {
        return Error.OutOfBounds;
    }

    for (video_buffer[0..size]) |*b| {
        b.* = c;
    }
}

inline fn updateCursor() void {
    vga.updateCursor(column, row);
}

inline fn getCursor() void {
    const cursor = vga.getCursor();

    row = @truncate(cursor / vga.WIDTH);
    column = @truncate(cursor % vga.WIDTH);
}

fn putEntryAt(char: u8, x: u8, y: u8) Error!void {
    const index = y * vga.WIDTH + x;

    if (index >= VIDEO_BUFFER_SIZE) {
        return Error.OutOfBounds;
    }

    const char_entry = vga.entry(char, color);

    if (index >= START_OF_DISPLAYABLE_REGION) {
        if (page_index != 0) {
            page_index = 0;
            try videoCopy(START_OF_DISPLAYABLE_REGION, pages[page_index][0..TOTAL_CHAR_ON_PAGE], TOTAL_CHAR_ON_PAGE);

            vga.enableCursor();
            updateCursor();
        }
        pages[page_index][index - START_OF_DISPLAYABLE_REGION] = char_entry;
    }

    video_buffer[index] = char_entry;
}

fn pagesMoveRowsUp(rows: u16) Error!void {
    if (rows > ROW_TOTAL) {
        return Error.OutOfBounds;
    }

    if (rows == 0) return;

    const row_length = rows * vga.WIDTH;
    const chars_to_move = (ROW_TOTAL - rows) * vga.WIDTH;
    try pageMove(pages[TOTAL_NUM_PAGES - 1][0..chars_to_move], pages[TOTAL_NUM_PAGES - 1][row_length..], chars_to_move);

    var i = TOTAL_NUM_PAGES - 1;
    while (i > 0) : (i -= 1) {
        try pageMove(pages[i][chars_to_move..], pages[i - 1][0..row_length], row_length);
        try pageMove(pages[i - 1][0..chars_to_move], pages[i - 1][row_length..], chars_to_move);
    }

    for (pages[0][chars_to_move..]) |*p| {
        p.* = blank;
    }
}

fn scroll() void {
    if (row >= vga.HEIGHT and (row - vga.HEIGHT + 1) <= ROW_TOTAL) {
        const rows_to_move = row - vga.HEIGHT + 1;

        pagesMoveRowsUp(rows_to_move) catch {
            panicAt(@frameAddress(), "Can't move {} rows up. Must be less than {}\n", .{ rows_to_move, ROW_TOTAL });
        };

        var i: u32 = 0;
        while (i < (ROW_TOTAL - rows_to_move) * vga.WIDTH) : (i += 1) {
            video_buffer[START_OF_DISPLAYABLE_REGION + i] = video_buffer[(rows_to_move * vga.WIDTH) + START_OF_DISPLAYABLE_REGION + i];
        }

        i = 0;
        while (i < vga.WIDTH * rows_to_move) : (i += 1) {
            video_buffer[(vga.HEIGHT - rows_to_move) * vga.WIDTH + i] = blank;
        }

        row = vga.HEIGHT - 1;
    }
}

fn putChar(char: u8) Error!void {
    const column_temp = column;
    const row_temp = row;

    errdefer column = column_temp;
    errdefer row = row_temp;

    switch (char) {
        '\n' => {
            column = 0;
            row += 1;
            scroll();
        },
        '\t' => {
            column += 4;
            if (column >= vga.WIDTH) {
                column -= @truncate(vga.WIDTH);
                row += 1;
                scroll();
            }
        },
        '\r' => {
            column = 0;
        },
        // \b
        '\x08' => {
            if (column == 0) {
                if (row != 0) {
                    column = vga.WIDTH - 1;
                    row -= 1;
                }
            } else {
                column -= 1;
            }
        },
        else => {
            try putEntryAt(char, column, row);
            column += 1;
            if (column == vga.WIDTH) {
                column = 0;
                row += 1;
                scroll();
            }
        },
    }
}

pub inline fn setColor(new_color: u8) void {
    color = new_color;
    blank = vga.entry(0, color);
}

pub inline fn setCursor(r: u8, col: u8) void {
    column = col;
    row = r;
    updateCursor();
}

pub inline fn writeString(str: []const u8) Error!void {
    defer updateCursor();
    for (str) |char| {
        try putChar(char);
    }
}

pub inline fn getVideoBufferAddress() usize {
    return @intFromPtr(&KERNEL_ADDR_OFFSET) + 0xB8000;
}

pub fn init() void {
    video_buffer = @as([*]volatile u16, @ptrFromInt(getVideoBufferAddress()))[0..VIDEO_BUFFER_SIZE];

    vga.enableCursor();
    getCursor();
    setColor(vga.entryColor(0xF, 0x0));

    if (row != 0 or column != 0) {
        var row_offset: u16 = 0;
        if (vga.HEIGHT - 1 - row < ROW_MIN) {
            row_offset = ROW_MIN - (vga.HEIGHT - 1 - row);
        }

        var i: u16 = 0;
        while (i < row * vga.WIDTH) : (i += 1) {
            pages[0][i] = video_buffer[i];
        }

        i = 0;
        if (@intFromPtr(&video_buffer[ROW_MIN * vga.WIDTH]) < @intFromPtr(&video_buffer[row_offset * vga.WIDTH])) {
            while (i != row * vga.WIDTH) : (i += 1) {
                video_buffer[i + (ROW_MIN * vga.WIDTH)] = video_buffer[i + (row_offset * vga.WIDTH)];
            }
        } else {
            i = row * vga.WIDTH;
            while (i != 0) {
                i -= 1;
                video_buffer[i + (ROW_MIN * vga.WIDTH)] = video_buffer[i + (row_offset * vga.WIDTH)];
            }
        }

        setVideoBuffer(blank, START_OF_DISPLAYABLE_REGION) catch |e| {
            panicAt(@frameAddress(), "Error clearing the top 7 rows. Error: {}\n", .{e});
        };
        row += @truncate(row_offset + ROW_MIN);
    } else {
        setVideoBuffer(blank, VIDEO_BUFFER_SIZE) catch |e| {
            panicAt(@frameAddress(), "Error clearing the screen. Error: {}\n", .{e});
        };
        row = ROW_MIN;
    }
}

pub fn writer() Writer {
    return .{ .context = undefined };
}
