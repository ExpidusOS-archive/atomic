const std = @import("std");
const metap = if (@hasDecl(@import("root"), "dependencies")) @import("metaplus").@"meta+" else @import("meta+");

pub const kconsts = @import("kernel/constants.zig");
pub const devices = @import("sdk/devices.zig");
pub const Device = @import("sdk/device.zig");
pub const DeviceType = metap.fields.rename(metap.enums.fromDecls(devices), "_", "-");

pub fn standardDeviceOption(b: *std.Build) ?Device {
    const option = b.option(DeviceType, "device", "The name of the device to build for");

    if (option) |device| {
        inline for (@typeInfo(devices).Struct.decls) |decl| {
            var value = @field(devices, decl.name);
            value.name = std.mem.replaceOwned(u8, b.allocator, decl.name, "_", "-") catch @panic("Out of memory");

            if (std.mem.eql(u8, value.name.?, @tagName(device))) return value;
        }
    }
    return null;
}

pub fn applyDevice(exe: *std.Build.Step.Compile, _device: ?Device) void {
    if (_device) |device| {
        if (device.linker_script) |linker_script| {
            exe.setLinkerScript(linker_script);
        }

        if (device.code_model) |code_model| {
            exe.code_model = code_model;
        }
    }
}
