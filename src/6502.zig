const std = @import("std");

pub const LogScope = .cpu6502;
pub const StackScope = .cpu6502Stack;
pub const ZeroPageScope = .cpu6502ZeroPage;
const Log = std.log.scoped(LogScope);
const StackLog = std.log.scoped(StackScope);
const ZeroPageLog = std.log.scoped(ZeroPageScope);

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

pub const BufferMemoryMap = struct {
    buffer: [std.math.maxInt(u16) + 1]u8 = @splat(0xFF),

    pub fn read(self: *@This(), address: u16) u8 {
        return self.buffer[address];
    }

    pub fn write(self: *@This(), address: u16, data: u8) void {
        self.buffer[address] = data;
    }

    pub fn getZeroPage(self: *@This()) []u8 {
        return self.buffer[0 .. 0xFF + 1];
    }
};

pub const AddressingMode = enum(u4) {
    ZPG,
    ZPX,
    ZPY,
    ABS,
    ABX,
    /// Will always take the max cycles
    ABX_MAX_CYCLE,
    ABY,
    /// Will always take the max cycles
    ABY_MAX_CYCLE,
    IND,
    IDX,
    IDY,
    /// Will always take the max cycles
    IDY_MAX_CYCLE,
    REL,
};

/// The second part is the addressing mode: https://www.6502.org/users/obelisk/6502/addressing.html
/// https://www.masswerk.at/6502/6502_instruction_set.html
///
/// Does not include the illegal opcodes, see https://www.masswerk.at/6502/6502_instruction_set.html
///
/// TODO: Could be extended with 65C02 instructions
pub const Op = enum(u8) {
    // Load/Store Operations
    /// Load Accumulator N,Z
    LDA_IMM = 0xA9,
    LDA_ZPG = 0xA5,
    LDA_ZPX = 0xB5,
    LDA_ABS = 0xAD,
    LDA_ABX = 0xBD,
    LDA_ABY = 0xB9,
    LDA_IDX = 0xA1,
    LDA_IDY = 0xB1,
    /// Load X Register N,Z
    LDX_IMM = 0xA2,
    LDX_ZPG = 0xA6,
    LDX_ZPY = 0xB6,
    LDX_ABS = 0xAE,
    LDX_ABY = 0xBE,
    /// Load Y Register N,Z
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
    /// Transfer accumulator to X N,Z
    TAX = 0xAA,
    /// Transfer accumulator to Y N,Z
    TAY = 0xA8,
    /// Transfer X to accumulator N,Z
    TXA = 0x8A,
    /// Transfer Y to accumulator N,Z
    TYA = 0x98,

    // Stack Operations
    /// Transfer stack pointer to X N,Z
    TSX = 0xBA,
    /// Transfer X to stack pointer
    TXS = 0x9A,
    /// Push accumulator on stack
    PHA = 0x48,
    /// Push processor status on stack
    PHP = 0x08,
    /// Pull accumulator from stack N,Z
    PLA = 0x68,
    /// Pull processor status from stack All
    PLP = 0x28,

    // Logical
    /// Logical AND N,Z
    AND_IMM = 0x29,
    AND_ZPG = 0x25,
    AND_ZPX = 0x35,
    AND_ABS = 0x2D,
    AND_ABX = 0x3D,
    AND_ABY = 0x39,
    AND_IDX = 0x21,
    AND_IDY = 0x31,
    /// Exclusive OR N,Z
    EOR_IMM = 0x49,
    EOR_ZPG = 0x45,
    EOR_ZPX = 0x55,
    EOR_ABS = 0x4D,
    EOR_ABX = 0x5D,
    EOR_ABY = 0x59,
    EOR_IDX = 0x41,
    EOR_IDY = 0x51,
    /// Logical Inclusive OR N,Z
    ORA_IMM = 0x09,
    ORA_ZPG = 0x05,
    ORA_ZPX = 0x15,
    ORA_ABS = 0x0D,
    ORA_ABX = 0x1D,
    ORA_ABY = 0x19,
    ORA_IDX = 0x01,
    ORA_IDY = 0x11,
    /// Bit Test N,V,Z
    BIT_ZPG = 0x24,
    BIT_ABS = 0x2C,

    // Arithmetic
    /// Add with Carry N,V,Z,C
    ADC_IMM = 0x69,
    ADC_ZPG = 0x65,
    ADC_ZPX = 0x75,
    ADC_ABS = 0x6D,
    ADC_ABX = 0x7D,
    ADC_ABY = 0x79,
    ADC_IDX = 0x61,
    ADC_IDY = 0x71,
    /// Subtract with Carry N,V,Z,C
    SBC_IMM = 0xE9,
    SBC_ZPG = 0xE5,
    SBC_ZPX = 0xF5,
    SBC_ABS = 0xED,
    SBC_ABX = 0xFD,
    SBC_ABY = 0xF9,
    SBC_IDX = 0xE1,
    SBC_IDY = 0xF1,
    /// Compare accumulator N,Z,C
    CMP_IMM = 0xC9,
    CMP_ZPG = 0xC5,
    CMP_ZPX = 0xD5,
    CMP_ABS = 0xCD,
    CMP_ABX = 0xDD,
    CMP_ABY = 0xD9,
    CMP_IDX = 0xC1,
    CMP_IDY = 0xD1,
    /// Compare X register N,Z,C
    CPX_IMM = 0xE0,
    CPX_ZPG = 0xE4,
    CPX_ABS = 0xEC,
    /// Compare Y register N,Z,C
    CPY_IMM = 0xC0,
    CPY_ZPG = 0xC4,
    CPY_ABS = 0xCC,

    // Increments & Decrements
    /// Increment a memory location N,Z
    INC_ZPG = 0xE6,
    INC_ZPX = 0xF6,
    INC_ABS = 0xEE,
    INC_ABX = 0xFE,
    /// Increment the X register N,Z
    INX = 0xE8,
    /// Increment the Y register N,Z
    INY = 0xC8,
    /// Decrement a memory location N,Z
    DEC_ZPG = 0xC6,
    DEC_ZPX = 0xD6,
    DEC_ABS = 0xCE,
    DEC_ABX = 0xDE,
    /// Decrement the X register N,Z
    DEX = 0xCA,
    /// Decrement the Y register N,Z
    DEY = 0x88,

    // Shifts
    /// Arithmetic Shift Left N,Z,C
    ASL = 0x0A,
    ASL_ZPG = 0x06,
    ASL_ZPX = 0x16,
    ASL_ABS = 0x0E,
    ASL_ABX = 0x1E,
    /// Logical Shift Right N,Z,C
    LSR = 0x4A,
    LSR_ZPG = 0x46,
    LSR_ZPX = 0x56,
    LSR_ABS = 0x4E,
    LSR_ABX = 0x5E,
    /// Rotate Left N,Z,C
    ROL = 0x2A,
    ROL_ZPG = 0x26,
    ROL_ZPX = 0x36,
    ROL_ABS = 0x2E,
    ROL_ABX = 0x3E,
    /// Rotate Right N,Z,C
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
    /// Clear carry flag C
    CLC = 0x18,
    /// Clear decimal mode flag D
    CLD = 0xD8,
    /// Clear interrupt disable flag I
    CLI = 0x58,
    /// Clear overflow flag V
    CLV = 0xB8,
    /// Set carry flag C
    SEC = 0x38,
    /// Set decimal mode flag D
    SED = 0xF8,
    /// Set interrupt disable flag I
    SEI = 0x78,

    // System Functions
    /// Force an interrupt B
    BRK = 0x00,
    /// No Operation
    NOP = 0xEA,
    /// Return from Interrupt All
    RTI = 0x40,

    _, // Invalid op code
};

pub fn CPU(MemoryMap: anytype) type {
    comptime {
        // Does not respect https://www.nesdev.org/wiki/Open_bus_behavior
        std.debug.assert(@TypeOf(MemoryMap.read) == fn (*MemoryMap, address: u16) u8);
        if (@hasDecl(MemoryMap, "getZeroPage")) {
            std.debug.assert(@TypeOf(MemoryMap.getZeroPage) == fn (*MemoryMap) []u8);
        }
        std.debug.assert(@TypeOf(MemoryMap.write) == fn (*MemoryMap, address: u16, u8) void);
    }

    return struct {
        const Self = @This();

        registers: Registers = .{},
        flags: Flags = .{},
        memory: *MemoryMap,

        cycles: u32 = 0,

        pub fn init(memory: *MemoryMap) Self {
            return .{
                .memory = memory,
            };
        }

        /// https://www.masswerk.at/6502/6502_instruction_set.html:~:text=Start/Reset%20Operations
        pub fn reset(self: *Self) void {
            self.flags = .{};
            self.registers.program_counter = self.fetch_u16(POWER_ON_RESET_ADDRESS);
            self.cycles = 8;
        }

        pub fn step(self: *Self) Op {
            const program_counter_before = self.registers.program_counter;
            const op: Op = @enumFromInt(self.next_program_u8());
            Log.info("({: >9}) {x:0>4} {x:0>2}: {s:<8} {:.0} {:.0}", .{
                self.cycles,  program_counter_before + 1,
                &[_]u8{
                    self.memory.read(program_counter_before + 2),
                    self.memory.read(program_counter_before + 3),
                    self.memory.read(program_counter_before + 4),
                },
                @tagName(op), self.registers,
                self.flags,
            });
            if (self.registers.stack_pointer < 0xFF) {
                StackLog.debug("{x:0>2}", .{self.memory.buffer[@as(u16, STACK_START) + self.registers.stack_pointer + 1 .. STACK_START + 0xFF + 1]});
            }
            if (@hasDecl(MemoryMap, "getZeroPage")) {
                const zero_page = self.memory.getZeroPage();
                ZeroPageLog.debug("[00..0F]: {x:0>2}", .{zero_page[0x00..0x10]});
                ZeroPageLog.debug("[10..1F]: {x:0>2}", .{zero_page[0x10..0x20]});
                ZeroPageLog.debug("[20..2F]: {x:0>2}", .{zero_page[0x20..0x30]});
                ZeroPageLog.debug("[30..3F]: {x:0>2}", .{zero_page[0x30..0x40]});
                ZeroPageLog.debug("[40..4F]: {x:0>2}", .{zero_page[0x40..0x50]});
                ZeroPageLog.debug("[50..5F]: {x:0>2}", .{zero_page[0x50..0x60]});
                ZeroPageLog.debug("[60..6F]: {x:0>2}", .{zero_page[0x60..0x70]});
                ZeroPageLog.debug("[70..7F]: {x:0>2}", .{zero_page[0x70..0x80]});
                ZeroPageLog.debug("[80..8F]: {x:0>2}", .{zero_page[0x80..0x90]});
                ZeroPageLog.debug("[90..9F]: {x:0>2}", .{zero_page[0x90..0xA0]});
                ZeroPageLog.debug("[A0..AF]: {x:0>2}", .{zero_page[0xA0..0xB0]});
                ZeroPageLog.debug("[B0..BF]: {x:0>2}", .{zero_page[0xB0..0xC0]});
                ZeroPageLog.debug("[C0..CF]: {x:0>2}", .{zero_page[0xC0..0xD0]});
                ZeroPageLog.debug("[D0..DF]: {x:0>2}", .{zero_page[0xD0..0xE0]});
                ZeroPageLog.debug("[E0..EF]: {x:0>2}", .{zero_page[0xE0..0xF0]});
                ZeroPageLog.debug("[F0..FF]: {x:0>2}", .{zero_page[0xF0..0x100]});
            }

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

                .STA_ZPG, .STA_ZPX, .STA_ABS, .STA_ABX, .STA_ABY, .STA_IDX, .STA_IDY => self.store(self.registers.accumulator, self.get_instruction_address(switch (op) {
                    .STA_ZPG => .ZPG,
                    .STA_ZPX => .ZPX,
                    .STA_ABS => .ABS,
                    .STA_ABX => .ABX_MAX_CYCLE,
                    .STA_ABY => .ABY_MAX_CYCLE,
                    .STA_IDX => .IDX,
                    .STA_IDY => .IDY_MAX_CYCLE,
                    else => unreachable,
                })),

                .STX_ZPG, .STX_ZPY, .STX_ABS => self.store(self.registers.x, self.get_instruction_address(switch (op) {
                    .STX_ZPG => .ZPG,
                    .STX_ZPY => .ZPY,
                    .STX_ABS => .ABS,
                    else => unreachable,
                })),
                .STY_ZPG, .STY_ZPX, .STY_ABS => self.store(self.registers.y, self.get_instruction_address(switch (op) {
                    .STY_ZPG => .ZPG,
                    .STY_ZPX => .ZPX,
                    .STY_ABS => .ABS,
                    else => unreachable,
                })),

                .TAX => {
                    self.cycles +%= 1;
                    self.load_x(self.registers.accumulator);
                },
                .TAY => {
                    self.cycles +%= 1;
                    self.load_y(self.registers.accumulator);
                },
                .TXA => {
                    self.cycles +%= 1;
                    self.load_accumulator(self.registers.x);
                },
                .TYA => {
                    self.cycles +%= 1;
                    self.load_accumulator(self.registers.y);
                },

                .TSX => {
                    self.cycles +%= 1;
                    self.load_x(self.registers.stack_pointer);
                },
                .TXS => {
                    self.cycles +%= 1;
                    self.registers.stack_pointer = self.registers.x;
                },
                .PHA => self.push(self.registers.accumulator),
                .PHP => self.push_flags(),
                .PLA => {
                    self.cycles +%= 1;
                    self.load_accumulator(self.pop());
                },
                .PLP => {
                    self.cycles +%= 1;
                    self.pop_flags();
                },

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
                    const before: u16 = self.registers.accumulator;
                    const result: u16 = before + value + @intFromBool(self.flags.carry);
                    Log.debug("{x:0>2} + {x:0>2} + {} = {x:0>2}", .{ before, value, @intFromBool(self.flags.carry), result });
                    // https://www.righto.com/2012/12/the-6502-overflow-flag-explained.html
                    // Disch's solution: https://forums.nesdev.org/viewtopic.php?t=6331
                    self.flags.overflow = (before ^ result) & (value ^ result) & 0x80 > 0;
                    // http://apple1.chez.com/Apple1project/Docs/m6502/6502%20C64%20Programmer%20Guide.txt
                    self.flags.carry = result > 0xFF;
                    self.load_accumulator(@truncate(result));
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
                    const carry_in = self.flags.carry;
                    const before: u16 = self.registers.accumulator;
                    // http://forum.6502.org/viewtopic.php?t=18
                    // Removes one when the carry flag is CLEAR
                    const result: u16 = before -% value -% @intFromBool(!carry_in);
                    Log.debug("{x:0>2} - {x:0>2} - {} = {x:0>2}", .{ before, value, @intFromBool(!self.flags.carry), result });
                    // https://www.righto.com/2012/12/the-6502-overflow-flag-explained.html
                    self.flags.overflow = (before ^ result) & (before ^ value) & 0x80 > 0;
                    // 6502 is opposite to industry standard and sets carry when AC is smaller than the operand.
                    // It's an "not borrow" flag
                    // http://apple1.chez.com/Apple1project/Docs/m6502/6502%20C64%20Programmer%20Guide.txt
                    self.flags.carry = result < 0x100;
                    self.load_accumulator(@truncate(result));
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
                    Log.debug("Comparing value: {x:0>2}", .{value});
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
                    Log.debug("Comparing value: {x:0>2}", .{value});
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
                    Log.debug("Comparing value: {x:0>2}", .{value});
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
                    const res = self.fetch_u8(address) +% 1;
                    self.store(res, address);
                    Log.debug("[{}]: {x:0>2}", .{ address, res });
                    self.flags.set_negative(res);
                    self.flags.set_zero(res);
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
                    const res = self.fetch_u8(address) -% 1;
                    self.store(res, address);
                    Log.debug("[{}]: {x:0>2}", .{ address, res });
                    self.flags.set_negative(res);
                    self.flags.set_zero(res);
                },

                .DEX => self.load_x(self.registers.x -% 1),
                .DEY => self.load_y(self.registers.y -% 1),

                .ASL => {
                    self.cycles +%= 1;
                    self.flags.carry = self.registers.accumulator & 0b10000000 > 0;
                    self.load_accumulator(self.registers.accumulator << 1);
                },

                .ASL_ZPG, .ASL_ZPX, .ASL_ABS, .ASL_ABX => {
                    self.cycles +%= 1;
                    const address = self.get_instruction_address(switch (op) {
                        .ASL_ZPG => .ZPG,
                        .ASL_ZPX => .ZPX,
                        .ASL_ABS => .ABS,
                        .ASL_ABX => .ABX_MAX_CYCLE,
                        else => unreachable,
                    });
                    const prev = self.fetch_u8(address);
                    self.flags.carry = prev & 0b10000000 > 0;
                    const res = prev << 1;
                    self.store(res, address);

                    Log.debug("[{}]: {x:0>2}", .{ address, res });
                    self.flags.set_zero(res);
                    self.flags.set_negative(res);
                },

                .LSR => {
                    self.cycles +%= 1;
                    self.flags.carry = self.registers.accumulator & 0b1 > 0;
                    self.load_accumulator(self.registers.accumulator >> 1);
                },

                .LSR_ZPG, .LSR_ZPX, .LSR_ABS, .LSR_ABX => {
                    self.cycles +%= 1;
                    const address = self.get_instruction_address(switch (op) {
                        .LSR_ZPG => .ZPG,
                        .LSR_ZPX => .ZPX,
                        .LSR_ABS => .ABS,
                        .LSR_ABX => .ABX_MAX_CYCLE,
                        else => unreachable,
                    });

                    const prev = self.fetch_u8(address);
                    self.flags.carry = prev & 0b1 > 0;
                    const res = prev >> 1;
                    self.store(res, address);
                    Log.debug("[{}]: {x:0>2}", .{ address, res });
                    self.flags.set_zero(res);
                    self.flags.set_negative(res);
                },

                .ROL => {
                    self.cycles +%= 1;
                    const carry = self.registers.accumulator & 0b10000000 > 0;
                    self.registers.accumulator <<= 1;
                    if (self.flags.carry) {
                        self.registers.accumulator |= 0b00000001;
                    }
                    self.flags.carry = carry;
                    self.load_accumulator(self.registers.accumulator);
                },

                .ROL_ZPG, .ROL_ZPX, .ROL_ABS, .ROL_ABX => {
                    self.cycles +%= 1;
                    const address = self.get_instruction_address(switch (op) {
                        .ROL_ZPG => .ZPG,
                        .ROL_ZPX => .ZPX,
                        .ROL_ABS => .ABS,
                        .ROL_ABX => .ABX_MAX_CYCLE,
                        else => unreachable,
                    });
                    const prev = self.fetch_u8(address);
                    const carry = prev & 0b10000000 > 0;
                    var res = prev << 1;
                    if (self.flags.carry) {
                        res |= 0b00000001;
                    }
                    self.store(res, address);
                    Log.debug("[{}]: {x:0>2}", .{ address, res });
                    self.flags.carry = carry;
                    self.flags.set_zero(res);
                    self.flags.set_negative(res);
                },

                .ROR => {
                    self.cycles +%= 1;
                    const carry = self.registers.accumulator & 0b00000001 > 0;
                    self.registers.accumulator >>= 1;
                    if (self.flags.carry) {
                        self.registers.accumulator |= 0b10000000;
                    }
                    self.flags.carry = carry;
                    self.load_accumulator(self.registers.accumulator);
                },

                .ROR_ZPG, .ROR_ZPX, .ROR_ABS, .ROR_ABX => {
                    self.cycles +%= 1;
                    const address = self.get_instruction_address(switch (op) {
                        .ROR_ZPG => .ZPG,
                        .ROR_ZPX => .ZPX,
                        .ROR_ABS => .ABS,
                        .ROR_ABX => .ABX_MAX_CYCLE,
                        else => unreachable,
                    });
                    const prev = self.fetch_u8(address);
                    const carry = prev & 0b000000001 > 0;
                    var res = prev >> 1;
                    if (self.flags.carry) {
                        res |= 0b10000000;
                    }
                    self.store(res, address);
                    Log.debug("[{}]: {x:0>2}", .{ address, res });
                    self.flags.carry = carry;
                    self.flags.set_zero(res);
                    self.flags.set_negative(res);
                },

                .JMP_ABS => self.registers.program_counter = self.get_instruction_address(.ABS) -% 1,
                .JMP_IND => self.registers.program_counter = self.get_instruction_address(.IND) -% 1,
                .JSR_ABS => {
                    const subroutine_address = self.get_instruction_address(.ABS) -% 1;
                    self.push_program_counter();
                    self.registers.program_counter = subroutine_address;
                },
                .RTS => {
                    // Does extra reads in the real ship and takes 2 extra cycles
                    // http://forum.6502.org/viewtopic.php?f=2&t=5146
                    self.cycles +%= 2;
                    self.pop_program_counter();
                },

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
                        self.cycles +%= 1;
                    }
                },

                .CLC => {
                    self.cycles +%= 1;
                    self.flags.carry = false;
                },
                .CLD => {
                    self.cycles +%= 1;
                    self.flags.decimal_mode = false;
                },
                .CLI => {
                    self.cycles +%= 1;
                    self.flags.interupt_disabled = false;
                },
                .CLV => {
                    self.cycles +%= 1;
                    self.flags.overflow = false;
                },
                .SEC => {
                    self.cycles +%= 1;
                    self.flags.carry = true;
                },
                .SED => {
                    self.cycles +%= 1;
                    self.flags.decimal_mode = true;
                },
                .SEI => {
                    self.cycles +%= 1;
                    self.flags.interupt_disabled = true;
                },

                .BRK => {
                    // Add two to get the correct offset of the return address on the stack
                    self.registers.program_counter +%= 2;
                    self.push_program_counter();
                    self.push_flags();
                    // Only pay for one stack pointer increment
                    self.cycles -%= 1;
                    self.flags.break_command = true;
                    self.flags.interupt_disabled = true;
                    self.registers.program_counter = self.fetch_u16(BRK_INTERUPT_HANDLER_ADDRESS) -% 1;
                },
                .NOP => self.cycles +%= 1,
                .RTI => {
                    self.pop_flags();
                    self.pop_program_counter();
                    // Remove one so that the next step with increment to the specified address
                    self.registers.program_counter -%= 1;
                },

                _ => std.debug.panic("Attempted to run invalid op code {x:0>2}", .{@intFromEnum(op)}),
            }

            if (self.registers.program_counter == program_counter_before) {
                std.debug.panic("Trap encountered at {x:0>4}\n", .{self.registers.program_counter + 1});
            }

            return op;
        }

        fn next_program_u8(self: *Self) u8 {
            self.registers.program_counter +%= 1;
            return self.fetch_u8(self.registers.program_counter);
        }

        fn next_program_u16(self: *Self) u16 {
            self.registers.program_counter +%= 1;
            const out = self.fetch_u16(self.registers.program_counter);
            self.registers.program_counter +%= 1;
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
                .ABS, .ABX, .ABX_MAX_CYCLE, .ABY, .ABY_MAX_CYCLE, .IND => self.next_program_u16(),
                else => @intCast(self.next_program_u8()),
            }, mode);
        }

        fn fetch_u8(self: *Self, address: u16) u8 {
            self.cycles +%= 1;
            return self.memory.read(address);
        }

        fn fetch_u16(self: *Self, address: u16) u16 {
            const low: u16 = @intCast(self.fetch_u8(address));
            const high: u16 = @intCast(self.fetch_u8(address +% 1));
            return (high << 8) + low;
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

        fn store(self: *Self, value: u8, address: u16) void {
            self.cycles +%= 1;
            self.memory.write(address, value);
        }

        fn store_u16(self: *Self, value: u16, address: u16) void {
            self.store(@truncate(value), address);
            self.store(@truncate(value >> 8), address + 1);
        }

        /// https://www.nesdev.org/wiki/CPU_addressing_modes
        ///
        /// Increments cycles if a page boundary would be crossed
        fn get_address(self: *Self, input: u16, mode: AddressingMode) u16 {
            const address = switch (mode) {
                .ZPG => input,
                .ZPX => blk: {
                    self.cycles +%= 1;
                    break :blk (@as(u8, @intCast(input)) +% self.registers.x);
                },
                .ZPY => blk: {
                    self.cycles +%= 1;
                    break :blk (@as(u8, @intCast(input)) +% self.registers.y);
                },
                .ABS => input,
                .ABX, .ABX_MAX_CYCLE => blk: {
                    const address = input +% self.registers.x;
                    // +1 if page cross (if address + 1 goes into the next 256 byte area)
                    if (mode == .ABX_MAX_CYCLE or input & 0xFF00 != address & 0xFF00) {
                        self.cycles +%= 1;
                    }
                    break :blk address;
                },
                .ABY, .ABY_MAX_CYCLE => blk: {
                    const address = input +% self.registers.y;
                    // +1 if page cross (if address + 1 goes into the next 256 byte area)
                    if (mode == .ABY_MAX_CYCLE or input & 0xFF00 != address & 0xFF00) {
                        self.cycles +%= 1;
                    }
                    break :blk address;
                },
                .IND => self.fetch_u16(input),
                .IDX => blk: {
                    self.cycles +%= 1; // For high byte addition
                    const low: u16 = self.fetch_u8((input + self.registers.x) % 256);
                    const high: u16 = self.fetch_u8((input + self.registers.x + 1) % 256);
                    break :blk (high << 8) + low;
                    // break :blk self.fetch_u16(input + self.registers.x);
                },
                // http://forum.6502.org/viewtopic.php?f=2&t=2195#p19862
                .IDY, .IDY_MAX_CYCLE => blk: {
                    const low: u16 = self.fetch_u8(input);
                    const high: u16 = self.fetch_u8((input + 1) % 256);
                    const raw_address = (high << 8) +% low;
                    const address = raw_address +% self.registers.y;
                    // +1 if page cross (if address + 1 goes into the next 256 byte area)
                    if (mode == .IDY_MAX_CYCLE or raw_address & 0xFF00 != address & 0xFF00) {
                        self.cycles +%= 1;
                    }
                    break :blk address;
                    // break :blk self.fetch_u16(input) + self.registers.y;
                },
                .REL => blk: {
                    const relative = @as(i8, @bitCast(@as(u8, @intCast(input))));
                    var address = self.registers.program_counter;
                    if (relative < 0) {
                        address -%= @abs(relative);
                    } else {
                        address +%= @abs(relative);
                    }
                    // Take extra cycle to increment high byte if it has changed
                    if (self.registers.program_counter & 0xFF00 != address & 0xFF00) self.cycles +%= 1;
                    break :blk address;
                },
            };
            Log.debug("get_address: {x:0>4} ({0b:0>16})", .{address});
            return address;
        }

        pub fn get_current_stack_address(self: *Self) u16 {
            return STACK_START + @as(u16, @intCast(self.registers.stack_pointer));
        }

        fn push_program_counter(self: *Self) void {
            self.registers.stack_pointer -= 1;
            const address = self.get_current_stack_address();
            self.registers.stack_pointer -= 1;
            self.cycles +%= 1; // Only one stack pointer update cost should be paid
            self.store_u16(self.registers.program_counter, address);
        }

        fn push_flags(self: *Self) void {
            self.push(@as(u8, @bitCast(self.flags)) | ~Flags.STACK_MASK);
        }

        fn push(self: *Self, value: u8) void {
            self.store(value, self.get_current_stack_address());
            self.cycles +%= 1;
            self.registers.stack_pointer -%= 1;
        }

        fn pop_program_counter(self: *Self) void {
            self.registers.stack_pointer += 1;
            const address = self.get_current_stack_address();
            self.registers.stack_pointer += 1;
            self.cycles +%= 1; // Only one stack pointer update cost should be paid
            self.registers.program_counter = self.fetch_u16(address);
        }

        fn pop_flags(self: *Self) void {
            self.flags = @bitCast(self.pop() & Flags.STACK_MASK);
        }

        fn pop(self: *Self) u8 {
            self.cycles +%= 1;
            self.registers.stack_pointer +%= 1;
            return self.fetch_u8(self.get_current_stack_address());
        }
    };
}

test {
    std.testing.refAllDecls(@import("./6502_cycles_test.zig"));
}

test "functional test" {
    const CODE_START_ADDRESS = 0x0400;
    const SUCCESS_TRAP_ADDRESS = 0x336d;
    const BIN_START_ADDRESS = 0x000A;
    const test_binary = @embedFile("./tests/6502_functional_test.bin");
    var memory_map = BufferMemoryMap{};
    var cpu = CPU(BufferMemoryMap).init(&memory_map);
    @memcpy(memory_map.buffer[BIN_START_ADDRESS..], test_binary[0..]);
    cpu.registers.program_counter = CODE_START_ADDRESS - 1;

    var iteratons: u32 = 0;
    while (cpu.registers.program_counter + 1 != SUCCESS_TRAP_ADDRESS) : (iteratons += 1) {
        if (iteratons > 0xFFFFFFFF) return .TooManyIterations;
        _ = cpu.step();
    }
}
