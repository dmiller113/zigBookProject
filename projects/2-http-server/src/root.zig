//! Steps for the project:
//! 1. Create a TCP socket object.
//! 2. Bind a name (or more specifically, an address) to this socket object.
//! ^--------- combine into a socket struct's init() method.
//! 3. Make this socket object to start listening and waiting for incoming connections.
//! ^--------- bind(socket) method
//! 4. When a connection arrive, we accept this connection, and we exchange the HTTP messages (HTTP Request and HTTP Response).
//! 5. Then, we simply close this connection.
//! ^--------- register callbacks perhaps?

pub const HttpServerError = error{
    ClosedSocket,
    MissingHostname,
    MissingPort,
};

pub fn init() HttpServerBuilder {
    return HttpServerBuilder{
        .hostname = null,
        .port = null,
    };
}

const HttpServerBuilder = struct {
    hostname: ?[]const u8,
    port: ?[]const u8,

    pub fn setHostname(self: *HttpServerBuilder, hostname: []const u8) *HttpServerBuilder {
        self.hostname = hostname;
        return self;
    }

    pub fn setPort(self: *HttpServerBuilder, port: []const u8) *HttpServerBuilder {
        self.port = port;
        return self;
    }

    pub fn create(self: *HttpServerBuilder) !HttpServer {
        const parsedPort = if (self.port) |port| try fmt.parseInt(u16, port, 10) else return HttpServerError.MissingPort;
        const address = if (self.hostname) |hostname| try Address.parseIp4(hostname, parsedPort) else return HttpServerError.MissingHostname;
        const socket = try posix.socket(address.any.family, SOCK_STREAM | SOCK_CLOSE_ON_EXEC, TCP);

        return HttpServer{
            .address = address,
            .fd = socket,
            .isClosed = false,
        };
    }
};

const HttpServer = struct {
    address: Address,
    fd: posix.socket_t,
    isClosed: bool,

    pub fn accept(self: *HttpServer) !net.Server.Connection {
        var acceptedAddress: Address = undefined;
        var addressLength: posix.socklen_t = @sizeOf(Address);
        // socketT contains the descriptor of the new socket returned by
        // address, and the passed address, acceptedAddress, is filled
        // with the connecting peer socket
        const socketT = try posix.accept(self.fd, &acceptedAddress.any, &addressLength, SOCK_CLOSE_ON_EXEC);

        return .{
            .stream = net.Stream{ .handle = socketT },
            .address = acceptedAddress,
        };
    }

    pub fn bind(self: *HttpServer) !void {
        errdefer self.close();
        try posix.bind(self.fd, &self.address.any, self.address.getOsSockLen());
    }

    pub fn close(self: *HttpServer) void {
        if (self.isClosed) {
            return;
        }

        posix.close(self.fd);
        self.isClosed = true;
    }

    pub fn listen(self: *HttpServer) !void {
        errdefer self.close();
        const defaultOptions = net.Address.ListenOptions{};

        try posix.listen(self.fd, defaultOptions.kernel_backlog);
    }
};

const std = @import("std");
const fmt = std.fmt;
const net = std.net;
const posix = std.posix;
// const testing = std.testing;
const Address = net.Address;
const PF_INET = std.c.PF.INET;
const SOCK_CLOSE_ON_EXEC = posix.SOCK.CLOEXEC;
const SOCK_STREAM = posix.SOCK.STREAM;
const TCP = posix.IPPROTO.TCP;
