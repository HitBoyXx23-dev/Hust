module runtime.windows

# Windows x64 runtime contract used by Hust native programs.
# Network syscalls are surfaced through Hust's `net` module rather than exposed
# directly to application code.
extern "kernel32" fn ExitProcess(code: u32) -> never
extern "ws2_32" fn WSAStartup(version: u16, data: ptr) -> int
extern "ws2_32" fn socket(af: int, socket_type: int, protocol: int) -> socket
extern "ws2_32" fn bind(s: socket, address: ptr, length: int) -> int
extern "ws2_32" fn recv(s: socket, buffer: ptr, length: int, flags: int) -> int
extern "ws2_32" fn send(s: socket, buffer: ptr, length: int, flags: int) -> int
extern "ws2_32" fn recvfrom(s: socket, buffer: ptr, length: int, flags: int, from: ptr, from_len: ptr) -> int
extern "ws2_32" fn sendto(s: socket, buffer: ptr, length: int, flags: int, to: ptr, to_len: int) -> int
