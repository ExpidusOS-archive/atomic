const std = @import("std");
const Device = @This();

name: ?[]const u8 = null,
platform: ?[]const u8 = null,
target: ?std.zig.CrossTarget = null,
linker_script: ?std.Build.LazyPath = null,
code_model: ?std.builtin.CodeModel = null,
