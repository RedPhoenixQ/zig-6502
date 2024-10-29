const std = @import("std");

const CPU = @import("./6502.zig");
const HexLoader = @import("./HexLoader.zig");

pub const std_options: std.Options = .{
    .logFn = logFn,
};

fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    switch (scope) {
        // Don't log zero page
        CPU.ZeroPageScope, .hexLoader => return,
        // Don't log debug cpu logs (compare values, computed addresses, ...)
        CPU.LogScope => if (message_level == .debug) return,
        else => {},
    }
    std.log.defaultLog(message_level, scope, format, args);
}

pub fn main() !void {
    const TINY_BASIC_HEX = @embedFile("./tests/tiny_basic.hex");
    var stream = std.io.fixedBufferStream(TINY_BASIC_HEX);
    var cpu: CPU = .{};
    _ = try HexLoader.read(stream.reader(), &cpu.memory);

    cpu.reset();
    cpu.registers.program_counter = 0x0200 - 1;

    var iteratons: u32 = 0;
    while (true) : (iteratons += 1) {
        if (iteratons > 0xFFFFFFFF) return .TooManyIterations;
        _ = cpu.step();
    }
}
