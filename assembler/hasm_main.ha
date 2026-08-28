; HAsm Stage-0 source design
section data
version db "HAsm 0.1.0", 13, 10, 0

section code
export start
fn start
    ; Stage-0 responsibilities:
    ; - read UTF-8 .ha input
    ; - tokenize labels/opcodes/registers/immediates/memory operands
    ; - encode initial x86-64 instruction table
    ; - emit .hobj and PE32+
    ; - resolve kernel32 imports
    xor rcx, rcx
    call kernel32.ExitProcess
end
