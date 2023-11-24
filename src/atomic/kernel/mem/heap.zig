const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = @import("../panic.zig").panic;
const virt = @import("virt.zig");

pub const FreeListAllocator = struct {
    const Self = @This();

    const Error = error{TooSmall};
    const Header = struct {
        size: usize,
        next_free: ?*Header,

        fn init(size: usize, next_free: ?*Header) Header {
            return .{
                .size = size,
                .next_free = next_free,
            };
        }
    };

    first_free: ?*Header,

    pub fn init(start: usize, size: usize) Error!FreeListAllocator {
        if (size <= @sizeOf(Header)) return Error.TooSmall;
        return FreeListAllocator{
            .first_free = insertFreeHeader(start, size - @sizeOf(Header), null),
        };
    }

    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn insertFreeHeader(at: usize, size: usize, next_free: ?*Header) *Header {
        const node: *Header = @ptrFromInt(at);
        node.* = Header.init(size, next_free);
        return node;
    }

    fn registerFreeHeader(self: *Self, previous: ?*Header, header: ?*Header) void {
        if (previous) |p| {
            p.next_free = header;
        } else {
            self.first_free = header;
        }
    }

    fn free(ctx: *anyopaque, mem: []u8, alignment: u8, ret_addr: usize) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        _ = alignment;
        _ = ret_addr;

        const size = @max(mem.len, @sizeOf(Header));
        const addr: usize = @intFromPtr(mem.ptr);
        var header = insertFreeHeader(addr, size - @sizeOf(Header), null);
        if (self.first_free) |first| {
            var prev: ?*Header = null;
            if (@intFromPtr(first) < addr) {
                prev = first;
                while (prev.?.next_free) |next| {
                    if (@intFromPtr(next) > addr) break;
                    prev = next;
                }
            }

            header.next_free = if (prev) |p| p.next_free else first;
            self.registerFreeHeader(prev, header);

            if (header.next_free) |next| {
                if (@intFromPtr(next) == @intFromPtr(header) + header.size + @sizeOf(Header)) {
                    header.size += next.size + @sizeOf(Header);
                    header.next_free = next.next_free;
                }
            }

            if (prev) |p| {
                p.size += header.size + @sizeOf(Header);
                p.next_free = header.next_free;
            }
        } else {
            self.first_free = header;
        }
    }

    fn resize(ctx: *anyopaque, old_mem: []u8, size_alignment: u8, new_size: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (new_size == 0) {
            free(ctx, old_mem, size_alignment, ret_addr);
            return true;
        }

        if (new_size == old_mem.len) return true;

        const end = @intFromPtr(old_mem.ptr) + old_mem.len;
        var real_size = if (size_alignment > 1) std.mem.alignAllocLen(old_mem.len, new_size, size_alignment) else new_size;

        var free_node = self.first_free;
        var next: ?*Header = null;
        var prev: ?*Header = null;
        while (free_node) |f| {
            if (@intFromPtr(f) == end) {
                next = f;
                break;
            } else if (@intFromPtr(f) > end) {
                break;
            }
            prev = f;
            free_node = f.next_free;
        }

        if (real_size > old_mem.len) {
            if (next) |n| {
                if (old_mem.len + n.size + @sizeOf(Header) < real_size) return false;

                const size_diff = real_size - old_mem.len;
                const consumes_whole_neighbour = size_diff == n.size + @sizeOf(Header);
                if (!consumes_whole_neighbour and n.size + @sizeOf(Header) - size_diff < @sizeOf(Header)) return false;
                var new_next: ?*Header = n.next_free;
                if (!consumes_whole_neighbour) {
                    new_next = insertFreeHeader(end + size_diff, n.size - size_diff, n.next_free);
                }
                self.registerFreeHeader(prev, new_next);
                return true;
            }
            return false;
        } else {
            const size_diff = old_mem.len - real_size;
            if (size_diff < @sizeOf(Header)) {
                return true;
            }

            if (real_size < @sizeOf(Header)) {
                real_size = @sizeOf(Header);
            }

            var new_next = insertFreeHeader(@intFromPtr(old_mem.ptr) + real_size, size_diff - @sizeOf(Header), if (prev) |p| p.next_free else self.first_free);
            self.registerFreeHeader(prev, new_next);

            if (next) |n| {
                new_next.size += n.size + @sizeOf(Header);
                new_next.next_free = n.next_free;
            }

            return true;
        }
    }

    fn alloc(ctx: *anyopaque, size: usize, alignment: u8, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));

        _ = ret_addr;
        if (self.first_free == null) return null;

        const real_size = @max(if (alignment > 1) std.mem.alignAllocLen(size, size, alignment) else size, @sizeOf(Header));

        var free_header = self.first_free;
        var prev: ?*Header = null;
        var backup: ?*Header = null;
        var backup_prev: ?*Header = null;

        const alloc_to = find: while (free_header) |h| : ({
            prev = h;
            free_header = h.next_free;
        }) {
            if (h.size + @sizeOf(Header) < real_size) {
                continue;
            }

            const addr = @intFromPtr(h);
            var alignment_padding: usize = 0;

            if ((alignment > 1 and !std.mem.isAligned(addr, alignment)) or !std.mem.isAligned(addr, @alignOf(Header))) {
                alignment_padding = alignment - (addr % alignment);
                if (h.size + @sizeOf(Header) < real_size + alignment_padding) {
                    continue;
                }

                if (alignment_padding < @sizeOf(Header)) {
                    backup = h;
                    backup_prev = prev;
                    continue;
                }
            }

            if (@sizeOf(Header) + h.size - alignment_padding - real_size < @sizeOf(Header)) {
                backup = h;
                backup_prev = prev;
                continue;
            }

            break :find h;
        } else backup;

        if (alloc_to == backup) {
            prev = backup_prev;
        }

        if (alloc_to) |x| {
            var header = x;
            const addr: usize = @intFromPtr(header);
            var alignment_padding: usize = 0;
            if (alignment > 1 and !std.mem.isAligned(addr, alignment)) {
                alignment_padding = alignment - (addr % alignment);
            }

            if (header.size > real_size + alignment_padding) {
                const at = @intFromPtr(header) + real_size + alignment_padding;
                if (!std.mem.isAligned(at, @alignOf(Header))) {
                    alignment_padding += @alignOf(Header) - (at % @alignOf(Header));
                }
            }

            if (alignment_padding >= @sizeOf(Header)) {
                header = insertFreeHeader(addr + alignment_padding, header.size - alignment_padding, header.next_free);

                const left = insertFreeHeader(addr, alignment_padding - @sizeOf(Header), header.next_free);
                self.registerFreeHeader(prev, left);
                prev = left;
                alignment_padding = 0;
            }

            if (header.size > real_size + alignment_padding) {
                header.next_free = insertFreeHeader(@intFromPtr(header) + real_size + alignment_padding, header.size - real_size - alignment_padding, header.next_free);
            }
            self.registerFreeHeader(prev, header.next_free);

            return @ptrCast(@as([*]u8, @ptrFromInt(@intFromPtr(header)))[0..std.mem.alignAllocLen(size, size, alignment)]);
        }

        return null;
    }
};

pub fn init(comptime Payload: type, heap_vmm: *virt.Manager(Payload), attribs: virt.Attributes, heap_size: usize) (FreeListAllocator.Error || Allocator.Error)!FreeListAllocator {
    const heap_start = (try heap_vmm.alloc(heap_size / virt.BLOCK_SIZE, null, attribs)) orelse panic("Out of memory, failed to allocate kernel heap", .{});
    errdefer heap_vmm.free(heap_start) catch unreachable;
    return try FreeListAllocator.init(heap_start, heap_size);
}
