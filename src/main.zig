const std = @import("std");

const CPU = @import("./6502.zig");

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
        CPU.ZeroPageScope => return,
        // Don't log debug cpu logs (compare values, computed addresses, ...)
        CPU.LogScope => if (message_level == .debug) return,
        else => {},
    }
    std.log.defaultLog(message_level, scope, format, args);
}

pub fn main() !void {
    const CODE_START_ADDRESS = 0x0400;
    const SUCCESS_TRAP_ADDRESS = 0x336d;
    const BIN_START_ADDRESS = 0x000A;
    const test_binary = @embedFile("./tests/6502_functional_test.bin");
    var cpu: CPU = .{};
    @memcpy(cpu.memory[BIN_START_ADDRESS..], test_binary[0..]);
    cpu.registers.program_counter = CODE_START_ADDRESS - 1;

    std.log.info("{}{}", .{ cpu.registers, cpu.flags });

    var iteratons: u32 = 0;
    while (cpu.registers.program_counter + 1 != SUCCESS_TRAP_ADDRESS) : (iteratons += 1) {
        if (iteratons > 0xFFFFFFFF) return .TooManyIterations;
        _ = cpu.step();
    }
}
