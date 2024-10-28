const std = @import("std");

const Log = std.log.scoped(.hexLoader);

const LENGTH_OFFSET = 0 * 2;
const LENGTH_LEN = 1 * 2;
const ADDRESS_OFFSET = 1 * 2;
const ADDRESS_LEN = 2 * 2;
/// Offset of the first type hex digit which is always '0'
const TYPE_ZERO_OFFSET = 4 * 2;
const TYPE_OFFSET = 5 * 2;
const DATA_OFFSET = 6 * 2;
const CHECKSUM_LENGTH = 2 * 2;
const RECORD_FIELD_LENGTH = TYPE_OFFSET + CHECKSUM_LENGTH;

/// https://en.wikipedia.org/wiki/Intel_HEX#Record_Types
const RecordType = enum(u8) {
    /// The byte count specifies number of data bytes in the record. The example has 0B (eleven) data
    /// bytes. The 16-bit starting address for the data (in the example at addresses beginning at 0010)
    /// and the data (61, 64, 64, 72, 65, 73, 73, 20, 67, 61, 70).
    Data = '0',
    /// Must occur exactly once per file in the last record of the file. The byte count is 00,
    /// the address field is typically 0000 and the data field is omitted.
    EOF = '1',
    /// the data field contains a 16-bit segment base address. This is multiplied by 16 and
    /// added to each subsequent data record address to form the starting address for the data.
    ExtendedSegmentAddress = '2',
    /// The byte count is always 04, the address field is 0000.
    ///
    /// The four data bytes represent a 32-bit address value (big endian). In the case of CPUs
    /// that support it, this 32-bit address is the address at which execution should start.
    ExtendedLineraAddress = '4',
    /// The byte count is always 04, the address field is 0000. The four data bytes represent a 32-bit
    /// address value (big endian). In the case of CPUs that support it, this 32-bit address is the
    /// address at which execution should start.
    StartLinearAddress = '5',
};

/// https://developer.arm.com/documentation/ka003292/latest/
///
/// Hex file must end with an EOF record ":00000001FF"
pub fn read(input: anytype, output: []u8) !void {
    while (true) {
        // : is the colon that starts every Intel HEX record.
        const colon = try input.readByte();
        if (colon != ':') {
            Log.err("Line did not start with ':'", .{});
            return error.InvalidLineStart;
        }
        // ll is the record-length field that represents the number of data bytes (dd) in the record.
        const record_length = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
        Log.debug("Record Length: {x:0>2}({0any})", .{record_length});

        // aaaa is the address field that represents the starting address for subsequent data in the record.
        const address = try std.fmt.parseInt(u16, &try input.readBytesNoEof(4), 16);
        Log.debug("Address: {x:0>4}", .{address});

        // tt is the field that represents the HEX record type
        if (try input.readByte() != '0') {
            Log.err("First hex digit of type was not '0'", .{});
            return error.InvalidTypeHex;
        }
        const record_type = try input.readEnum(RecordType, .big);
        Log.debug("Record Type: {s}", .{@tagName(record_type)});

        // dd is a data field that represents one byte of data. A record may have
        // multiple data bytes. The number of data bytes in the record must match the
        // number specified by the ll field.
        const data = output[address .. address + record_length];

        if (record_length > 0) {
            if (address + record_length > output.len) {
                Log.err("Output slice is not big enough to contain the HEX data. Tried to write 0x{x} bytes at 0x{x}", .{ record_length, address });
                return error.OutputTooSmall;
            }

            for (data) |*d| {
                d.* = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
            }
            Log.debug("Data: {X:0>2}\n", .{data});
        }

        const checksum_or_end_of_line = input.readBytesNoEof(2) catch |err| switch (err) {
            @TypeOf(input).NoEofError.EndOfStream => .{ '\r', '\n' },
            else => return err,
        };
        // Checksum is optional
        if (!std.mem.eql(u8, &checksum_or_end_of_line, "\r\n")) {
            const line_end = input.readBytesNoEof(2) catch |err| switch (err) {
                @TypeOf(input).NoEofError.EndOfStream => .{ '\r', '\n' },
                else => return err,
            };
            if (!std.mem.eql(u8, &line_end, "\r\n")) {
                Log.err("Did not find return and newline after checksum", .{});
                return error.MissingEndOfLine;
            }

            // cc is the checksum field that represents the checksum of the record. The
            // checksum is calculated by summing the values of all hexadecimal digit pairs in
            // the record modulo 256 and taking the two's complement.
            const expected_checksum = try std.fmt.parseInt(u8, &checksum_or_end_of_line, 16);
            Log.debug("Checksum: {}", .{expected_checksum});

            var checksum: u8 = @intCast((record_length + address +
                // Convert from ASCII digit to number
                (@intFromEnum(record_type) - 0x30)) % 255);
            for (data) |byte| {
                checksum +%= byte;
            }
            checksum = @addWithOverflow(~checksum, 1)[0];

            if (checksum != expected_checksum) {
                Log.err("Checksum failed: expected {x:0>2}, got {x:0>2}", .{ expected_checksum, checksum });
                return error.InvalidChecksum;
            }
        }
        if (record_type == .EOF) {
            return;
        }
    }
}

test read {
    const HEX =
        ":10001300AC12AD13AE10AF1112002F8E0E8F0F2244\r\n" ++
        ":10000300E50B250DF509E50A350CF5081200132259\r\n" ++
        ":03000000020023D8\r\n" ++
        ":0C002300787FE4F6D8FD7581130200031D\r\n" ++
        ":10002F00EFF88DF0A4FFEDC5F0CEA42EFEEC88F016\r\n" ++
        ":04003F00A42EFE22CB\r\n" ++
        ":00000001FF";
    var DATA = [_]u8{0} ** 0xFF;
    @memcpy(DATA[0x0013 .. 0x0013 + 0x10], &[0x10]u8{
        0xAC,
        0x12,
        0xAD,
        0x13,
        0xAE,
        0x10,
        0xAF,
        0x11,
        0x12,
        0x00,
        0x2F,
        0x8E,
        0x0E,
        0x8F,
        0x0F,
        0x22,
    });
    @memcpy(DATA[0x0003 .. 0x0003 + 0x10], &[0x10]u8{
        0xE5,
        0x0B,
        0x25,
        0x0D,
        0xF5,
        0x09,
        0xE5,
        0x0A,
        0x35,
        0x0C,
        0xF5,
        0x08,
        0x12,
        0x00,
        0x13,
        0x22,
    });
    @memcpy(DATA[0x0000 .. 0x0000 + 0x03], &[0x03]u8{
        0x02, 0x00, 0x23,
    });
    @memcpy(DATA[0x0023 .. 0x0023 + 0x0C], &[0x0C]u8{
        0x78,
        0x7F,
        0xE4,
        0xF6,
        0xD8,
        0xFD,
        0x75,
        0x81,
        0x13,
        0x02,
        0x00,
        0x03,
    });
    @memcpy(DATA[0x002F .. 0x002F + 0x10], &[0x10]u8{
        0xEF,
        0xF8,
        0x8D,
        0xF0,
        0xA4,
        0xFF,
        0xED,
        0xC5,
        0xF0,
        0xCE,
        0xA4,
        0x2E,
        0xFE,
        0xEC,
        0x88,
        0xF0,
    });
    @memcpy(DATA[0x003F .. 0x003F + 0x04], &[0x04]u8{
        0xA4, 0x2E, 0xFE, 0x22,
    });
    var output = [_]u8{0} ** DATA.len;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}

test "data record one" {
    const HEX = ":10246200464C5549442050524F46494C4500464C33\r\n" ++
        ":00000001FF";
    var DATA = [_]u8{0} ** (0x2462 + 0x10);
    @memcpy(DATA[0x2462 .. 0x2462 + 0x10], &[0x10]u8{
        0x46,
        0x4C,
        0x55,
        0x49,
        0x44,
        0x20,
        0x50,
        0x52,
        0x4F,
        0x46,
        0x49,
        0x4C,
        0x45,
        0x00,
        0x46,
        0x4C,
    });
    var output = [_]u8{0} ** DATA.len;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}

test "data record two" {
    const HEX = ":100130003F0156702B5E712B722B732146013421C7\r\n" ++
        ":00000001FF";
    var DATA = [_]u8{0} ** (0x0130 + 0x10);
    @memcpy(DATA[0x0130 .. 0x0130 + 0x10], &[0x10]u8{
        0x3F,
        0x01,
        0x56,
        0x70,
        0x2B,
        0x5E,
        0x71,
        0x2B,
        0x72,
        0x2B,
        0x73,
        0x21,
        0x46,
        0x01,
        0x34,
        0x21,
    });
    var output = [_]u8{0} ** DATA.len;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}
