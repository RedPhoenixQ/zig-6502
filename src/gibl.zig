const std = @import("std");

const CPU = @import("./6502.zig");
const SRecLoader = @import("./SRecLoader.zig");

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
        CPU.ZeroPageScope, .SRecLoader => return,
        // Don't log debug cpu logs (compare values, computed addresses, ...)
        CPU.LogScope => if (message_level == .debug) return,
        else => {},
    }
    std.log.defaultLog(message_level, scope, format, args);
}

const READ_CHAR = 0xF00C;
const WRITE_CHAR = 0xF00F;
// const NEWLINE = 0xF00F;

pub fn main() !void {
    const MON = @embedFile("./gibl-sxb/mon.srec");
    const RAM = @embedFile("./gibl-sxb/ram.srec");
    const ROM = @embedFile("./gibl-sxb/rom.srec");
    var mem = CPU.BufferMemoryMap{};
    var stream = std.io.fixedBufferStream(MON);
    _ = try SRecLoader.read(stream.reader(), &mem.buffer);
    stream = std.io.fixedBufferStream(RAM);
    _ = try SRecLoader.read(stream.reader(), &mem.buffer);
    stream = std.io.fixedBufferStream(ROM);
    _ = try SRecLoader.read(stream.reader(), &mem.buffer);
    var cpu = CPU.CPU(CPU.BufferMemoryMap).init(&mem);

    for ([_]u16{ READ_CHAR, WRITE_CHAR }) |address| {
        mem.buffer[address] = @intFromEnum(CPU.Op.RTS);
    }

    cpu.reset();
    cpu.registers.program_counter = 0x1000 - 1;

    var prev_time = std.time.milliTimestamp();
    var delta: u64 = 0;
    const MS_PER_TIME = 1000;
    while (true) {
        _ = cpu.step();

        // Step add one to seconds at 160
        const time = std.time.milliTimestamp();
        delta +%= @intCast(time - prev_time);
        if (delta / MS_PER_TIME > 1) {
            cpu.memory[160] +%= @truncate(delta / MS_PER_TIME);
            delta %= MS_PER_TIME;
        }
        prev_time = time;

        switch (cpu.registers.program_counter + 1) {
            // 0xe00f => { // Puts
            //     const address = cpu.get_current_stack_address() + 1;
            //     // Get address of called from the stack
            //     const start = std.mem.readInt(u16, @ptrCast(cpu.memory[address .. address + 2]), .little) + 1;
            //     const end = std.mem.indexOf(u8, cpu.memory[start..], &[_]u8{0});

            //     try std.io.getStdOut().writeAll(cpu.memory[start .. start + end.?]);

            //     // Set return address past the string data
            //     std.mem.writeInt(u16, @ptrCast(cpu.memory[address .. address + 2]), @intCast(start + end.?), .little);
            // },
            WRITE_CHAR => { // OUTCH output char in A
                const bytes_written = try std.io.getStdOut().write(&[_]u8{cpu.registers.accumulator});
                std.debug.assert(bytes_written == 1);
            },
            READ_CHAR => { // GETCH get char in A (blocks)
                var bytes: [1]u8 = undefined;
                const bytes_read = try std.io.getStdIn().read(&bytes);
                if (bytes[0] == "\n"[0]) {
                    _ = try std.io.getStdIn().read(&bytes);
                }
                std.debug.assert(bytes_read == 1);
                cpu.registers.accumulator = bytes[0];
            },
            // 0x020c => { // CRLF print CR/LF
            //     try std.io.getStdOut().writeAll("\r\n");
            // },
            // 0x020f => { // OUTHEX print A as hex
            //     try std.fmt.formatInt(cpu.registers.accumulator, 16, .upper, .{}, std.io.getStdOut().writer());
            // },
            // 0x0212 => { // MONITOR return to monitor
            //     std.log.warn("Monitor called", .{});
            // },
            else => {},
        }
    }
}
