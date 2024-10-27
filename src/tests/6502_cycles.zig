const std = @import("std");
const CPU = @import("../6502.zig");

fn test_op(cycles: u4, op: CPU.Op) !void {
    return test_op_with_params(cycles, op, .{ 11, 11 });
}

fn test_op_with_params(cycles: u4, op: CPU.Op, params: [2]u8) !void {
    var cpu: CPU = .{};
    cpu.reset();
    try std.testing.expectEqual(0, cpu.registers.program_counter);
    cpu.reset();
    cpu.memory[1] = @intFromEnum(op);
    cpu.memory[2] = params[0];
    cpu.memory[3] = params[1];
    std.debug.print("op: {s} ({} {x:0>2})\n", .{ @tagName(op), cpu.registers.program_counter, cpu.memory[0..5] });
    const executed_op = cpu.step();
    try std.testing.expectEqual(op, executed_op);
    std.testing.expectEqual(cycles, cpu.cycles) catch {
        std.debug.print("{s} had incorrect cycles with bytes {x:0>2}\n", .{ @tagName(op), params });
        return error.IncorrectCycles;
    };
}

test "LDA_IMM" {
    try test_op(2, .LDA_IMM);
}
test "LDA_ZPG" {
    try test_op(3, .LDA_ZPG);
}
test "LDA_ZPX" {
    try test_op(4, .LDA_ZPX);
}
test "LDA_ABS" {
    try test_op(4, .LDA_ABS);
}
test "LDA_ABX" {
    try test_op(4, .LDA_ABX);
    try test_op_with_params(4, .LDA_ABX, .{ 0xFF, 0xF }); // (+1 if page crossed)
}
test "LDA_ABY" {
    try test_op(4, .LDA_ABY);
    try test_op_with_params(4, .LDA_ABY, .{ 0xFF, 0xF }); // (+1 if page crossed)
}
test "LDA_IDX" {
    try test_op(6, .LDA_IDX);
}
test "LDA_IDY" {
    try test_op(5, .LDA_IDY);
    try test_op_with_params(5, .LDA_IDY, .{ 0xFF, 0xF }); // (+1 if page crossed)
}

test "LDX_IMM" {
    try test_op(2, .LDX_IMM);
}
test "LDX_ZPG" {
    try test_op(3, .LDX_ZPG);
}
test "LDX_ZPY" {
    try test_op(4, .LDX_ZPY);
}
test "LDX_ABS" {
    try test_op(4, .LDX_ABS);
}
test "LDX_ABY" {
    try test_op(4, .LDX_ABY);
    try test_op_with_params(4, .LDX_ABY, .{ 0xFF, 0xF }); // (+1 if page crossed)
}

test "LDY_IMM" {
    try test_op(2, .LDY_IMM);
}
test "LDY_ZPG" {
    try test_op(3, .LDY_ZPG);
}
test "LDY_ZPX" {
    try test_op(4, .LDY_ZPX);
}
test "LDY_ABS" {
    try test_op(4, .LDY_ABS);
}
test "LDY_ABX" {
    try test_op(4, .LDY_ABX);
    try test_op_with_params(4, .LDY_ABX, .{ 0xFF, 0xF }); // (+1 if page crossed)
}

test "STA_ZPG" {
    try test_op(3, .STA_ZPG);
}
test "STA_ZPX" {
    try test_op(4, .STA_ZPX);
}
test "STA_ABS" {
    try test_op(4, .STA_ABS);
}
test "STA_ABX" {
    try test_op(5, .STA_ABX);
}
test "STA_ABY" {
    try test_op(5, .STA_ABY);
}
test "STA_IDX" {
    try test_op(6, .STA_IDX);
}
test "STA_IDY" {
    try test_op(6, .STA_IDY);
}

test "TAX" {
    try test_op(2, .TAX);
}
test "TAY" {
    try test_op(2, .TAY);
}
test "TXA" {
    try test_op(2, .TXA);
}
test "TYA" {
    try test_op(2, .TYA);
}

test "TSX" {
    try test_op(2, .TSX);
}
test "TXS" {
    try test_op(2, .TXS);
}
test "PHA" {
    try test_op(3, .PHA);
}
test "PHP" {
    try test_op(3, .PHP);
}
test "PLA" {
    try test_op(4, .PLA);
}
test "PLP" {
    try test_op(4, .PLP);
}
