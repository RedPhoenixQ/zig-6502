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

    std.debug.print("{}{}", .{ cpu.registers, cpu.flags });
}

test "functional test" {
    const test_binary = @embedFile("./tests/6502_functional_test.bin");
    var mem = try std.testing.allocator.create([0x10000]u8);
    @memcpy(mem[0xa..], test_binary[0..]);
    var cpu = CPU.new(mem.*);
    cpu.registers.program_counter = 0x0400 - 1;

    while (true) {
        const pg = cpu.registers.program_counter + 1;
        std.debug.print("{x:0>4} {x:0>2}: ", .{ pg, cpu.memory[pg .. pg + 3] });
        switch (cpu.step()) {
            .NOP => |op| std.debug.print("{s:<8}\n", .{@tagName(op)}),
            else => |op| std.debug.print("{s:<8} {:.0} {:.0}\n", .{ @tagName(op), cpu.registers, cpu.flags }),
        }
    }
}
