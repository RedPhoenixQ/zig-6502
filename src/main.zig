const std = @import("std");

const CPU = @import("./6502.zig");

pub fn main() !void {
    var cpu: CPU = .{};

    cpu.memory[1] = @intFromEnum(CPU.Op.LDA_IMM);
    cpu.memory[2] = 0x42;
    cpu.memory[3] = @intFromEnum(CPU.Op.LDA_IMM);
    cpu.memory[4] = 0xAA;
    cpu.memory[CPU.POWER_ON_RESET_ADDRESS] = 0x03 - 1;

    _ = cpu.step();

    std.debug.print("{}{}", .{ cpu.registers, cpu.flags });
}
