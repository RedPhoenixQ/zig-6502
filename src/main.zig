const std = @import("std");

const CPU = @import("./6502.zig");

pub fn main() !void {
    var mem = std.mem.zeroes(CPU.Memory);
    mem[1] = @intFromEnum(CPU.Op.LDA_IMM);
    mem[2] = 0x42;
    mem[3] = @intFromEnum(CPU.Op.LDA_IMM);
    mem[4] = 0xAA;
    mem[CPU.POWER_ON_RESET_ADDRESS] = 0x03 - 1;

    var cpu = CPU.new(mem);
    cpu.step();

    cpu.printRegisters();
}

test "functional test" {
    const test_binary = @embedFile("./test_binaries/6502_functional_test.bin");
    var mem = try std.testing.allocator.create([0x10000]u8);
    @memcpy(mem[0..], test_binary[0..]);
    var cpu = CPU.new(mem.*);
    cpu.registers.program_counter = 0x0400 - 1;
    cpu.printRegisters();

    while (true) {
        cpu.step();
        cpu.printRegisters();
        cpu.printFlags();
    }
}
