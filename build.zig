const std = @import("std");

pub const sdk = @import("src/atomic/sdk.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const tasking = b.option(sdk.kconsts.Tasking, "tasking", "The kernel tasking mode") orelse .none;
    const _device = sdk.standardDeviceOption(b);

    const metaplus = b.dependency("metaplus", .{
        .target = target,
        .optimize = optimize,
    });

    const fio = b.dependency("fio", .{
        .target = target,
        .optimize = optimize,
    });

    const options = b.addOptions();
    options.addOption(sdk.kconsts.Tasking, "tasking", tasking);

    if (_device) |device| {
        options.addOption(?[]const u8, "device", device.name);
        options.addOption(?[]const u8, "platform", device.platform);
    } else {
        options.addOption(?[]const u8, "device", null);
        options.addOption(?[]const u8, "platform", null);
    }

    const atomic = b.addModule("atomic", .{
        .source_file = .{ .path = b.pathFromRoot("src/atomic.zig") },
        .dependencies = &.{ .{
            .name = "atomic-options",
            .module = options.createModule(),
        }, .{
            .name = "meta+",
            .module = metaplus.module("meta+"),
        }, .{
            .name = "fio",
            .module = fio.module("fio"),
        } },
    });

    const exe_example = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{
            .path = b.pathFromRoot("example.zig"),
        },
        .target = (if (_device) |device| device.target else null) orelse target,
        .optimize = optimize,
        .single_threaded = tasking == .none,
        .linkage = .static,
    });

    exe_example.addModule("atomic", atomic);
    sdk.applyDevice(exe_example, _device);
    b.installArtifact(exe_example);
}
