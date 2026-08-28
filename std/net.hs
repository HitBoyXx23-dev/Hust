module net

struct SocketAddress
    family: int
    ip: string
    port: u16
end

struct TcpListener
    handle: socket
end

struct TcpStream
    handle: socket
end

struct UdpSocket
    handle: socket

    static fn bind(address: string, port: u16) -> result<UdpSocket, NetworkError>
        return platform.net.udp_bind(address, port)
    end

    async fn recv_from_or_cancel(buffer: ref bytes, cancel: CancelToken) -> optional<UdpDatagram>
        return await platform.net.udp_recv_from(handle, buffer, cancel)
    end

    async fn send_to(data: bytes, address: SocketAddress) -> result<int, NetworkError>
        return await platform.net.udp_send_to(handle, data, address)
    end
end

struct UdpDatagram
    address: SocketAddress
    length: int
end
