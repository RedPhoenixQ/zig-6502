const std = @import("std");

const Log = std.log.scoped(.SRecLoader);

const Kind = enum(u8) {
    Header = '0',
    Data16 = '1',
    Data24 = '2',
    Data32 = '3',
    // '4' is reserved and unused
    Terminator16 = '9',
    Terminator24 = '8',
    Terminator32 = '7',
    RecordCount16 = '5',
    RecordCount24 = '6',

    fn address_bytes(self: Kind) u3 {
        return switch (self) {
            .Data16, .Terminator16, .RecordCount16, .Header => 2,
            .Data24, .Terminator24, .RecordCount24 => 3,
            .Data32, .Terminator32 => 4,
        };
    }
};

pub fn read(reader: anytype, output: []u8) !?u32 {
    var data_records_seen: u16 = 0;
    var header_buf = [_]u8{0} ** 0xFF;
    while (true) {
        const first_byte = while (true) {
            const byte = reader.readByte() catch |err| switch (err) {
                error.EndOfStream => return null,
                else => return err,
            };
            // Consume whitespace
            if (!std.ascii.isWhitespace(byte)) break byte;
        };
        if (first_byte != 'S') {
            Log.err("Line did not start with 'S', got '{any}'(0x{0X:0>2})", .{first_byte});
            return error.InvalidLineStart;
        }

        const kind: Kind = try reader.readEnum(Kind, .big);
        Log.debug("Kind: {s}", .{@tagName(kind)});

        const count = try std.fmt.parseInt(u8, &try reader.readBytesNoEof(2), 16);
        Log.debug("Count: {X:0>2} ({0any})", .{count});
        switch (kind) {
            .Terminator16, .RecordCount16 => std.debug.assert(count == 3),
            .Terminator24, .RecordCount24 => std.debug.assert(count == 4),
            .Terminator32 => std.debug.assert(count == 5),
            else => {},
        }

        var checksum: u32 = count;

        var address_bytes = [_]u8{0} ** 4;
        _ = switch (kind) {
            .Data16, .Terminator16, .RecordCount16, .Header => try std.fmt.hexToBytes(address_bytes[2..], &try reader.readBytesNoEof(4)),
            .Data24, .Terminator24, .RecordCount24 => try std.fmt.hexToBytes(address_bytes[1..], &try reader.readBytesNoEof(6)),
            .Data32, .Terminator32 => try std.fmt.hexToBytes(address_bytes[0..], &try reader.readBytesNoEof(8)),
        };
        for (address_bytes) |byte| checksum += byte;
        const address = std.mem.readInt(u32, &address_bytes, .big);
        Log.debug("Address: {X:0>8} ({0any})", .{address});

        const data_len = count - 1 - kind.address_bytes();
        const data = switch (kind) {
            .Header => header_buf[0..data_len],
            else => output[address .. address + data_len],
        };
        for (data) |*d| {
            d.* = try std.fmt.parseInt(u8, &try reader.readBytesNoEof(2), 16);
            checksum += d.*;
        }
        Log.debug("Data: {X:0>2}", .{data});

        const expected_checksum = try std.fmt.parseInt(u8, &try reader.readBytesNoEof(2), 16);
        Log.debug("Checksum: {X:0>2}", .{expected_checksum});
        checksum = 0xFF - @as(u8, @truncate(checksum));
        if (checksum != expected_checksum) {
            Log.err("Checksum failed: expected {X:0>2}, got {X:0>2}", .{ expected_checksum, checksum });
            return error.InvalidChecksum;
        }

        switch (kind) {
            // Address stores the number of records
            .RecordCount16, .RecordCount24 => if (address != data_records_seen) {
                Log.err("Did not recive the expected number of data records before S5 record, expected {} got {}", .{ address, data_records_seen });
                return error.IncorrectNumberOfRecords;
            },
            .Data16, .Data24, .Data32 => data_records_seen += 1,
            .Header => Log.info("Header: {s}", .{data}),
            .Terminator16, .Terminator24, .Terminator32 => return address,
        }
    }
}

test read {
    const SREC =
        \\S00F000068656C6C6F202020202000003C
        \\S11F00007C0802A6900100049421FFF07C6C1B787C8C23783C6000003863000026
        \\S11F001C4BFFFFE5398000007D83637880010014382100107C0803A64E800020E9
        \\S111003848656C6C6F20776F726C642E0A0042
        \\S5030003F9
        \\S9030000FC
    ;
    var DATA = [_]u8{0xFF} ** 0x60;
    _ = try std.fmt.hexToBytes(DATA[0x0000..], "7C0802A6900100049421FFF07C6C1B787C8C23783C60000038630000");
    _ = try std.fmt.hexToBytes(DATA[0x001C..], "4BFFFFE5398000007D83637880010014382100107C0803A64E800020");
    _ = try std.fmt.hexToBytes(DATA[0x0038..], "48656C6C6F20776F726C642E0A00");

    var output = [_]u8{0xFF} ** DATA.len;
    var stream = std.io.fixedBufferStream(SREC);
    const reader = stream.reader();

    const address = try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
    try std.testing.expect(address != null);
    try std.testing.expectEqual(u8, 0x0000, address.?);
}
