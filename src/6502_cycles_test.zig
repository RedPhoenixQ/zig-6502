const std = @import("std");
const CPU = @import("./6502.zig");
const Op = CPU.Op;

const TestCPU = struct {
    cpu: CPU = .{},
    extra_cycles: u2 = 0,
    params: [2]u8 = .{ 0x11, 0x11 },

    const OP_ADDRESS = 0xBEEF;

    fn set_page_break_params(self: *TestCPU) void {
        self.set_op_param(0x0FFF);
    }

    fn set_op_param(self: *TestCPU, param: u16) void {
        std.mem.writeInt(u16, self.cpu.memory[TestCPU.OP_ADDRESS + 1 .. TestCPU.OP_ADDRESS + 3], param, .little);
    }

    fn test_op(self: *TestCPU, op: CPU.Op) !void {
        self.cpu.memory[TestCPU.OP_ADDRESS] = @intFromEnum(op);
        self.cpu.cycles = 0;
        self.cpu.registers.program_counter = TestCPU.OP_ADDRESS - 1;

        std.log.debug("op: {s} ({x:0>2})\n", .{ @tagName(op), self.cpu.memory[TestCPU.OP_ADDRESS .. TestCPU.OP_ADDRESS + 3] });

        const executed_op = self.cpu.step();
        try std.testing.expectEqual(op, executed_op);
        std.testing.expectEqual(CYCLES[@intFromEnum(op)] + self.extra_cycles, self.cpu.cycles) catch {
            std.log.err("{s} had incorrect cycles with bytes {x:0>2}\n", .{ @tagName(op), self.cpu.memory[TestCPU.OP_ADDRESS .. TestCPU.OP_ADDRESS + 3] });
            return error.IncorrectCycles;
        };
    }
};

fn cycles_init() [std.math.maxInt(u8)]u4 {
    var arr = [_]u4{0} ** std.math.maxInt(u8);
    arr[@intFromEnum(Op.LDA_IMM)] = 2;
    arr[@intFromEnum(Op.LDA_ZPG)] = 3;
    arr[@intFromEnum(Op.LDA_ZPX)] = 4;
    arr[@intFromEnum(Op.LDA_ABS)] = 4;
    arr[@intFromEnum(Op.LDA_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.LDA_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.LDA_IDX)] = 6;
    arr[@intFromEnum(Op.LDA_IDY)] = 5; // (+1 if page crossed)
    arr[@intFromEnum(Op.LDX_IMM)] = 2;
    arr[@intFromEnum(Op.LDX_ZPG)] = 3;
    arr[@intFromEnum(Op.LDX_ZPY)] = 4;
    arr[@intFromEnum(Op.LDX_ABS)] = 4;
    arr[@intFromEnum(Op.LDX_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.LDY_IMM)] = 2;
    arr[@intFromEnum(Op.LDY_ZPG)] = 3;
    arr[@intFromEnum(Op.LDY_ZPX)] = 4;
    arr[@intFromEnum(Op.LDY_ABS)] = 4;
    arr[@intFromEnum(Op.LDY_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.STA_ZPG)] = 3;
    arr[@intFromEnum(Op.STA_ZPX)] = 4;
    arr[@intFromEnum(Op.STA_ABS)] = 4;
    arr[@intFromEnum(Op.STA_ABX)] = 5;
    arr[@intFromEnum(Op.STA_ABY)] = 5;
    arr[@intFromEnum(Op.STA_IDX)] = 6;
    arr[@intFromEnum(Op.STA_IDY)] = 6;
    arr[@intFromEnum(Op.STX_ZPG)] = 3;
    arr[@intFromEnum(Op.STX_ZPY)] = 4;
    arr[@intFromEnum(Op.STX_ABS)] = 4;
    arr[@intFromEnum(Op.STY_ZPG)] = 3;
    arr[@intFromEnum(Op.STY_ZPX)] = 4;
    arr[@intFromEnum(Op.STY_ABS)] = 4;
    arr[@intFromEnum(Op.TAX)] = 2;
    arr[@intFromEnum(Op.TAY)] = 2;
    arr[@intFromEnum(Op.TXA)] = 2;
    arr[@intFromEnum(Op.TYA)] = 2;
    arr[@intFromEnum(Op.TSX)] = 2;
    arr[@intFromEnum(Op.TXS)] = 2;
    arr[@intFromEnum(Op.PHA)] = 3;
    arr[@intFromEnum(Op.PHP)] = 3;
    arr[@intFromEnum(Op.PLA)] = 4;
    arr[@intFromEnum(Op.PLP)] = 4;
    arr[@intFromEnum(Op.AND_IMM)] = 2;
    arr[@intFromEnum(Op.AND_ZPG)] = 3;
    arr[@intFromEnum(Op.AND_ZPX)] = 4;
    arr[@intFromEnum(Op.AND_ABS)] = 4;
    arr[@intFromEnum(Op.AND_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.AND_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.AND_IDX)] = 6;
    arr[@intFromEnum(Op.AND_IDY)] = 5; // (+1 if page crossed)
    arr[@intFromEnum(Op.EOR_IMM)] = 2;
    arr[@intFromEnum(Op.EOR_ZPG)] = 3;
    arr[@intFromEnum(Op.EOR_ZPX)] = 4;
    arr[@intFromEnum(Op.EOR_ABS)] = 4;
    arr[@intFromEnum(Op.EOR_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.EOR_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.EOR_IDX)] = 6;
    arr[@intFromEnum(Op.EOR_IDY)] = 5; // (+1 if page crossed)
    arr[@intFromEnum(Op.ORA_IMM)] = 2;
    arr[@intFromEnum(Op.ORA_ZPG)] = 3;
    arr[@intFromEnum(Op.ORA_ZPX)] = 4;
    arr[@intFromEnum(Op.ORA_ABS)] = 4;
    arr[@intFromEnum(Op.ORA_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.ORA_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.ORA_IDX)] = 6;
    arr[@intFromEnum(Op.ORA_IDY)] = 5; // (+1 if page crossed)
    arr[@intFromEnum(Op.BIT_ZPG)] = 3;
    arr[@intFromEnum(Op.BIT_ABS)] = 4;
    arr[@intFromEnum(Op.ADC_IMM)] = 2;
    arr[@intFromEnum(Op.ADC_ZPG)] = 3;
    arr[@intFromEnum(Op.ADC_ZPX)] = 4;
    arr[@intFromEnum(Op.ADC_ABS)] = 4;
    arr[@intFromEnum(Op.ADC_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.ADC_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.ADC_IDX)] = 6;
    arr[@intFromEnum(Op.ADC_IDY)] = 5; // (+1 if page crossed)
    arr[@intFromEnum(Op.SBC_IMM)] = 2;
    arr[@intFromEnum(Op.SBC_ZPG)] = 3;
    arr[@intFromEnum(Op.SBC_ZPX)] = 4;
    arr[@intFromEnum(Op.SBC_ABS)] = 4;
    arr[@intFromEnum(Op.SBC_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.SBC_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.SBC_IDX)] = 6;
    arr[@intFromEnum(Op.SBC_IDY)] = 5; // (+1 if page crossed)
    arr[@intFromEnum(Op.CMP_IMM)] = 2;
    arr[@intFromEnum(Op.CMP_ZPG)] = 3;
    arr[@intFromEnum(Op.CMP_ZPX)] = 4;
    arr[@intFromEnum(Op.CMP_ABS)] = 4;
    arr[@intFromEnum(Op.CMP_ABX)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.CMP_ABY)] = 4; // (+1 if page crossed)
    arr[@intFromEnum(Op.CMP_IDX)] = 6;
    arr[@intFromEnum(Op.CMP_IDY)] = 5; // (+1 if page crossed)
    arr[@intFromEnum(Op.CPX_IMM)] = 2;
    arr[@intFromEnum(Op.CPX_ZPG)] = 3;
    arr[@intFromEnum(Op.CPX_ABS)] = 4;
    arr[@intFromEnum(Op.CPY_IMM)] = 2;
    arr[@intFromEnum(Op.CPY_ZPG)] = 3;
    arr[@intFromEnum(Op.CPY_ABS)] = 4;
    arr[@intFromEnum(Op.INC_ZPG)] = 5;
    arr[@intFromEnum(Op.INC_ZPX)] = 6;
    arr[@intFromEnum(Op.INC_ABS)] = 6;
    arr[@intFromEnum(Op.INC_ABX)] = 7;
    arr[@intFromEnum(Op.INX)] = 2;
    arr[@intFromEnum(Op.INY)] = 2;
    arr[@intFromEnum(Op.DEC_ZPG)] = 5;
    arr[@intFromEnum(Op.DEC_ZPX)] = 6;
    arr[@intFromEnum(Op.DEC_ABS)] = 6;
    arr[@intFromEnum(Op.DEC_ABX)] = 7;
    arr[@intFromEnum(Op.DEX)] = 2;
    arr[@intFromEnum(Op.DEY)] = 2;
    arr[@intFromEnum(Op.ASL)] = 2;
    arr[@intFromEnum(Op.ASL_ZPG)] = 5;
    arr[@intFromEnum(Op.ASL_ZPX)] = 6;
    arr[@intFromEnum(Op.ASL_ABS)] = 6;
    arr[@intFromEnum(Op.ASL_ABX)] = 7;
    arr[@intFromEnum(Op.LSR)] = 2;
    arr[@intFromEnum(Op.LSR_ZPG)] = 5;
    arr[@intFromEnum(Op.LSR_ZPX)] = 6;
    arr[@intFromEnum(Op.LSR_ABS)] = 6;
    arr[@intFromEnum(Op.LSR_ABX)] = 7;
    arr[@intFromEnum(Op.ROL)] = 2;
    arr[@intFromEnum(Op.ROL_ZPG)] = 5;
    arr[@intFromEnum(Op.ROL_ZPX)] = 6;
    arr[@intFromEnum(Op.ROL_ABS)] = 6;
    arr[@intFromEnum(Op.ROL_ABX)] = 7;
    arr[@intFromEnum(Op.ROR)] = 2;
    arr[@intFromEnum(Op.ROR_ZPG)] = 5;
    arr[@intFromEnum(Op.ROR_ZPX)] = 6;
    arr[@intFromEnum(Op.ROR_ABS)] = 6;
    arr[@intFromEnum(Op.ROR_ABX)] = 7;
    arr[@intFromEnum(Op.JMP_ABS)] = 3;
    arr[@intFromEnum(Op.JMP_IND)] = 5;
    arr[@intFromEnum(Op.JSR_ABS)] = 6;
    arr[@intFromEnum(Op.RTS)] = 6;
    arr[@intFromEnum(Op.BCC_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.BCS_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.BEQ_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.BMI_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.BNE_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.BPL_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.BVC_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.BVS_REL)] = 2; // (+1 if branch succeeds, +2 if to a new page)
    arr[@intFromEnum(Op.CLC)] = 2;
    arr[@intFromEnum(Op.CLD)] = 2;
    arr[@intFromEnum(Op.CLI)] = 2;
    arr[@intFromEnum(Op.CLV)] = 2;
    arr[@intFromEnum(Op.SEC)] = 2;
    arr[@intFromEnum(Op.SED)] = 2;
    arr[@intFromEnum(Op.SEI)] = 2;
    arr[@intFromEnum(Op.BRK)] = 7;
    arr[@intFromEnum(Op.NOP)] = 2;
    arr[@intFromEnum(Op.RTI)] = 6;
    return arr;
}

const CYCLES = cycles_init();

// const CYCLES: [std.math.maxInt(u8)]u4 = .{
//     .LDA_IMM = 2,
//     .LDA_ZPG = 3,
//     .LDA_ZPX = 4,
//     .LDA_ABS = 4,
//     .LDA_ABX = 4, // (+1 if page crossed)
//     .LDA_ABY = 4, // (+1 if page crossed)
//     .LDA_IDX = 6,
//     .LDA_IDY = 5, // (+1 if page crossed)
//     .LDX_IMM = 2,
//     .LDX_ZPG = 3,
//     .LDX_ZPY = 4,
//     .LDX_ABS = 4,
//     .LDX_ABY = 4, // (+1 if page crossed)
//     .LDY_IMM = 2,
//     .LDY_ZPG = 3,
//     .LDY_ZPX = 4,
//     .LDY_ABS = 4,
//     .LDY_ABX = 4, // (+1 if page crossed)
//     .STA_ZPG = 3,
//     .STA_ZPX = 4,
//     .STA_ABS = 4,
//     .STA_ABX = 5,
//     .STA_ABY = 5,
//     .STA_IDX = 6,
//     .STA_IDY = 6,
//     .STX_ZPG = 3,
//     .STX_ZPY = 4,
//     .STX_ABS = 4,
//     .STY_ZPG = 3,
//     .STY_ZPX = 4,
//     .STY_ABS = 4,
//     .TAX = 2,
//     .TAY = 2,
//     .TXA = 2,
//     .TYA = 2,
//     .TSX = 2,
//     .TXS = 2,
//     .PHA = 3,
//     .PHP = 3,
//     .PLA = 4,
//     .PLP = 4,
//     .AND_IMM = 2,
//     .AND_ZPG = 3,
//     .AND_ZPX = 4,
//     .AND_ABS = 4,
//     .AND_ABX = 4, // (+1 if page crossed)
//     .AND_ABY = 4, // (+1 if page crossed)
//     .AND_IDX = 6,
//     .AND_IDY = 5, // (+1 if page crossed)
//     .EOR_IMM = 2,
//     .EOR_ZPG = 3,
//     .EOR_ZPX = 4,
//     .EOR_ABS = 4,
//     .EOR_ABX = 4, // (+1 if page crossed)
//     .EOR_ABY = 4, // (+1 if page crossed)
//     .EOR_IDX = 6,
//     .EOR_IDY = 5, // (+1 if page crossed)
//     .ORA_IMM = 2,
//     .ORA_ZPG = 3,
//     .ORA_ZPX = 4,
//     .ORA_ABS = 4,
//     .ORA_ABX = 4, // (+1 if page crossed)
//     .ORA_ABY = 4, // (+1 if page crossed)
//     .ORA_IDX = 6,
//     .ORA_IDY = 5, // (+1 if page crossed)
//     .BIT_ZPG = 3,
//     .BIT_ABS = 4,
//     .ADC_IMM = 2,
//     .ADC_ZPG = 3,
//     .ADC_ZPX = 4,
//     .ADC_ABS = 4,
//     .ADC_ABX = 4, // (+1 if page crossed)
//     .ADC_ABY = 4, // (+1 if page crossed)
//     .ADC_IDX = 6,
//     .ADC_IDY = 5, // (+1 if page crossed)
//     .SBC_IMM = 2,
//     .SBC_ZPG = 3,
//     .SBC_ZPX = 4,
//     .SBC_ABS = 4,
//     .SBC_ABX = 4, // (+1 if page crossed)
//     .SBC_ABY = 4, // (+1 if page crossed)
//     .SBC_IDX = 6,
//     .SBC_IDY = 5, // (+1 if page crossed)
//     .CMP_IMM = 2,
//     .CMP_ZPG = 3,
//     .CMP_ZPX = 4,
//     .CMP_ABS = 4,
//     .CMP_ABX = 4, // (+1 if page crossed)
//     .CMP_ABY = 4, // (+1 if page crossed)
//     .CMP_IDX = 6,
//     .CMP_IDY = 5, // (+1 if page crossed)
//     .CPX_IMM = 2,
//     .CPX_ZPG = 3,
//     .CPX_ABS = 4,
//     .CPY_IMM = 2,
//     .CPY_ZPG = 3,
//     .CPY_ABS = 4,
//     .INC_ZPG = 5,
//     .INC_ZPX = 6,
//     .INC_ABS = 6,
//     .INC_ABX = 7,
//     .INX = 2,
//     .INY = 2,
//     .DEC_ZPG = 5,
//     .DEC_ZPX = 6,
//     .DEC_ABS = 6,
//     .DEC_ABX = 7,
//     .DEX = 2,
//     .DEY = 2,
//     .ASL = 2,
//     .ASL_ZPG = 5,
//     .ASL_ZPX = 6,
//     .ASL_ABS = 6,
//     .ASL_ABX = 7,
//     .LSR = 2,
//     .LSR_ZPG = 5,
//     .LSR_ZPX = 6,
//     .LSR_ABS = 6,
//     .LSR_ABX = 7,
//     .ROL = 2,
//     .ROL_ZPG = 5,
//     .ROL_ZPX = 6,
//     .ROL_ABS = 6,
//     .ROL_ABX = 7,
//     .ROR = 2,
//     .ROR_ZPG = 5,
//     .ROR_ZPX = 6,
//     .ROR_ABS = 6,
//     .ROR_ABX = 7,
//     .JMP_ABS = 3,
//     .JMP_IND = 5,
//     .JSR_ABS = 6,
//     .RTS = 6,
//     .BCC_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .BCS_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .BEQ_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .BMI_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .BNE_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .BPL_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .BVC_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .BVS_REL = 2, // (+1 if branch succeeds, +2 if to a new page)
//     .CLC = 2,
//     .CLD = 2,
//     .CLI = 2,
//     .CLV = 2,
//     .SEC = 2,
//     .SED = 2,
//     .SEI = 2,
//     .BRK = 7,
//     .NOP = 2,
//     .RTI = 6,
// };

test "LDA" {
    var t: TestCPU = .{};
    try t.test_op(.LDA_IMM);
    try t.test_op(.LDA_ZPG);
    try t.test_op(.LDA_ZPX);
    try t.test_op(.LDA_ABS);
    try t.test_op(.LDA_ABX);
    try t.test_op(.LDA_ABY);
    try t.test_op(.LDA_IDX);
    try t.test_op(.LDA_IDY);

    // (+1 if page crossed)
    t.extra_cycles = 1;
    t.set_page_break_params();
    try t.test_op(.LDA_ABX);
    try t.test_op(.LDA_ABY);
    try t.test_op(.LDA_IDY);
}

test "LDX" {
    var t: TestCPU = .{};
    try t.test_op(.LDX_IMM);
    try t.test_op(.LDX_ZPG);
    try t.test_op(.LDX_ZPY);
    try t.test_op(.LDX_ABS);
    try t.test_op(.LDX_ABY);

    // (+1 if page crossed)
    t.extra_cycles = 1;
    t.set_page_break_params();
    try t.test_op(.LDX_ABY);
}

test "LDY" {
    var t: TestCPU = .{};
    try t.test_op(.LDY_IMM);
    try t.test_op(.LDY_ZPG);
    try t.test_op(.LDY_ZPX);
    try t.test_op(.LDY_ABS);
    try t.test_op(.LDY_ABX);

    // (+1 if page crossed)
    t.extra_cycles = 1;
    t.set_page_break_params();
    try t.test_op(.LDY_ABX);
}

test "STA" {
    var t: TestCPU = .{};
    try t.test_op(.STA_ZPG);
    try t.test_op(.STA_ZPX);
    try t.test_op(.STA_ABS);
    try t.test_op(.STA_ABX);
    try t.test_op(.STA_ABY);
    try t.test_op(.STA_IDX);
    try t.test_op(.STA_IDY);
}

test "TAX" {
    var t: TestCPU = .{};
    try t.test_op(.TAX);
}
test "TAY" {
    var t: TestCPU = .{};
    try t.test_op(.TAY);
}
test "TXA" {
    var t: TestCPU = .{};
    try t.test_op(.TXA);
}
test "TYA" {
    var t: TestCPU = .{};
    try t.test_op(.TYA);
}

test "TSX" {
    var t: TestCPU = .{};
    try t.test_op(.TSX);
}
test "TXS" {
    var t: TestCPU = .{};
    try t.test_op(.TXS);
}
test "PHA" {
    var t: TestCPU = .{};
    try t.test_op(.PHA);
}
test "PHP" {
    var t: TestCPU = .{};
    try t.test_op(.PHP);
}
test "PLA" {
    var t: TestCPU = .{};
    try t.test_op(.PLA);
}
test "PLP" {
    var t: TestCPU = .{};
    try t.test_op(.PLP);
}

test "AND" {
    var t: TestCPU = .{};
    try t.test_op(.AND_IMM);
    try t.test_op(.AND_ZPG);
    try t.test_op(.AND_ZPX);
    try t.test_op(.AND_ABS);
    try t.test_op(.AND_ABX);
    try t.test_op(.AND_ABY);
    try t.test_op(.AND_IDX);
    try t.test_op(.AND_IDY);

    // (+1 if page crossed)
    t.extra_cycles = 1;
    t.set_page_break_params();
    try t.test_op(.AND_ABX);
    try t.test_op(.AND_ABY);
    try t.test_op(.AND_IDY);
}
test "EOR" {
    var t: TestCPU = .{};
    try t.test_op(.EOR_IMM);
    try t.test_op(.EOR_ZPG);
    try t.test_op(.EOR_ZPX);
    try t.test_op(.EOR_ABS);
    try t.test_op(.EOR_ABX);
    try t.test_op(.EOR_ABY);
    try t.test_op(.EOR_IDX);
    try t.test_op(.EOR_IDY);

    // (+1 if page crossed)
    t.extra_cycles = 1;
    t.set_page_break_params();
    try t.test_op(.EOR_ABX);
    try t.test_op(.EOR_ABY);
    try t.test_op(.EOR_IDY);
}
test "ORA" {
    var t: TestCPU = .{};
    try t.test_op(.ORA_IMM);
    try t.test_op(.ORA_ZPG);
    try t.test_op(.ORA_ZPX);
    try t.test_op(.ORA_ABS);
    try t.test_op(.ORA_ABX);
    try t.test_op(.ORA_ABY);
    try t.test_op(.ORA_IDX);
    try t.test_op(.ORA_IDY);

    // (+1 if page crossed)
    t.extra_cycles = 1;
    t.set_page_break_params();
    try t.test_op(.ORA_ABX);
    try t.test_op(.ORA_ABY);
    try t.test_op(.ORA_IDY);
}
test "BIT" {
    var t: TestCPU = .{};
    try t.test_op(.BIT_ZPG);
    try t.test_op(.BIT_ABS);
}

test "ASL" {
    var t: TestCPU = .{};
    try t.test_op(.ASL);
    try t.test_op(.ASL_ZPG);
    try t.test_op(.ASL_ZPX);
    try t.test_op(.ASL_ABS);
    try t.test_op(.ASL_ABX);
}
test "LSR" {
    var t: TestCPU = .{};
    try t.test_op(.LSR);
    try t.test_op(.LSR_ZPG);
    try t.test_op(.LSR_ZPX);
    try t.test_op(.LSR_ABS);
    try t.test_op(.LSR_ABX);
}
test "ROL" {
    var t: TestCPU = .{};
    try t.test_op(.ROL);
    try t.test_op(.ROL_ZPG);
    try t.test_op(.ROL_ZPX);
    try t.test_op(.ROL_ABS);
    try t.test_op(.ROL_ABX);
}
test "ROR" {
    var t: TestCPU = .{};
    try t.test_op(.ROR);
    try t.test_op(.ROR_ZPG);
    try t.test_op(.ROR_ZPX);
    try t.test_op(.ROR_ABS);
    try t.test_op(.ROR_ABX);
}

test "JMP" {
    var t: TestCPU = .{};
    try t.test_op(.JMP_ABS);
    try t.test_op(.JMP_IND);
}
test "JSR" {
    var t: TestCPU = .{};
    try t.test_op(.JSR_ABS);
}
test "RTI" {
    var t: TestCPU = .{};
    try t.test_op(.RTI);
}

test "BCC" {
    var t: TestCPU = .{};
    t.cpu.flags.carry = true;
    try t.test_op(.BCC_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.carry = false;
    try t.test_op(.BCC_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BCC_REL);
}
test "BCS" {
    var t: TestCPU = .{};
    t.cpu.flags.carry = false;
    try t.test_op(.BCS_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.carry = true;
    try t.test_op(.BCS_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BCS_REL);
}
test "BEQ" {
    var t: TestCPU = .{};
    t.cpu.flags.zero = false;
    try t.test_op(.BEQ_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.zero = true;
    try t.test_op(.BEQ_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BEQ_REL);
}
test "BMI" {
    var t: TestCPU = .{};
    t.cpu.flags.negative = false;
    try t.test_op(.BMI_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.negative = true;
    try t.test_op(.BMI_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BMI_REL);
}
test "BNE" {
    var t: TestCPU = .{};
    t.cpu.flags.zero = true;
    try t.test_op(.BNE_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.zero = false;
    try t.test_op(.BNE_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BNE_REL);
}
test "BPL" {
    var t: TestCPU = .{};
    t.cpu.flags.negative = true;
    try t.test_op(.BPL_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.negative = false;
    try t.test_op(.BPL_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BPL_REL);
}
test "BVC" {
    var t: TestCPU = .{};
    t.cpu.flags.overflow = true;
    try t.test_op(.BVC_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.overflow = false;
    try t.test_op(.BVC_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BVC_REL);
}
test "BVS" {
    var t: TestCPU = .{};
    t.cpu.flags.overflow = false;
    try t.test_op(.BVS_REL);
    // +1 if branch succeeds
    t.extra_cycles = 1;
    t.cpu.flags.overflow = true;
    try t.test_op(.BVS_REL);
    // +2 if to a new page
    t.extra_cycles = 2;
    t.set_op_param(0x69);
    try t.test_op(.BVS_REL);
}
