const std = @import("std");

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
    return;
}

// Window: 011000 100110 000101 101111
//         011000 100110 000101 101111
