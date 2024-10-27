const std = @import("std");

const Self = @This();

// Registers
// http://www.6502.org/users/obelisk/6502/registers.html

const Registers = struct {
    ///
    /// The program counter is a 16 bit register which points to the next instruction
    /// to be executed. The value of program counter is modified automatically as
    /// instructions are executed.
    program_counter: u16 = POWER_ON_RESET_ADDRESS,
    /// Stack Pointer
    ///
    /// The processor supports a 256 byte stack located between $0100 and $01FF.
    /// The stack pointer is an 8 bit register and holds the low 8 bits of the next free
    /// location on the stack. The location of the stack is fixed and cannot be moved.
    stack_pointer: u8 = 0xFF,
    accumulator: u8 = 0,
    x: u8 = 0,
    y: u8 = 0,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (options.precision == 0) {
            try writer.writeAll("{ ");
            try writer.print("PG: {x:0>4}, ", .{self.program_counter});
            try writer.print("SP: {x:>2}, ", .{self.stack_pointer});
            try writer.print("A: {x:0>2}, ", .{self.accumulator});
            try writer.print("X: {x:0>2}, ", .{self.x});
            try writer.print("Y: {x:0>2}", .{self.y});
            try writer.writeAll(" }");
        } else {
            try writer.writeAll("Register{\n");
            try writer.print("\tprogram_counter: {x:0>4} ({0b:0>16}),\n", .{self.program_counter});
            try writer.print("\tstack_pointer: {x:0>2} ({0b:0>8}),\n", .{self.stack_pointer});
            try writer.print("\taccumulator: {x:0>2} ({0b:0>8}),\n", .{self.accumulator});
            try writer.print("\tx: {x:0>2} ({0b:0>8}),\n", .{self.x});
            try writer.print("\ty: {x:0>2} ({0b:0>8}),\n", .{self.y});
            try writer.writeAll("}\n");
        }
    }
};

/// https://www.nesdev.org/wiki/Status_flags
const Flags = packed struct(u8) {
    carry: bool = false,
    zero: bool = false,
    interupt_disabled: bool = true,
    decimal_mode: bool = false,
    break_command: bool = false,
    _padding: u1 = 1,
    overflow: bool = false,
    negative: bool = false,

    const STACK_MASK: u8 = 0b11001111;

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (options.precision == 0) {
            try writer.writeByte('[');
            try writer.writeByte(if (self.negative) 'N' else '_');
            try writer.writeByte(if (self.overflow) 'V' else '_');
            try writer.writeByte('_');
            try writer.writeByte(if (self.break_command) 'B' else '_');
            try writer.writeByte(if (self.decimal_mode) 'D' else '_');
            try writer.writeByte(if (self.interupt_disabled) 'I' else '_');
            try writer.writeByte(if (self.zero) 'Z' else '_');
            try writer.writeByte(if (self.carry) 'C' else '_');
            try writer.writeByte(']');
        } else {
            try writer.writeAll("Flags{\n");
            try writer.print("\tcarry: {},\n", .{self.carry});
            try writer.print("\tzero: {},\n", .{self.zero});
            try writer.print("\tinterupt_disabled: {},\n", .{self.interupt_disabled});
            try writer.print("\tdecimal_mode: {},\n", .{self.decimal_mode});
            try writer.print("\tbreak_command: {},\n", .{self.break_command});
            try writer.print("\toverflow: {},\n", .{self.overflow});
            try writer.print("\tnegative: {},\n", .{self.negative});
            try writer.writeAll("}\n");
        }
    }

    fn set_zero(self: *Flags, value: u8) void {
        self.zero = Flags.test_zero(value);
    }

    fn set_negative(self: *Flags, value: u8) void {
        self.negative = Flags.test_negative(value);
    }

    fn test_zero(value: u8) bool {
        return value == 0;
    }

    fn test_negative(value: u8) bool {
        return value & 0b10000000 > 0;
    }
};

pub const STACK_START = 0x0100;

/// Two bytes long (0xFFFA/B)
pub const INTERUPT_HANDLER_ADDRESS = 0xFFFA;
/// Two bytes long (0xFFFC/D)
pub const POWER_ON_RESET_ADDRESS = 0xFFFC;
/// Two bytes long (0xFFFE/F)
pub const BRK_INTERUPT_HANDLER_ADDRESS = 0xFFFE;

pub const Memory = [0x10000]u8;

pub const AddressingMode = enum(u4) {
    ZPG,
    ZPX,
    ZPY,
    ABS,
    ABX,
    ABY,
    IND,
    IDX,
    IDY,
    REL,
};

/// The second part is the addressing mode: https://www.6502.org/users/obelisk/6502/addressing.html
pub const Op = enum(u8) {
    // Load/Store Operations
    /// Load Accumulator	N,Z
    LDA_IMM = 0xA9,
    LDA_ZPG = 0xA5,
    LDA_ZPX = 0xB5,
    LDA_ABS = 0xAD,
    LDA_ABX = 0xBD,
    LDA_ABY = 0xB9,
    LDA_IDX = 0xA1,
    LDA_IDY = 0xB1,
    /// Load X Register	N,Z
    LDX_IMM = 0xA2,
    LDX_ZPG = 0xA6,
    LDX_ZPY = 0xB6,
    LDX_ABS = 0xAE,
    LDX_ABY = 0xBE,
    /// Load Y Register	N,Z
    LDY_IMM = 0xA0,
    LDY_ZPG = 0xA4,
    LDY_ZPX = 0xB4,
    LDY_ABS = 0xAC,
    LDY_ABX = 0xBC,
    /// Store Accumulator
    STA_ZPG = 0x85,
    STA_ZPX = 0x95,
    STA_ABS = 0x8D,
    STA_ABX = 0x9D,
    STA_ABY = 0x99,
    STA_IDX = 0x81,
    STA_IDY = 0x91,
    /// Store X Register
    STX_ZPG = 0x86,
    STX_ZPY = 0x96,
    STX_ABS = 0x8E,
    /// Store Y Register
    STY_ZPG = 0x84,
    STY_ZPX = 0x94,
    STY_ABS = 0x8C,

    // Register Transfers
    /// Transfer accumulator to X	N,Z
    TAX = 0xAA,
    /// Transfer accumulator to Y	N,Z
    TAY = 0xA8,
    /// Transfer X to accumulator	N,Z
    TXA = 0x8A,
    /// Transfer Y to accumulator	N,Z
    TYA = 0x98,

    // Stack Operations
    /// Transfer stack pointer to X	N,Z
    TSX = 0xBA,
    /// Transfer X to stack pointer
    TXS = 0x9A,
    /// Push accumulator on stack
    PHA = 0x48,
    /// Push processor status on stack
    PHP = 0x08,
    /// Pull accumulator from stack	N,Z
    PLA = 0x68,
    /// Pull processor status from stack	All
    PLP = 0x28,

    // Logical
    /// Logical AND	N,Z
    AND_IMM = 0x29,
    AND_ZPG = 0x25,
    AND_ZPX = 0x35,
    AND_ABS = 0x2D,
    AND_ABX = 0x3D,
    AND_ABY = 0x39,
    AND_IDX = 0x21,
    AND_IDY = 0x31,
    /// Exclusive OR	N,Z
    EOR_IMM = 0x49,
    EOR_ZPG = 0x45,
    EOR_ZPX = 0x55,
    EOR_ABS = 0x4D,
    EOR_ABX = 0x5D,
    EOR_ABY = 0x59,
    EOR_IDX = 0x41,
    EOR_IDY = 0x51,
    /// Logical Inclusive OR	N,Z
    ORA_IMM = 0x09,
    ORA_ZPG = 0x05,
    ORA_ZPX = 0x15,
    ORA_ABS = 0x0D,
    ORA_ABX = 0x1D,
    ORA_ABY = 0x19,
    ORA_IDX = 0x01,
    ORA_IDY = 0x11,
    /// Bit Test	N,V,Z
    BIT_ZPG = 0x24,
    BIT_ABS = 0x2C,

    // Arithmetic
    /// Add with Carry	N,V,Z,C
    ADC_IMM = 0x69,
    ADC_ZPG = 0x65,
    ADC_ZPX = 0x75,
    ADC_ABS = 0x6D,
    ADC_ABX = 0x7D,
    ADC_ABY = 0x79,
    ADC_IDX = 0x61,
    ADC_IDY = 0x71,
    /// Subtract with Carry	N,V,Z,C
    SBC_IMM = 0xE9,
    SBC_ZPG = 0xE5,
    SBC_ZPX = 0xF5,
    SBC_ABS = 0xED,
    SBC_ABX = 0xFD,
    SBC_ABY = 0xF9,
    SBC_IDX = 0xE1,
    SBC_IDY = 0xF1,
    /// Compare accumulator	N,Z,C
    CMP_IMM = 0xC9,
    CMP_ZPG = 0xC5,
    CMP_ZPX = 0xD5,
    CMP_ABS = 0xCD,
    CMP_ABX = 0xDD,
    CMP_ABY = 0xD9,
    CMP_IDX = 0xC1,
    CMP_IDY = 0xD1,
    /// Compare X register	N,Z,C
    CPX_IMM = 0xE0,
    CPX_ZPG = 0xE4,
    CPX_ABS = 0xEC,
    /// Compare Y register	N,Z,C
    CPY_IMM = 0xC0,
    CPY_ZPG = 0xC4,
    CPY_ABS = 0xCC,

    // Increments & Decrements
    /// Increment a memory location	N,Z
    INC_ZPG = 0xE6,
    INC_ZPX = 0xF6,
    INC_ABS = 0xEE,
    INC_ABX = 0xFE,
    /// Increment the X register	N,Z
    INX = 0xE8,
    /// Increment the Y register	N,Z
    INY = 0xC8,
    /// Decrement a memory location	N,Z
    DEC_ZPG = 0xC6,
    DEC_ZPX = 0xD6,
    DEC_ABS = 0xCE,
    DEC_ABX = 0xDE,
    /// Decrement the X register	N,Z
    DEX = 0xCA,
    /// Decrement the Y register	N,Z
    DEY = 0x88,

    // Shifts
    /// Arithmetic Shift Left	N,Z,C
    ASL = 0x0A,
    ASL_ZPG = 0x06,
    ASL_ZPX = 0x16,
    ASL_ABS = 0x0E,
    ASL_ABX = 0x1E,
    /// Logical Shift Right	N,Z,C
    LSR = 0x4A,
    LSR_ZPG = 0x46,
    LSR_ZPX = 0x56,
    LSR_ABS = 0x4E,
    LSR_ABX = 0x5E,
    /// Rotate Left	N,Z,C
    ROL = 0x2A,
    ROL_ZPG = 0x26,
    ROL_ZPX = 0x36,
    ROL_ABS = 0x2E,
    ROL_ABX = 0x3E,
    /// Rotate Right	N,Z,C
    ROR = 0x6A,
    ROR_ZPG = 0x66,
    ROR_ZPX = 0x76,
    ROR_ABS = 0x6E,
    ROR_ABX = 0x7E,

    // Jumps & Calls
    /// Jump to another location
    JMP_ABS = 0x4C,
    JMP_IND = 0x6C,
    /// Jump to a subroutine
    JSR_ABS = 0x20,
    /// Return from subroutine
    RTS = 0x60,

    // Branches
    /// Branch if carry flag clear
    BCC_REL = 0x90,
    /// Branch if carry flag set
    BCS_REL = 0xB0,
    /// Branch if zero flag set
    BEQ_REL = 0xF0,
    /// Branch if negative flag set
    BMI_REL = 0x30,
    /// Branch if zero flag clear
    BNE_REL = 0xD0,
    /// Branch if negative flag clear
    BPL_REL = 0x10,
    /// Branch if overflow flag clear
    BVC_REL = 0x50,
    /// Branch if overflow flag set
    BVS_REL = 0x70,

    // Status Flag Changes
    /// Clear carry flag	C
    CLC = 0x18,
    /// Clear decimal mode flag	D
    CLD = 0xD8,
    /// Clear interrupt disable flag	I
    CLI = 0x58,
    /// Clear overflow flag	V
    CLV = 0xB8,
    /// Set carry flag	C
    SEC = 0x38,
    /// Set decimal mode flag	D
    SED = 0xF8,
    /// Set interrupt disable flag	I
    SEI = 0x78,

    // System Functions
    /// Force an interrupt	B
    BRK = 0x00,
    /// No Operation
    NOP = 0xEA,
    /// Return from Interrupt	All
    RTI = 0x40,
};

registers: Registers = .{},
flags: Flags = .{},
memory: Memory,

pub fn new(memory: Memory) Self {
    return .{
        .memory = memory,
    };
}

pub fn reset(self: *Self) void {
    self.registers.program_counter = self.fetch_u16(POWER_ON_RESET_ADDRESS);
}

pub fn step(self: *Self) Op {
    const program_counter_before = self.registers.program_counter;
    const op: Op = @enumFromInt(self.next_program_u8());

    switch (op) {
        .LDA_IMM, .LDA_ZPG, .LDA_ZPX, .LDA_ABS, .LDA_ABX, .LDA_ABY, .LDA_IDX, .LDA_IDY => self.load_accumulator(self.fetch_instruction_data(switch (op) {
            .LDA_IMM => null,
            .LDA_ZPG => .ZPG,
            .LDA_ZPX => .ZPX,
            .LDA_ABS => .ABS,
            .LDA_ABX => .ABX,
            .LDA_ABY => .ABY,
            .LDA_IDX => .IDX,
            .LDA_IDY => .IDY,
            else => unreachable,
        })),

        .LDX_IMM, .LDX_ZPG, .LDX_ZPY, .LDX_ABS, .LDX_ABY => self.load_x(self.fetch_instruction_data(switch (op) {
            .LDX_IMM => null,
            .LDX_ZPG => .ZPG,
            .LDX_ZPY => .ZPY,
            .LDX_ABS => .ABS,
            .LDX_ABY => .ABY,
            else => unreachable,
        })),

        .LDY_IMM, .LDY_ZPG, .LDY_ZPX, .LDY_ABS, .LDY_ABX => self.load_y(self.fetch_instruction_data(switch (op) {
            .LDY_IMM => null,
            .LDY_ZPG => .ZPG,
            .LDY_ZPX => .ZPX,
            .LDY_ABS => .ABS,
            .LDY_ABX => .ABX,
            else => unreachable,
        })),

        .STA_ZPG => self.memory[self.get_instruction_address(.ZPG)] = self.registers.accumulator,
        .STA_ZPX => self.memory[self.get_instruction_address(.ZPX)] = self.registers.accumulator,
        .STA_ABS => self.memory[self.get_instruction_address(.ABS)] = self.registers.accumulator,
        .STA_ABX => self.memory[self.get_instruction_address(.ABX)] = self.registers.accumulator,
        .STA_ABY => self.memory[self.get_instruction_address(.ABY)] = self.registers.accumulator,
        .STA_IDX => self.memory[self.get_instruction_address(.IDX)] = self.registers.accumulator,
        .STA_IDY => self.memory[self.get_instruction_address(.IDY)] = self.registers.accumulator,

        .STX_ZPG => self.memory[self.get_instruction_address(.ZPG)] = self.registers.x,
        .STX_ZPY => self.memory[self.get_instruction_address(.ZPY)] = self.registers.x,
        .STX_ABS => self.memory[self.get_instruction_address(.ABS)] = self.registers.x,

        .STY_ZPG => self.memory[self.get_instruction_address(.ZPG)] = self.registers.y,
        .STY_ZPX => self.memory[self.get_instruction_address(.ZPX)] = self.registers.y,
        .STY_ABS => self.memory[self.get_instruction_address(.ABS)] = self.registers.y,

        .TAX => self.load_x(self.registers.accumulator),
        .TAY => self.load_y(self.registers.accumulator),
        .TXA => self.load_accumulator(self.registers.x),
        .TYA => self.load_accumulator(self.registers.y),

        .TSX => self.load_x(self.registers.stack_pointer),
        .TXS => self.registers.stack_pointer = self.registers.x,
        .PHA => self.push(self.registers.accumulator),
        .PHP => self.push_flags(),
        .PLA => self.load_accumulator(self.pop()),
        .PLP => self.pop_flags(),

        .AND_IMM, .AND_ZPG, .AND_ZPX, .AND_ABS, .AND_ABX, .AND_ABY, .AND_IDX, .AND_IDY => self.load_accumulator(self.registers.accumulator & self.fetch_instruction_data(switch (op) {
            .AND_IMM => null,
            .AND_ZPG => .ZPG,
            .AND_ZPX => .ZPX,
            .AND_ABS => .ABS,
            .AND_ABX => .ABX,
            .AND_ABY => .ABY,
            .AND_IDX => .IDX,
            .AND_IDY => .IDY,
            else => unreachable,
        })),

        .EOR_IMM, .EOR_ZPG, .EOR_ZPX, .EOR_ABS, .EOR_ABX, .EOR_ABY, .EOR_IDX, .EOR_IDY => self.load_accumulator(self.registers.accumulator ^ self.fetch_instruction_data(switch (op) {
            .EOR_IMM => null,
            .EOR_ZPG => .ZPG,
            .EOR_ZPX => .ZPX,
            .EOR_ABS => .ABS,
            .EOR_ABX => .ABX,
            .EOR_ABY => .ABY,
            .EOR_IDX => .IDX,
            .EOR_IDY => .IDY,
            else => unreachable,
        })),

        .ORA_IMM, .ORA_ZPG, .ORA_ZPX, .ORA_ABS, .ORA_ABX, .ORA_ABY, .ORA_IDX, .ORA_IDY => self.load_accumulator(self.registers.accumulator | self.fetch_instruction_data(switch (op) {
            .ORA_IMM => null,
            .ORA_ZPG => .ZPG,
            .ORA_ZPX => .ZPX,
            .ORA_ABS => .ABS,
            .ORA_ABX => .ABX,
            .ORA_ABY => .ABY,
            .ORA_IDX => .IDX,
            .ORA_IDY => .IDY,
            else => unreachable,
        })),

        .BIT_ZPG, .BIT_ABS => {
            const value = self.fetch_instruction_data(switch (op) {
                .BIT_ABS => .ABS,
                .BIT_ZPG => .ZPG,
                else => unreachable,
            });
            const bit_test = self.registers.accumulator & value;
            self.flags.overflow = value & 0b01000000 > 0;
            self.flags.set_negative(value);
            self.flags.set_zero(bit_test);
        },

        .ADC_IMM, .ADC_ZPG, .ADC_ZPX, .ADC_ABS, .ADC_ABX, .ADC_ABY, .ADC_IDX, .ADC_IDY => {
            const value = self.fetch_instruction_data(switch (op) {
                .ADC_IMM => null,
                .ADC_ZPG => .ZPG,
                .ADC_ZPX => .ZPX,
                .ADC_ABS => .ABS,
                .ADC_ABX => .ABX,
                .ADC_ABY => .ABY,
                .ADC_IDX => .IDX,
                .ADC_IDY => .IDY,
                else => unreachable,
            });
            const before = self.registers.accumulator;
            if (self.flags.carry) {
                self.registers.accumulator +%= 1;
            }
            self.load_accumulator(self.registers.accumulator +% value);
            if (!Flags.test_negative(before) and self.flags.negative) {
                self.flags.overflow = true;
            }
            self.flags.carry = self.registers.accumulator < before;
        },

        .SBC_IMM, .SBC_ZPG, .SBC_ZPX, .SBC_ABS, .SBC_ABX, .SBC_ABY, .SBC_IDX, .SBC_IDY => {
            const value = self.fetch_instruction_data(switch (op) {
                .SBC_IMM => null,
                .SBC_ZPG => .ZPG,
                .SBC_ZPX => .ZPX,
                .SBC_ABS => .ABS,
                .SBC_ABX => .ABX,
                .SBC_ABY => .ABY,
                .SBC_IDX => .IDX,
                .SBC_IDY => .IDY,
                else => unreachable,
            });
            const before = self.registers.accumulator;
            if (self.flags.carry) {
                self.registers.accumulator -%= 1;
            }
            self.load_accumulator(self.registers.accumulator -% value);
            if (Flags.test_negative(before) and !self.flags.negative) {
                self.flags.overflow = true;
            }
            self.flags.carry = self.registers.accumulator > before;
        },

        .CMP_IMM, .CMP_ZPG, .CMP_ZPX, .CMP_ABS, .CMP_ABX, .CMP_ABY, .CMP_IDX, .CMP_IDY => {
            const value = self.fetch_instruction_data(switch (op) {
                .CMP_IMM => null,
                .CMP_ZPG => .ZPG,
                .CMP_ZPX => .ZPX,
                .CMP_ABS => .ABS,
                .CMP_ABX => .ABX,
                .CMP_ABY => .ABY,
                .CMP_IDX => .IDX,
                .CMP_IDY => .IDY,
                else => unreachable,
            });
            self.flags.carry = self.registers.accumulator >= value;
            self.flags.zero = self.registers.accumulator == value;
            self.flags.set_negative(self.registers.accumulator -% value);
        },

        .CPX_IMM, .CPX_ZPG, .CPX_ABS => {
            const value = self.fetch_instruction_data(switch (op) {
                .CPX_IMM => null,
                .CPX_ZPG => .ZPG,
                .CPX_ABS => .ABS,
                else => unreachable,
            });
            self.flags.carry = self.registers.x >= value;
            self.flags.zero = self.registers.x == value;
            self.flags.set_negative(self.registers.x -% value);
        },

        .CPY_IMM, .CPY_ZPG, .CPY_ABS => {
            const value = self.fetch_instruction_data(switch (op) {
                .CPY_IMM => null,
                .CPY_ZPG => .ZPG,
                .CPY_ABS => .ABS,
                else => unreachable,
            });
            self.flags.carry = self.registers.y >= value;
            self.flags.zero = self.registers.y == value;
            self.flags.set_negative(self.registers.y -% value);
        },

        .INC_ZPG, .INC_ZPX, .INC_ABS, .INC_ABX => {
            const address = self.get_instruction_address(switch (op) {
                .INC_ZPG => .ZPG,
                .INC_ZPX => .ZPX,
                .INC_ABS => .ABS,
                .INC_ABX => .ABX,
                else => unreachable,
            });
            self.memory[address] +%= 1;
            self.flags.set_negative(self.memory[address]);
            self.flags.set_zero(self.memory[address]);
        },

        .INX => self.load_x(self.registers.x +% 1),
        .INY => self.load_y(self.registers.y +% 1),

        .DEC_ZPG, .DEC_ZPX, .DEC_ABS, .DEC_ABX => {
            const address = self.get_instruction_address(switch (op) {
                .DEC_ZPG => .ZPG,
                .DEC_ZPX => .ZPX,
                .DEC_ABS => .ABS,
                .DEC_ABX => .ABX,
                else => unreachable,
            });
            self.memory[address] -%= 1;
            self.flags.set_negative(self.memory[address]);
            self.flags.set_zero(self.memory[address]);
        },

        .DEX => self.load_x(self.registers.x -% 1),
        .DEY => self.load_y(self.registers.y -% 1),

        .ASL => {
            self.flags.carry = self.registers.accumulator & 0b10000000 > 0;
            self.load_accumulator(self.registers.accumulator << 1);
        },

        .ASL_ZPG, .ASL_ZPX, .ASL_ABS, .ASL_ABX => {
            const address = self.get_instruction_address(switch (op) {
                .ASL_ZPG => .ZPG,
                .ASL_ZPX => .ZPX,
                .ASL_ABS => .ABS,
                .ASL_ABX => .ABX,
                else => unreachable,
            });
            self.flags.carry = self.memory[address] & 0b10000000 > 0;
            self.memory[address] <<= 1;
            self.flags.set_zero(self.memory[address]);
            self.flags.set_negative(self.memory[address]);
        },

        .LSR => {
            self.flags.carry = self.registers.accumulator & 0b1 > 0;
            self.load_accumulator(self.registers.accumulator >> 1);
        },

        .LSR_ZPG, .LSR_ZPX, .LSR_ABS, .LSR_ABX => {
            const address = self.get_instruction_address(switch (op) {
                .LSR_ZPG => .ZPG,
                .LSR_ZPX => .ZPX,
                .LSR_ABS => .ABS,
                .LSR_ABX => .ABX,
                else => unreachable,
            });
            self.flags.carry = self.memory[address] & 0b1 > 0;
            self.memory[address] >>= 1;
            self.flags.set_zero(self.memory[address]);
            self.flags.set_negative(self.memory[address]);
        },

        .ROL => {
            self.flags.carry = self.registers.accumulator & 0b10000000 > 0;
            var value = self.registers.accumulator << 1;
            if (self.flags.carry) {
                value |= 0b00000001;
            }
            self.load_accumulator(value);
        },

        .ROL_ZPG, .ROL_ZPX, .ROL_ABS, .ROL_ABX => {
            const address = self.get_instruction_address(switch (op) {
                .ROL_ZPG => .ZPG,
                .ROL_ZPX => .ZPX,
                .ROL_ABS => .ABS,
                .ROL_ABX => .ABX,
                else => unreachable,
            });
            self.flags.carry = self.memory[address] & 0b10000000 > 0;
            self.memory[address] <<= 1;
            if (self.flags.carry) {
                self.memory[address] |= 0b00000001;
            }
            self.flags.set_zero(self.memory[address]);
            self.flags.set_negative(self.memory[address]);
        },

        .ROR => {
            self.flags.carry = self.registers.accumulator & 0b00000001 > 0;
            var value = self.registers.accumulator >> 1;
            if (self.flags.carry) {
                value |= 0b10000000;
            }
            self.load_accumulator(value);
        },

        .ROR_ZPG, .ROR_ZPX, .ROR_ABS, .ROR_ABX => {
            const address = self.get_instruction_address(switch (op) {
                .ROR_ZPG => .ZPG,
                .ROR_ZPX => .ZPX,
                .ROR_ABS => .ABS,
                .ROR_ABX => .ABX,
                else => unreachable,
            });
            self.flags.carry = self.memory[address] & 0b1 > 0;
            self.memory[address] >>= 1;
            if (self.flags.carry) {
                self.memory[address] |= 0b10000000;
            }
            self.flags.set_zero(self.memory[address]);
            self.flags.set_negative(self.memory[address]);
        },

        .JMP_ABS => self.registers.program_counter = self.get_instruction_address(.ABS) - 1,
        .JMP_IND => self.registers.program_counter = self.get_instruction_address(.IND) - 1,
        .JSR_ABS => {
            const subroutine_address = self.get_instruction_address(.ABS) - 1;
            self.push_program_counter();
            self.registers.program_counter = subroutine_address;
        },
        .RTS => self.pop_program_counter(),

        .BCC_REL, .BCS_REL, .BEQ_REL, .BMI_REL, .BNE_REL, .BPL_REL, .BVC_REL, .BVS_REL => {
            const should_branch = switch (op) {
                .BCC_REL => !self.flags.carry,
                .BCS_REL => self.flags.carry,
                .BEQ_REL => self.flags.zero,
                .BMI_REL => self.flags.negative,
                .BNE_REL => !self.flags.zero,
                .BPL_REL => !self.flags.negative,
                .BVC_REL => !self.flags.overflow,
                .BVS_REL => self.flags.overflow,
                else => unreachable,
            };
            // Must always consume the offset byte
            const offset = self.next_program_u8();
            if (should_branch) {
                self.registers.program_counter = self.get_address(offset, .REL);
            }
        },

        .CLC => self.flags.carry = false,
        .CLD => self.flags.decimal_mode = false,
        .CLI => self.flags.interupt_disabled = false,
        .CLV => self.flags.overflow = false,
        .SEC => self.flags.carry = true,
        .SED => self.flags.decimal_mode = true,
        .SEI => self.flags.interupt_disabled = true,

        .BRK => {
            // Add two to get the correct offset of the return address on the stack
            self.registers.program_counter += 2;
            self.push_program_counter();
            self.push_flags();
            self.flags.break_command = true;
            self.flags.interupt_disabled = true;
            self.registers.program_counter = self.fetch_u16(BRK_INTERUPT_HANDLER_ADDRESS) -% 1;
        },
        .NOP => {},
        .RTI => {
            self.pop_flags();
            self.pop_program_counter();
            // Remove one so that the next step with increment to the specified address
            self.registers.program_counter -= 1;
        },
    }

    if (self.registers.program_counter == program_counter_before) {
        std.debug.panic("Trap encountered at {x:0>4}\n", .{self.registers.program_counter + 1});
    }

    return op;
}

fn next_program_u8(self: *Self) u8 {
    self.registers.program_counter += 1;
    return self.fetch_u8(self.registers.program_counter);
}

fn next_program_u16(self: *Self) u16 {
    self.registers.program_counter += 1;
    const out = self.fetch_u16(self.registers.program_counter);
    self.registers.program_counter += 1;
    return out;
}

fn fetch_instruction_data(self: *Self, maybe_address: ?AddressingMode) u8 {
    if (maybe_address) |mode| {
        return self.fetch_u8(self.get_instruction_address(mode));
    } else {
        return self.next_program_u8();
    }
}

fn get_instruction_address(self: *Self, mode: AddressingMode) u16 {
    return self.get_address(switch (mode) {
        .ABS, .ABX, .ABY, .IND => self.next_program_u16(),
        else => @intCast(self.next_program_u8()),
    }, mode);
}

fn fetch_u8(self: *Self, address: u16) u8 {
    return self.memory[address];
}

fn fetch_u16(self: *Self, address: u16) u16 {
    return std.mem.readInt(u16, @as(*[2]u8, @ptrCast(self.memory[address..])), .little);
    // const low: u16 = @intCast(self.fetch_u8(address));
    // const high: u16 = @intCast(self.fetch_u8(address + 1));
    // return high * 8 + low;
}

/// Loads a value into the accumulator register and sets the negative and zero flags
fn load_accumulator(self: *Self, value: u8) void {
    self.flags.set_negative(value);
    self.flags.set_zero(value);
    self.registers.accumulator = value;
}

/// Loads a value into the x register and sets the negative and zero flags
fn load_x(self: *Self, value: u8) void {
    self.flags.set_negative(value);
    self.flags.set_zero(value);
    self.registers.x = value;
}

/// Loads a value into the x register and sets the negative and zero flags
fn load_y(self: *Self, value: u8) void {
    self.flags.set_negative(value);
    self.flags.set_zero(value);
    self.registers.y = value;
}

fn store(self: *Self, register: std.meta.FieldEnum(Registers), address: u16) void {
    self.memory[address] = switch (register) {
        .accumulator => self.registers.accumulator,
        .x => self.registers.x,
        .y => self.registers.y,
    };
}

/// https://www.nesdev.org/wiki/CPU_addressing_modes
fn get_address(self: *Self, input: u16, mode: AddressingMode) u16 {
    const address = switch (mode) {
        .ZPG => input,
        .ZPX => (@as(u8, @intCast(input)) +% self.registers.x),
        .ZPY => (@as(u8, @intCast(input)) +% self.registers.y),
        .ABS => input,
        .ABX => input +% self.registers.x,
        .ABY => input +% self.registers.y,
        .IND => self.fetch_u16(input),
        .IDX => blk: {
            const low: u16 = self.fetch_u8((input + self.registers.x) % 256);
            const high: u16 = self.fetch_u8((input + self.registers.x + 1) % 256);
            break :blk (high << 8) + low;
            // break :blk self.fetch_u16(input + self.registers.x);
        },
        // http://forum.6502.org/viewtopic.php?f=2&t=2195#p19862
        .IDY => blk: {
            const low: u16 = self.fetch_u8(input);
            const high: u16 = self.fetch_u8((input + 1) % 256);
            break :blk (high << 8) + low + self.registers.y;
            // break :blk self.fetch_u16(input) + self.registers.y;
        },
        .REL => blk: {
            const relative = @as(i8, @bitCast(@as(u8, @intCast(input))));
            std.debug.print("relative {}\n", .{relative});
            if (relative < 0) {
                break :blk self.registers.program_counter - @abs(relative);
            } else {
                break :blk self.registers.program_counter + @abs(relative);
            }
        },
    };
    return address;
}

fn get_current_stack_address(self: *Self) u16 {
    return STACK_START + @as(u16, @intCast(self.registers.stack_pointer));
}

fn push_program_counter(self: *Self) void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, self.registers.program_counter, .little);
    // This handles SP overflows in the middle of the two bytes
    self.push(bytes[1]);
    self.push(bytes[0]);
}

fn push_flags(self: *Self) void {
    self.push(@as(u8, @bitCast(self.flags)) | ~Flags.STACK_MASK);
}

fn push(self: *Self, value: u8) void {
    self.memory[self.get_current_stack_address()] = value;
    self.registers.stack_pointer -%= 1;
}

fn pop_program_counter(self: *Self) void {
    // This handles SP overflows in the middle of the two bytes
    const bytes: [2]u8 = .{ self.pop(), self.pop() };
    self.registers.program_counter = std.mem.readInt(u16, &bytes, .little);
}

fn pop_flags(self: *Self) void {
    self.flags = @bitCast(self.pop() & Flags.STACK_MASK);
}

fn pop(self: *Self) u8 {
    self.registers.stack_pointer +%= 1;
    return self.memory[self.get_current_stack_address()];
}
