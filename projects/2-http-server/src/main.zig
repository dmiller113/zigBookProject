const defaultAddress = "0.0.0.0";
const defaultPort = "6969";

pub fn main() !void {
    const stdoutFile = std.io.getStdOut().writer();
    var bufferedWriter = std.io.bufferedWriter(stdoutFile);
    const stdout = bufferedWriter.writer();

    var requestBuffer = [_]u8{0} ** 1000;

    // init server with that address + port
    var serverBuilder = httpServer.init();
    var server = try serverBuilder.setHostname(defaultAddress).setPort(defaultPort).create();
    try server.bind();
    defer server.close();

    // listen with that server
    try server.listen();
    // endless loop, soon(tm)
    while (true) {
        const connection = try server.accept();
        const stream = connection.stream;
        defer stream.close();

        // print out any request received
        _ = try stream.read(&requestBuffer);
        try stdout.print("{s}", .{requestBuffer});
        try bufferedWriter.flush();

        // Send Response
        const okResponseMessage =
            \\HTTP/1.1 200 OK
            \\
            \\<html><head><title>Hello</title></head><body><h1>HI</h1></body></html>
        ;
        const connectionFile = stream.writer();
        var bufferedConnectionWriter = std.io.bufferedWriter(connectionFile);
        _ = try bufferedConnectionWriter.write(okResponseMessage);
        try bufferedConnectionWriter.flush();
    }
}

const std = @import("std");
const httpServer = @import("http-server");
