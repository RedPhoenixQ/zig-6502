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

    // Set platform subroutines to return
    @memset(cpu.memory[0xe000..0xe05A], @intFromEnum(CPU.Op.RTS));

    cpu.reset();
    cpu.registers.program_counter = 0x0200 - 1;

    while (true) {
        _ = cpu.step();

        switch (cpu.registers.program_counter + 1) {
            0xe00f => { // Puts
                const address = cpu.get_current_stack_address() + 1;
                // Get address of called from the stack
                const start = std.mem.readInt(u16, @ptrCast(cpu.memory[address .. address + 2]), .little) + 1;
                const end = std.mem.indexOf(u8, cpu.memory[start..], &[_]u8{0});

                try std.io.getStdOut().writeAll(cpu.memory[start .. start + end.?]);

                // Set return address past the string data
                std.mem.writeInt(u16, @ptrCast(cpu.memory[address .. address + 2]), @intCast(start + end.?), .little);
            },
            else => {},
        }
    }
}
