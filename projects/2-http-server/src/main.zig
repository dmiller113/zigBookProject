const defaultAddress = "0.0.0.0";
const defaultPort = "6969";

pub fn main() !void {
    const stdoutFile = std.io.getStdOut().writer();
    var buffered_writer = std.io.bufferedWriter(stdoutFile);
    const stdout = buffered_writer.writer();

    var request_buffer = [_]u8{0} ** 1000;
    var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(&request_buffer);
    const allocator = fixed_buffer_allocator.allocator();

    // init server with that address + port
    var serverBuilder = httpServer.init();
    var server = try serverBuilder.setHostname(defaultAddress).setPort(defaultPort).create();
    try server.bind();
    defer server.close();

    try stdout.print("\nListening on: {s}:{s}\n", .{ defaultAddress, defaultPort });
    try buffered_writer.flush();

    // listen with that server
    try server.listen();
    // endless loop, soon(tm)
    while (true) {
        const connection = try server.accept();
        var stream = connection.stream;
        defer stream.close();

        // print out any request received
        try httpServer.Request.fromStream(allocator, &stream);
        // _ = try stream.read(&request_buffer);
        // try stdout.print("{s}", .{request_buffer});

        // Send Response
        const ok_response_message =
            \\HTTP/1.1 200 OK
            \\
            \\<html><head><title>Hello</title></head><body><h1>HI</h1></body></html>
        ;
        const connection_file = stream.writer();
        var buffered_connection_writer = std.io.bufferedWriter(connection_file);
        _ = try buffered_connection_writer.write(ok_response_message);
        try buffered_connection_writer.flush();
    }
}

const std = @import("std");
const httpServer = @import("http-server");
