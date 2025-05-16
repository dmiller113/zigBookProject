const std = @import("std");

const upperTable = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const lowerTable = "abcdefghijklmnopqrstuvwxyz";
const nullValue = '=';
const numberTable = "0123456789";
const symbolTable = "+/";
const base64Table = upperTable ++ lowerTable ++ numberTable ++ symbolTable;
const base64DecodeMap = std.StaticStringMap(usize).initComptime(
    blk: {
        var temp: [base64Table.len]struct { []const u8, usize } = undefined;

        for (base64Table, 0..) |byte, i| {
            temp[i] = .{ &[1]u8{byte}, i };
        }

        // Deal with comptime + global issue
        const output = temp;
        break :blk &output;
    },
);

fn outputU6Amount(bytes: []const u8) !usize {
    return (try std.math.divCeil(usize, bytes.len, 3)) * 4;
}

pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    // could waste up to 2 values due to = packing
    const baseNumSets: usize = (try std.math.divFloor(usize, bytes.len, 4) * 3);
    const baseOutput: []u8 = try allocator.alloc(u8, baseNumSets);
    defer allocator.free(baseOutput);

    // Grab the packets
    var destination = [_]u8{ 0, 0, 0, 0 };
    var stream = std.io.fixedBufferStream(bytes);
    var paddingRead: usize = 0;

    // Needed because we need to skip the while if an empty read;
    var head: usize = 0;
    var bytesRead: usize = try stream.read(&destination);
    while (bytesRead != 0) : (bytesRead = try stream.read(&destination)) {

        // Move buffer into 24 bit window
        var window: u24 = 0;
        for (destination, 0..) |byte, i| {
            if (i != 0) window <<= 6;
            // Ignore padding
            if (byte == nullValue) {
                paddingRead += 1;
                continue;
            }

            const decodedByte = std.math.lossyCast(u6, base64DecodeMap.get(&[1]u8{byte}).?);
            window |= decodedByte;
        }

        // Divide the window into 3 u8 bytes
        var windowIndex: usize = 3;
        while (windowIndex > 0) {
            windowIndex -= 1;
            baseOutput[head + (2 - windowIndex)] = std.math.lossyCast(u8, (window >> std.math.lossyCast(u5, 8 * windowIndex)) & 0b11111111);
        }

        head += 3;
    }

    // TODO: Find way to avoid this
    const output = try allocator.alloc(u8, baseNumSets - paddingRead);
    for (output, 0..) |_, i| {
        output[i] = baseOutput[i];
    }

    return output;
}

pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const numSets: usize = try outputU6Amount(bytes);
    const output: []u8 = try allocator.alloc(u8, numSets);

    // Grab the packets
    var destination = [_]u8{ 0, 0, 0 };
    var stream = std.io.fixedBufferStream(bytes);

    var head: usize = 0;
    var bytesRead = try stream.read(&destination);
    var missingBytes: usize = 0;
    while (bytesRead != 0) : (bytesRead = try stream.read(&destination)) {
        var window: u24 = 0;
        for (destination, 0..) |byte, i| {
            if (i != 0) window <<= 8;

            // Don't use prior read bytes
            if (i < bytesRead) window |= byte;

            // Capture Padding
            missingBytes = @max(3 - bytesRead, 0);
        }

        var windowIndex: usize = 4;
        while (windowIndex > 0) {
            windowIndex -= 1;
            const bitsToEncode: u6 = std.math.lossyCast(u6, (window >> std.math.lossyCast(u5, windowIndex * 6)) & 0b111111);

            output[head + (3 - windowIndex)] = base64Table[bitsToEncode];
        }

        head += 4;
    }

    // Handle padding
    var outputIndex: usize = output.len - missingBytes;
    while (outputIndex < output.len) : (outputIndex += 1) {
        output[outputIndex] = nullValue;
    }

    return output;
}

// test "output sizing" {
//    const bytes = "fo";
// }

// 00000001
// 000000 010000 000000 000000
// AQ==

test "encoding single pack no padding" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = [3]u8{ 0xFF, 0xFF, 0xFF };
    const expected = "////";
    const output = try encode(allocator, &testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "encoding single pack with padding" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = [1]u8{0x01};
    // 0000 0001 XXXX XXXX XXXX XXXX
    // 000000 01XXXX XXXXXX XXXXXX
    const expected = "AQ==";
    const output = try encode(allocator, &testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "encoding multiple packs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "Hi";
    const expected = "SGk=";
    const output = try encode(allocator, testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "encoding large string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "foobar the great";
    const expected = "Zm9vYmFyIHRoZSBncmVhdA==";

    const output = try encode(allocator, testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "encoding empty string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "";
    const expected = "";

    const output = try encode(allocator, testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "decode empty string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "";
    const expected = "";

    const output = try decode(allocator, testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "decode simple encoding" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "AQ==";
    const expected = &[1]u8{0x01};

    const output = try decode(allocator, testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "byte encoding" {
    const upperCByte = 0b000011;
    const lowerByte = 0b100000;
    const symbol = @as(u6, 62);
    const number = @as(u6, 52);

    try std.testing.expectEqual('D', base64Table[upperCByte]);
    try std.testing.expectEqual('g', base64Table[lowerByte]);
    try std.testing.expectEqual('+', base64Table[symbol]);
    try std.testing.expectEqual('0', base64Table[number]);
}

test "Reversibility single byte" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = &[1]u8{0x01};

    const encoded = try encode(allocator, testBytes);
    defer allocator.free(encoded);

    const decoded = try decode(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(testBytes, decoded);
}

test "Reversibility of string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "foobar the great";

    const encoded = try encode(allocator, testBytes);
    defer allocator.free(encoded);

    const decoded = try decode(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(testBytes, decoded);
}

test "Padding" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const expected = "QzNWwQ==";
    const testBytes = &[_]u8{ 0x43, 0x33, 0x56, 0xc1 };

    const encoded = try encode(allocator, testBytes);
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected, encoded);
}

// 1000 0000 0000 0000 0
