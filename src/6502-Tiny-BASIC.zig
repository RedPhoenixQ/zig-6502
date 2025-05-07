const std = @import("std");

const CPU = @import("./6502.zig");
const HexLoader = @import("./HexLoader.zig");

pub const std_options: std.Options = .{
    .log_level = .warn,
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
    const TINY_BASIC_HEX = @embedFile("./6502-Tiny-BASIC.hex");
    var stream = std.io.fixedBufferStream(TINY_BASIC_HEX);
    var mem = CPU.BufferMemoryMap{};
    _ = try HexLoader.read(stream.reader(), &mem.buffer);
    var cpu = CPU.CPU(CPU.BufferMemoryMap).init(&mem);

    // Set platform subroutines to return
    @memset(cpu.memory.buffer[0xe000 .. 0xe057 + 2], @intFromEnum(CPU.Op.RTS));
    @memset(cpu.memory.buffer[0x0206 .. 0x0212 + 2], @intFromEnum(CPU.Op.RTS));

    cpu.reset();
    cpu.registers.program_counter = 0x0200 - 1;

    while (true) {
        _ = cpu.step();

        switch (cpu.registers.program_counter + 1) {
            0xe00f => { // Puts
                const address = cpu.get_current_stack_address() + 1;
                // Get address of called from the stack
                const start = std.mem.readInt(u16, @ptrCast(cpu.memory.buffer[address .. address + 2]), .little) + 1;
                const end = std.mem.indexOf(u8, cpu.memory.buffer[start..], &[_]u8{0});

                try std.io.getStdOut().writeAll(cpu.memory.buffer[start .. start + end.?]);

                // Set return address past the string data
                std.mem.writeInt(u16, @ptrCast(cpu.memory.buffer[address .. address + 2]), @intCast(start + end.?), .little);
            },
            0x0206 => { // OUTCH output char in A
                const bytes_written = try std.io.getStdOut().write(&[_]u8{cpu.registers.accumulator});
                std.debug.assert(bytes_written == 1);
            },
            0x0209 => { // GETCH get char in A (blocks)
                var bytes: [1]u8 = undefined;
                const bytes_read = try std.io.getStdIn().read(&bytes);
                if (bytes[0] == "\n"[0]) {
                    _ = try std.io.getStdIn().read(&bytes);
                }
                std.debug.assert(bytes_read == 1);
                cpu.registers.accumulator = bytes[0];
            },
            0x020c => { // CRLF print CR/LF
                try std.io.getStdOut().writeAll("\r\n");
            },
            0x020f => { // OUTHEX print A as hex
                try std.fmt.formatInt(cpu.registers.accumulator, 16, .upper, .{}, std.io.getStdOut().writer());
            },
            0x0212 => { // MONITOR return to monitor
                std.log.warn("Monitor called", .{});
            },
            else => {},
        }
    }
}
