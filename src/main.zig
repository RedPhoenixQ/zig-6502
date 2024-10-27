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

test "functional test" {
    const CODE_START_ADDRESS = 0x0400;
    const SUCCESS_TRAP_ADDRESS = 0x336d;
    const BIN_START_ADDRESS = 0x000A;
    const test_binary = @embedFile("./tests/6502_functional_test.bin");
    var cpu: CPU = .{};
    @memcpy(cpu.memory[BIN_START_ADDRESS..], test_binary[0..]);
    // cpu.memory[0x0200] = 0x27;
    cpu.registers.program_counter = CODE_START_ADDRESS - 1;

    for (0..0xFFFFFFFF) |_| {
        // if (i % 0xFFFF == 0) {
        //     std.debug.print("{:.0} {:.0}\n", .{ cpu.registers, cpu.flags });
        // }
        // std.debug.print("{x:0>4} {x:0>2}: ", .{ pg, cpu.memory[pg .. pg + 3] });
        const pg = cpu.registers.program_counter + 1;
        if (pg == SUCCESS_TRAP_ADDRESS) return;
        _ = cpu.step();
        // switch (cpu.step()) {
        //     .NOP => |op| std.debug.print("{s:<8}\n", .{@tagName(op)}),
        //     else => |op| std.debug.print("{s:<8} {:.0} {:.0}\n", .{ @tagName(op), cpu.registers, cpu.flags }),
        // }
        // std.debug.print("{x:0>2} {x:0>2}\n", .{ cpu.memory[0x0026..0x003E], cpu.memory[0x0203..0x0210] });
        // if (cpu.registers.stack_pointer < 0xFF) {
        //     std.debug.print("Stack: {x:0>2}\n", .{cpu.memory[@as(u16, CPU.STACK_START) + cpu.registers.stack_pointer + 1 .. CPU.STACK_START + 0xFF + 1]});
        // }
    }
}
