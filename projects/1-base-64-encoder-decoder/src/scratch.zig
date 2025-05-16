const std = @import("std");

const encodeTable = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const decodeStringMap = std.StaticStringMap(usize).initComptime(
    blk: {
        var temp: [encodeTable.len]struct { []const u8, usize } = undefined;

        for (encodeTable, 0..) |byte, i| {
            temp[i] = .{ &[1]u8{byte}, i };
        }

        // Deal with comptime + global issue
        const output = temp;
        break :blk &output;
    },
);

pub fn main() !void {
    var dest = [_]u8{ 0, 0, 0 };
    const source = "Fooba";

    var buffer = std.io.fixedBufferStream(source);
    var bytesRead = try buffer.read(&dest);

    std.debug.print("Bytes read {d} for {s}\n", .{ bytesRead, dest });

    bytesRead = try buffer.read(&dest);
    std.debug.print("Bytes read {d} for {s}\n\n", .{ bytesRead, dest });

    bytesRead = try buffer.read(&dest);
    std.debug.print("Bytes read {d} for {s}\n\n", .{ bytesRead, dest });

    const fooo = "1" ** 0;
    std.debug.print("foo {s}", .{fooo});
    //
    //    var window: u24 = 0;
    //    for (dest, 0..) |byte, i| {
    //        if (i != 0) window <<= 8;
    //        window |= byte;
    //    }
    //
    //    std.debug.print("Window: {b:0>24}\n", .{window});
    //
    //    var i: usize = 4;
    //    while (i > 0) {
    //        i -= 1;
    //        const foo: u6 = std.math.lossyCast(u6, (window >> std.math.lossyCast(u5, i * 6)) & 0b111111);
    //        std.debug.print("{b:0>6}\n", .{foo});
    //    }
    //

    const encodedChar: u8 = 'Z';
    // const decodedChar = switch (encodedChar) {
    //     '+' => 62,
    //     '/' => 63,
    //     'A'...'Z' => (encodedChar - 'A'),
    //     'a'...'z' => (encodedChar - 'a') + 26,
    //     '0'...'9' => (encodedChar - '0') + 52,
    //     else => unreachable,
    // };

    const decodedChar = decodeStringMap.get(&[_]u8{encodedChar}).?;

    std.debug.print("decode {d}\n", .{decodedChar});
    const firstArray = "Foobar";
    const firstSlice = firstArray[0 .. firstArray.len - 2];
    const secondSlice = firstSlice[0 .. firstSlice.len - 1];

    for (secondSlice) |item| {
        std.debug.print("{c}\n", .{item});
    }

    return;
}

// inline fn makeInit(comptime encodeValues: []const u8) []struct { []const u8, usize }
// Window: 011000 100110 000101 101111
//         011000 100110 000101 101111
