const std = @import("std");

const upperTable = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const lowerTable = "abcdefghijklmnopqrstuvwxyz";
const nullValue = '=';
const numberTable = "0123456789";
const symbolTable = "+/";
const base64Table = upperTable ++ lowerTable ++ numberTable ++ symbolTable;

pub const EncodeError = error{
    InputOverMaxSize,
};

pub const Base64 = struct {
    fn outputU6Amount(bytes: []const u8) !usize {
        return (try std.math.divCeil(usize, bytes.len, 3)) * 4;
    }

    pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
        const numSets: usize = try Base64.outputU6Amount(bytes);
        const output: []u8 = try allocator.alloc(u8, numSets);

        // Grab the sets
        var destination = [_]u8{ 0, 0, 0 };
        var stream = std.io.fixedBufferStream(bytes);

        var head: usize = 0;
        var bytesRead = try stream.read(&destination);
        var missingBytes: usize = 0;
        while (bytesRead != 0) : (bytesRead = try stream.read(&destination)) {
            var window: u24 = 0;
            for (destination, 0..) |byte, i| {
                if (i != 0) window <<= 8;

                window |= byte;

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
};

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
    const output = try Base64.encode(allocator, &testBytes);
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
    const output = try Base64.encode(allocator, &testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "encoding multiple packs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "Hi";
    const expected = "SGk=";
    const output = try Base64.encode(allocator, testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "encoding large string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "foobar the great";
    const expected = "Zm9vYmFyIHRoZSBncmVhdG==";

    const output = try Base64.encode(allocator, testBytes);
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "encoding empty string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testBytes = "";
    const expected = "";

    const output = try Base64.encode(allocator, testBytes);
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

// 1000 0000 0000 0000 0
