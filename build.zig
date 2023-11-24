const std = @import("std");

pub const sdk = @import("src/atomic/sdk.zig");

pub const ModuleOptions = struct {
    target: std.zig.CrossTarget,
    optimize: std.builtin.OptimizeMode,
    device: ?sdk.Device,
    tasking: sdk.kconsts.Tasking,
};

pub fn addModule(b: *std.Build, options: ModuleOptions) *std.Build.Module {
    const opts = b.addOptions();
    opts.addOption(sdk.kconsts.Tasking, "tasking", options.tasking);

    const metaplus = b.dependency("metaplus", .{
        .target = options.target,
        .optimize = options.optimize,
    });

    const fio = b.dependency("fio", .{
        .target = options.target,
        .optimize = options.optimize,
    });

    if (options.device) |device| {
        opts.addOption(?[]const u8, "device", device.name);
        opts.addOption(?[]const u8, "platform", device.platform);
    } else {
        opts.addOption(?[]const u8, "device", null);
        opts.addOption(?[]const u8, "platform", null);
    }

    return b.createModule(.{
        .source_file = .{ .path = b.pathFromRoot("src/atomic.zig") },
        .dependencies = &.{ .{
            .name = "atomic-options",
            .module = opts.createModule(),
        }, .{
            .name = "meta+",
            .module = metaplus.module("meta+"),
        }, .{
            .name = "fio",
            .module = fio.module("fio"),
        } },
    });
}

pub const ExecutableOptions = struct {
    name: []const u8,
    root_source_file: ?std.Build.LazyPath = null,
    version: ?std.SemanticVersion = null,
    dependencies: []const std.Build.ModuleDependency = &.{},
    target: std.zig.CrossTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: ?std.Build.Step.Compile.Linkage = .static,
    device: ?sdk.Device,
    tasking: sdk.kconsts.Tasking,
};

fn applyExecutable(exe: *std.Build.Step.Compile, options: ExecutableOptions) void {
    const target = (if (options.device) |device| device.target else null) orelse options.target;

    const atomic = addModule(exe.step.owner, .{
        .target = target,
        .optimize = options.optimize,
        .device = options.device,
        .tasking = options.tasking,
    });

    exe.addModule("atomic", atomic);

    if (options.root_source_file) |root_source_file| {
        const deps = exe.step.owner.allocator.alloc(std.Build.ModuleDependency, options.dependencies.len + 1) catch @panic("OOM");

        for (options.dependencies, 0..) |dep, i| deps[i] = dep;
        deps[options.dependencies.len] = .{
            .name = "atomic",
            .module = atomic,
        };

        exe.addAnonymousModule("atomic-root", .{
            .source_file = root_source_file,
            .dependencies = deps,
        });
    }

    sdk.applyDevice(exe, options.device);
}

pub fn addExecutable(b: *std.Build, options: ExecutableOptions) *std.Build.Step.Compile {
    const target = (if (options.device) |device| device.target else null) orelse options.target;

    const exe = b.addExecutable(.{
        .name = options.name,
        .root_source_file = .{
            .path = b.pathFromRoot("src/root.zig"),
        },
        .version = options.version,
        .target = target,
        .optimize = options.optimize,
        .single_threaded = options.tasking == .none,
        .linkage = options.linkage,
    });

    applyExecutable(exe, options);
    return exe;
}

pub const TestOptions = struct {
    name: []const u8 = "test",
    root_source_file: std.Build.LazyPath,
    version: ?std.SemanticVersion = null,
    dependencies: []const std.Build.ModuleDependency = &.{},
    target: std.zig.CrossTarget,
    optimize: std.builtin.OptimizeMode,
    device: ?sdk.Device,
    tasking: sdk.kconsts.Tasking,
};

pub fn addTest(b: *std.Build, options: TestOptions) *std.Build.Step.Compile {
    const target = (if (options.device) |device| device.target else null) orelse options.target;

    const exe = b.addTest(.{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .version = options.version,
        .target = target,
        .optimize = options.optimize,
        .single_threaded = options.tasking == .none,
        .test_runner = b.pathFromRoot("src/test_runner.zig"),
    });

    applyExecutable(exe, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .version = options.version,
        .dependencies = options.dependencies,
        .target = target,
        .optimize = options.optimize,
        .linkage = exe.linkage,
        .device = options.device,
        .tasking = options.tasking,
    });
    return exe;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const tasking = b.option(sdk.kconsts.Tasking, "tasking", "The kernel tasking mode") orelse .none;
    const device = sdk.standardDeviceOption(b);

    const exe_example = addExecutable(b, .{
        .name = "example",
        .root_source_file = .{
            .path = b.pathFromRoot("example.zig"),
        },
        .target = target,
        .optimize = optimize,
        .tasking = tasking,
        .device = device,
    });
    b.installArtifact(exe_example);

    const exe_test = addTest(b, .{
        .root_source_file = .{
            .path = b.pathFromRoot("src/tests.zig"),
        },
        .target = target,
        .optimize = optimize,
        .tasking = tasking,
        .device = device,
    });
    b.installArtifact(exe_test);
}
