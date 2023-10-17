const std = @import("std");
const atomsdk = @import("src/atomic/sdk.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const benv = atomsdk.BuildEnv.init(b, .{
        .target = target,
        .optimize = optimize,
    });

    const example = benv.addExecutable("example", .{
        .path = "example.zig",
    });

    b.installArtifact(example);
}
