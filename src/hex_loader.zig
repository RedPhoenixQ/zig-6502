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

const RecordType = enum(u8) {
    Data = '0',
    EOF = '1',
    ExtendedSegmentAddress = '2',
    ExtendedLineraAddress = '4',
    /// (MDK-ARM only)
    StartLinearAddress = '5',
};

/// https://developer.arm.com/documentation/ka003292/latest/
pub fn from_hex(input: anytype, output: anytype) !void {
    var buf: [128]u8 = undefined;

    while (true) {
        // : is the colon that starts every Intel HEX record.
        const colon = input.readByte() catch |err| if (err == error.EndOfStream) break else return err;
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
        const data_read = try input.readAtLeast(buf[0 .. record_length * 2], record_length * 2 - 1);
        if (data_read == record_length * 2 - 1) {
            Log.err("Length did not match the amount of bytes read", .{});
            return error.InvalidLineLength;
        }
        const data_hex = buf[0..data_read];
        Log.debug("Data hex: {s}", .{data_hex});

        const data = buf[0..record_length];
        for (data, 0..data.len) |*d, i| {
            d.* = try std.fmt.parseInt(u8, data_hex[i * 2 .. i * 2 + 2], 16);
        }
        Log.debug("Data: {any}\n", .{data});
        try output.writeAll(data);

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
            const checksum = try std.fmt.parseInt(u8, &checksum_or_end_of_line, 16);
            Log.debug("Checksum: {}", .{checksum});

            var sum: u8 = @intCast((record_length + address +
                // Convert from ASCII digit to number
                (@intFromEnum(record_type) - 0x30)) % 255);
            for (data) |byte| {
                sum +%= byte;
            }
            sum = @addWithOverflow(~sum, 1)[0];

            if (sum != checksum) {
                Log.err("Checksum failed: expected {x:0>2}, got {x:0>2}", .{ checksum, sum });
                // return error.InvalidChecksum;
            }
        }
    }
}

test from_hex {
    const HEX = ":10246200464C5549442050524F46494C4500464C33";
    const DATA = [_]u8{ 70, 76, 85, 73, 68, 32, 80, 82, 79, 70, 73, 76, 69, 0, 70, 76 };
    var output: [DATA.len]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&output);
    const writer = out_stream.writer();
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    try from_hex(reader, writer);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}

test "hex with checksum" {
    const HEX = ":100130003F0156702B5E712B722B732146013421C7";
    const DATA = [_]u8{ 63, 1, 86, 112, 43, 94, 113, 43, 114, 43, 115, 33, 70, 1, 52, 33 };
    var output: [DATA.len]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&output);
    const writer = out_stream.writer();
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    try from_hex(reader, writer);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}
