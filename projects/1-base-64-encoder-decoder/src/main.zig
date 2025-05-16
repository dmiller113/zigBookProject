const std = @import("std");
const Base64 = @import("base64.zig");

pub fn main() !void {
    // Allocator business
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    // Grab stdout
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Actually do things
    const testValue = "Testing some more stuff";
    const encodedValue = try Base64.encode(allocator, testValue);
    defer allocator.free(encodedValue);

    const decodedValue = try Base64.decode(allocator, encodedValue);
    defer allocator.free(decodedValue);

    try stdout.print(
        "Base String {s}\nEncoded String {s}\nDecoded String {s}\n",
        .{ testValue, encodedValue, decodedValue },
    );

    try bw.flush(); // Don't forget to flush!
}
