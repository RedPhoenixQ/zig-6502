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
    /// The byte count is always 02, the address field (typically 0000) is ignored and the data field
    /// contains a 16-bit segment base address. This is multiplied by 16 and added to each subsequent
    /// data record address to form the starting address for the data. This allows addressing up to
    /// one mebibyte (1048576 bytes) of address space.
    ExtendedSegmentAddress = '2',
    /// For 80x86 processors, specifies the starting execution address. The byte count is always 04,
    /// the address field is 0000 and the first two data bytes are the CS value, the latter two are
    /// the IP value. The execution should start at this address.
    StartSegmentAddress = '3',
    /// Allows for 32 bit addressing (up to 4 GiB). The byte count is always 02 and the address field
    /// is ignored (typically 0000). The two data bytes (big endian) specify the upper 16 bits of the
    /// 32 bit absolute address for all subsequent type 00 records; these upper address bits apply until
    /// the next 04 record. The absolute address for a type 00 record is formed by combining the upper
    /// 16 address bits of the most recent 04 record with the low 16 address bits of the 00 record. If a
    /// type 00 record is not preceded by any type 04 records then its upper 16 address bits default to 0000.
    ExtendedLineraAddress = '4',
    /// The byte count is always 04, the address field is 0000. The four data bytes represent a 32-bit
    /// address value (big endian). In the case of CPUs that support it, this 32-bit address is the
    /// address at which execution should start.
    StartLinearAddress = '5',
};

const Addresses = struct {
    /// Contains the address of the final EOF line of the hex file
    eof: u16 = 0,
    segment: ?SegmentAddress = null,
    /// In the case of CPUs that support it, this 32-bit address is the address at which execution
    /// should start.
    linear: ?u32 = null,

    const SegmentAddress = struct {
        code_segment: u16,
        /// The execution should start at this address.
        instruction_pointer: u16,
    };
};

/// https://developer.arm.com/documentation/ka003292/latest/
///
/// Hex file must end with an EOF record ":00000001FF"
///
/// Return an starting address if the hexfile includes it
pub fn read(input: anytype, output: []u8) !Addresses {
    var addresses: Addresses = .{};
    var segment_address_offset: u32 = 0;
    var linear_address_offset: u32 = 0;
    while (true) {
        const first_byte = while (true) {
            const byte = try input.readByte();
            // Consume whitespace
            if (!std.ascii.isWhitespace(byte)) break byte;
        };
        // : is the colon that starts every Intel HEX record.
        if (first_byte != ':') {
            Log.err("Line did not start with ':', got '{any}'(0x{0X:0>2})", .{first_byte});
            return error.InvalidLineStart;
        }
        var checksum: u8 = 0;

        // ll is the record-length field that represents the number of data bytes (dd) in the record.
        const record_length = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
        Log.debug("Record Length: 0x{X:0>2}({0any})", .{record_length});
        checksum +%= record_length;

        // aaaa is the address field that represents the starting address for subsequent data in the record.
        const address_bytes: [2]u8 = .{
            try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16),
            try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16),
        };
        checksum +%= address_bytes[0];
        checksum +%= address_bytes[1];
        const address = std.mem.readInt(u16, &address_bytes, .big);
        Log.debug("Address: {X:0>4}", .{address});
        const effective_address: u32 = segment_address_offset + linear_address_offset + address;
        if (effective_address != address) {
            Log.debug("Effective address: {X:0>8}", .{effective_address});
        }

        // tt is the field that represents the HEX record type
        if (try input.readByte() != '0') {
            Log.err("First hex digit of type was not '0'", .{});
            return error.InvalidTypeHex;
        }
        const record_type = try input.readEnum(RecordType, .big);
        Log.debug("Record Type: {s}", .{@tagName(record_type)});
        // Convert from ASCII digit to number
        checksum +%= (@intFromEnum(record_type) - 0x30);

        // dd is a data field that represents one byte of data. A record may have
        // multiple data bytes. The number of data bytes in the record must match the
        // number specified by the ll field.
        if (record_length > 0) {
            switch (record_type) {
                .Data => {
                    if (effective_address + record_length > output.len) {
                        Log.err("Output slice is not big enough to contain the HEX data. Tried to write 0x{X} bytes at 0x{X}", .{ record_length, effective_address });
                        return error.OutputTooSmall;
                    }

                    const data = output[effective_address .. effective_address + record_length];
                    for (data) |*d| {
                        d.* = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
                        checksum +%= d.*;
                    }
                },
                .ExtendedSegmentAddress => {
                    if (record_length != 0x02) {
                        return error.InvalidExtendedSegmentAddress;
                    }
                    var data: [2]u8 = undefined;
                    for (&data) |*d| {
                        d.* = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
                        checksum +%= d.*;
                    }
                    segment_address_offset = @as(u32, @intCast(std.mem.readInt(u16, &data, .big))) * 16;
                    Log.debug("Extended Segment Address: {X:0>4}", .{segment_address_offset});
                },
                .StartSegmentAddress => {
                    if (record_length != 0x04) {
                        return error.InvalidStartSegmentAddress;
                    } else if (address != 0x0000) {
                        return error.InvalidStartSegmentAddress;
                    }
                    var data: [4]u8 = undefined;
                    for (&data) |*d| {
                        d.* = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
                        checksum +%= d.*;
                    }
                    const segment: Addresses.SegmentAddress = .{
                        .code_segment = std.mem.readInt(u16, data[0..2], .big),
                        .instruction_pointer = std.mem.readInt(u16, data[2..], .big),
                    };
                    Log.debug("Code segment: {X:0>4}", .{segment.code_segment});
                    Log.debug("Instruction pointer: {X:0>4}", .{segment.instruction_pointer});
                    addresses.segment = segment;
                },
                .ExtendedLineraAddress => {
                    if (record_length != 0x02) {
                        return error.InvalidExtendedLineraAddress;
                    } else if (address != 0x0000) {
                        return error.InvalidExtendedLineraAddress;
                    }
                    var data: [2]u8 = undefined;
                    for (&data) |*d| {
                        d.* = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
                        checksum +%= d.*;
                    }
                    linear_address_offset = @as(u32, @intCast(std.mem.readInt(u16, &data, .big))) << 16;
                    Log.debug("Extended Linera Address: {X:0>4}\n", .{linear_address_offset});
                },
                .StartLinearAddress => {
                    if (record_length != 0x04) {
                        return error.InvalidStartLinearAddressRecord;
                    } else if (address != 0x0000) {
                        return error.InvalidStartLinearAddressRecord;
                    }
                    var data: [4]u8 = undefined;
                    for (&data) |*d| {
                        d.* = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
                        checksum +%= d.*;
                    }
                    addresses.linear = std.mem.readInt(u32, &data, .big);
                    Log.debug("Start Linear Address: {?X:0>8}\n", .{addresses.linear});
                },
                .EOF => {},
            }
        }

        // cc is the checksum field that represents the checksum of the record. The
        // checksum is calculated by summing the values of all hexadecimal digit pairs in
        // the record modulo 256 and taking the two's complement.
        const expected_checksum = try std.fmt.parseInt(u8, &try input.readBytesNoEof(2), 16);
        Log.debug("Checksum: {X:0>2}", .{expected_checksum});

        // Take the Two's Complement
        checksum = @addWithOverflow(~checksum, 1)[0];
        if (checksum != expected_checksum) {
            Log.err("Checksum failed: expected {X:0>2}, got {X:0>2}", .{ expected_checksum, checksum });
            return error.InvalidChecksum;
        }

        if (record_type == .EOF) {
            addresses.eof = address;
            return addresses;
        }
    }
}

test read {
    const HEX =
        \\:10001300AC12AD13AE10AF1112002F8E0E8F0F2244
        \\:10000300E50B250DF509E50A350CF5081200132259
        \\:03000000020023D8
        \\:0C002300787FE4F6D8FD7581130200031D
        \\:10002F00EFF88DF0A4FFEDC5F0CEA42EFEEC88F016
        \\:04003F00A42EFE22CB
        \\:00000001FF
    ;
    var DATA = [_]u8{0} ** 0x100;
    _ = try std.fmt.hexToBytes(DATA[0x0013..], "AC12AD13AE10AF1112002F8E0E8F0F22");
    _ = try std.fmt.hexToBytes(DATA[0x0003..], "E50B250DF509E50A350CF50812001322");
    _ = try std.fmt.hexToBytes(DATA[0x0000..], "020023");
    _ = try std.fmt.hexToBytes(DATA[0x0023..], "787FE4F6D8FD758113020003");
    _ = try std.fmt.hexToBytes(DATA[0x002F..], "EFF88DF0A4FFEDC5F0CEA42EFEEC88F0");
    _ = try std.fmt.hexToBytes(DATA[0x003F..], "A42EFE22");
    var output = [_]u8{0} ** DATA.len;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    _ = try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}

test "Data" {
    const HEX =
        \\:10246200464C5549442050524F46494C4500464C33
        \\:00000001FF
    ;
    var DATA = [_]u8{0} ** (0x2462 + 0x10);
    _ = try std.fmt.hexToBytes(DATA[0x2462..], "464C5549442050524F46494C4500464C");
    var output = [_]u8{0} ** DATA.len;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    _ = try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}

test "ExtendedSegmentAddress" {
    const HEX =
        \\:020000021200EA
        \\:100130003F0156702B5E712B722B732146013421C7
        \\:00000001FF
    ;
    const ADDRESS = (0x1200 * 16) + 0x0130;
    var DATA = [_]u8{0} ** (ADDRESS + 0x10);
    _ = try std.fmt.hexToBytes(DATA[ADDRESS..], "3F0156702B5E712B722B732146013421");
    var output = [_]u8{0} ** DATA.len;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    _ = try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}

test "StartSegmentAddress" {
    const HEX =
        \\:0400000300003800C1
        \\:00000001FF
    ;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    const addresses = try read(reader, &[_]u8{});
    try std.testing.expect(addresses.segment != null);
    try std.testing.expectEqual(0x0000, addresses.segment.?.code_segment);
    try std.testing.expectEqual(0x3800, addresses.segment.?.instruction_pointer);
}

test "ExtendedLineraAddress" {
    const HEX =
        \\:020000040001F9
        \\:100130003F0156702B5E712B722B732146013421C7
        \\:00000001FF
    ;
    // Uses ~65KiB of memory
    const ADDRESS = (0x0001 << 16) + 0x0130;
    var DATA = [_]u8{0} ** (ADDRESS + 0x10);
    _ = try std.fmt.hexToBytes(DATA[ADDRESS..], "3F0156702B5E712B722B732146013421");
    var output = [_]u8{0} ** DATA.len;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    _ = try read(reader, output[0..]);
    try std.testing.expectEqualSlices(u8, &DATA, &output);
}

test "StartLinearAddress" {
    const HEX =
        \\:04000005000000CD2A
        \\:00000001FF
    ;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    const addresses = try read(reader, &[_]u8{});
    try std.testing.expect(addresses.linear != null);
    try std.testing.expectEqual(0x000000CD, addresses.linear.?);
}

test "functional test" {
    const HEX = @embedFile("./tests/6502_functional_test.hex");
    // Binary file starts at 0x000A
    const BIN = @embedFile("./tests/6502_functional_test.bin");
    // Binary file is filled with 0xFF for untouched bytes
    var output = [_]u8{0xFF} ** 0x10000;
    var stream = std.io.fixedBufferStream(HEX);
    const reader = stream.reader();

    const addresses = try read(reader, output[0..]);

    try std.testing.expectEqualSlices(u8, BIN, output[0x000A..]);
    try std.testing.expectEqual(0x0400, addresses.eof);
}
