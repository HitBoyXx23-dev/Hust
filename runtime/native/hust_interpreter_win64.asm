.intel_syntax noprefix

# Hust native interpreter backend - Windows x64.
#
# User-facing executable: HustInterpreter.exe
# Canonical high-level behavior: interpreter/main.hs, interpreter/evaluator.hs
# and compiler/rust2hust/*.hs
#
# Imports are ordinary KERNEL32 console, file and heap APIs only. No Winsock,
# WinHTTP, ShellExecute, CreateProcess, VirtualProtect or dynamic code loading.

.text
.globl _start
.globl write_out
.globl h_heap
.extern __imp_GetStdHandle
.extern __imp_WriteFile
.extern __imp_ReadFile
.extern __imp_CreateFileA
.extern __imp_GetFileSize
.extern __imp_CloseHandle
.extern __imp_GetCommandLineA
.extern __imp_GetProcessHeap
.extern __imp_HeapAlloc
.extern __imp_HeapFree
.extern __imp_CreateDirectoryA
.extern __imp_FindFirstFileA
.extern __imp_FindNextFileA
.extern __imp_FindClose
.extern __imp_ExitProcess

.extern r2h_convert
.extern hi_run_source
.extern r2h_stat_reset
.extern r2h_stat_lifetime
.extern r2h_stat_where
.extern r2h_stat_macro
.extern r2h_stat_iflet
.extern r2h_stat_closure
.extern r2h_stat_unsafe

.equ STD_OUTPUT_HANDLE, -11
.equ STD_INPUT_HANDLE, -10
.equ GENERIC_READ, 0x80000000
.equ GENERIC_WRITE, 0x40000000
.equ FILE_SHARE_READ, 1
.equ OPEN_EXISTING, 3
.equ CREATE_ALWAYS, 2
.equ FILE_ATTRIBUTE_NORMAL, 0x80
.equ FILE_ATTRIBUTE_DIRECTORY, 0x10
.equ HEAP_ZERO_MEMORY, 8

_start:
    sub rsp, 88

    mov ecx, STD_OUTPUT_HANDLE
    call qword ptr [rip + __imp_GetStdHandle]
    mov qword ptr [rip + h_stdout], rax
    mov ecx, STD_INPUT_HANDLE
    call qword ptr [rip + __imp_GetStdHandle]
    mov qword ptr [rip + h_stdin], rax
    call qword ptr [rip + __imp_GetProcessHeap]
    mov qword ptr [rip + h_heap], rax

    call qword ptr [rip + __imp_GetCommandLineA]
    mov rcx, rax
    call parse_command_line

    mov rax, qword ptr [rip + argc]
    cmp rax, 1
    jbe main_repl

    mov rcx, 1
    call get_arg_ptr
    mov rbx, rax

    lea rcx, [rip + opt_version_long]
    mov rdx, rbx
    call streq
    test eax, eax
    jnz main_version
    lea rcx, [rip + opt_version_short]
    mov rdx, rbx
    call streq
    test eax, eax
    jnz main_version

    lea rcx, [rip + opt_help_long]
    mov rdx, rbx
    call streq
    test eax, eax
    jnz main_help
    lea rcx, [rip + opt_help_short]
    mov rdx, rbx
    call streq
    test eax, eax
    jnz main_help

    lea rcx, [rip + opt_convert]
    mov rdx, rbx
    call streq
    test eax, eax
    jnz main_convert_file

    lea rcx, [rip + opt_convert_dir]
    mov rdx, rbx
    call streq
    test eax, eax
    jnz main_convert_dir

    mov rcx, rbx
    call run_script_file
    jmp main_exit_code

main_version:
    lea rcx, [rip + msg_version]
    call print_cstr
    xor eax, eax
    jmp main_exit_code

main_help:
    lea rcx, [rip + msg_help]
    call print_cstr
    xor eax, eax
    jmp main_exit_code

main_convert_file:
    mov rax, qword ptr [rip + argc]
    cmp rax, 4
    jb main_convert_usage
    call r2h_stat_reset
    mov rcx, 2
    call get_arg_ptr
    mov r12, rax
    mov rcx, 3
    call get_arg_ptr
    mov r13, rax
    mov rcx, r12
    mov rdx, r13
    call convert_one_file
    test eax, eax
    jnz main_convert_failed
    lea rcx, [rip + msg_converted]
    call print_cstr
    mov rcx, r13
    call print_cstr
    call print_nl
    call print_stats
    xor eax, eax
    jmp main_exit_code
main_convert_failed:
    mov eax, 1
    jmp main_exit_code
main_convert_usage:
    lea rcx, [rip + msg_convert_usage]
    call print_cstr
    mov eax, 2
    jmp main_exit_code

main_convert_dir:
    mov rax, qword ptr [rip + argc]
    cmp rax, 4
    jb main_convert_usage
    call r2h_stat_reset
    mov qword ptr [rip + files_ok], 0
    mov qword ptr [rip + files_failed], 0
    mov rcx, 2
    call get_arg_ptr
    mov r12, rax
    mov rcx, 3
    call get_arg_ptr
    mov r13, rax
    mov rcx, r13
    call make_dir
    mov rcx, r12
    mov rdx, r13
    call convert_tree
    lea rcx, [rip + msg_files_converted]
    call print_cstr
    mov rcx, qword ptr [rip + files_ok]
    call print_uint
    lea rcx, [rip + msg_files_failed]
    call print_cstr
    mov rcx, qword ptr [rip + files_failed]
    call print_uint
    call print_nl
    call print_stats
    xor eax, eax
    jmp main_exit_code

main_repl:
    call repl_loop
    xor eax, eax

main_exit_code:
    mov ecx, eax
    call qword ptr [rip + __imp_ExitProcess]

# ---------------------------------------------------------------- console

print_cstr:
    push r12
    push r13
    sub rsp, 40
    mov r12, rcx
    xor r13, r13
pc_len:
    cmp byte ptr [r12 + r13], 0
    je pc_write
    inc r13
    jmp pc_len
pc_write:
    mov rcx, r12
    mov rdx, r13
    call write_out
    add rsp, 40
    pop r13
    pop r12
    ret

write_out:
    sub rsp, 56
    mov r8, rdx
    mov rdx, rcx
    mov rcx, qword ptr [rip + h_stdout]
    lea r9, [rip + io_written]
    mov qword ptr [rsp + 32], 0
    call qword ptr [rip + __imp_WriteFile]
    add rsp, 56
    ret

print_nl:
    lea rcx, [rip + str_nl]
    call print_cstr
    ret

print_uint:
    mov rax, rcx
    lea r8, [rip + num_buf]
    mov r9, 32
    mov byte ptr [r8 + r9], 0
    mov r10, 10
pu_loop:
    xor edx, edx
    div r10
    add dl, '0'
    dec r9
    mov byte ptr [r8 + r9], dl
    test rax, rax
    jnz pu_loop
    lea rcx, [r8 + r9]
    call print_cstr
    ret

print_stats:
    lea rcx, [rip + msg_stat_head]
    call print_cstr
    lea rcx, [rip + msg_stat_lifetimes]
    call print_cstr
    mov rcx, qword ptr [rip + r2h_stat_lifetime]
    call print_uint
    lea rcx, [rip + msg_stat_where]
    call print_cstr
    mov rcx, qword ptr [rip + r2h_stat_where]
    call print_uint
    lea rcx, [rip + msg_stat_macro]
    call print_cstr
    mov rcx, qword ptr [rip + r2h_stat_macro]
    call print_uint
    lea rcx, [rip + msg_stat_iflet]
    call print_cstr
    mov rcx, qword ptr [rip + r2h_stat_iflet]
    call print_uint
    lea rcx, [rip + msg_stat_closure]
    call print_cstr
    mov rcx, qword ptr [rip + r2h_stat_closure]
    call print_uint
    lea rcx, [rip + msg_stat_unsafe]
    call print_cstr
    mov rcx, qword ptr [rip + r2h_stat_unsafe]
    call print_uint
    call print_nl
    ret

# ---------------------------------------------------------------- arguments

parse_command_line:
    push r12
    push r13
    push r14
    push r15
    mov r12, rcx
    mov qword ptr [rip + argc], 0
    lea r14, [rip + arg_buf]
    xor r15, r15
pcl_next:
    mov al, byte ptr [r12]
    test al, al
    jz pcl_done
    cmp al, ' '
    jne pcl_token
    inc r12
    jmp pcl_next
pcl_token:
    mov rax, qword ptr [rip + argc]
    cmp rax, 32
    jae pcl_done
    lea rcx, [rip + arg_table]
    lea rdx, [r14 + r15]
    mov qword ptr [rcx + rax * 8], rdx
    inc rax
    mov qword ptr [rip + argc], rax
    mov al, byte ptr [r12]
    cmp al, '"'
    je pcl_quoted
pcl_plain:
    mov al, byte ptr [r12]
    test al, al
    jz pcl_end_token
    cmp al, ' '
    je pcl_end_token
    mov byte ptr [r14 + r15], al
    inc r15
    inc r12
    jmp pcl_plain
pcl_quoted:
    inc r12
pcl_q_loop:
    mov al, byte ptr [r12]
    test al, al
    jz pcl_end_token
    cmp al, '"'
    je pcl_q_end
    mov byte ptr [r14 + r15], al
    inc r15
    inc r12
    jmp pcl_q_loop
pcl_q_end:
    inc r12
pcl_end_token:
    mov byte ptr [r14 + r15], 0
    inc r15
    jmp pcl_next
pcl_done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

get_arg_ptr:
    lea rax, [rip + arg_table]
    mov rax, qword ptr [rax + rcx * 8]
    ret

streq:
    xor r10, r10
se_loop:
    mov al, byte ptr [rcx + r10]
    mov r11b, byte ptr [rdx + r10]
    cmp al, r11b
    jne se_no
    test al, al
    jz se_yes
    inc r10
    jmp se_loop
se_yes:
    mov eax, 1
    ret
se_no:
    xor eax, eax
    ret

# ---------------------------------------------------------------- files

read_file:
    sub rsp, 72
    mov rdx, GENERIC_READ
    mov r8, FILE_SHARE_READ
    xor r9, r9
    mov qword ptr [rsp + 32], OPEN_EXISTING
    mov qword ptr [rsp + 40], FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp + 48], 0
    call qword ptr [rip + __imp_CreateFileA]
    cmp rax, -1
    je rf_fail
    mov qword ptr [rip + tmp_handle], rax
    mov rcx, rax
    xor rdx, rdx
    call qword ptr [rip + __imp_GetFileSize]
    mov qword ptr [rip + tmp_size], rax
    mov rcx, qword ptr [rip + h_heap]
    mov rdx, HEAP_ZERO_MEMORY
    mov r8, qword ptr [rip + tmp_size]
    add r8, 16
    call qword ptr [rip + __imp_HeapAlloc]
    test rax, rax
    jz rf_close_fail
    mov qword ptr [rip + tmp_buffer], rax
    mov rcx, qword ptr [rip + tmp_handle]
    mov rdx, rax
    mov r8, qword ptr [rip + tmp_size]
    lea r9, [rip + io_read]
    mov qword ptr [rsp + 32], 0
    call qword ptr [rip + __imp_ReadFile]
    mov rcx, qword ptr [rip + tmp_handle]
    call qword ptr [rip + __imp_CloseHandle]
    mov rax, qword ptr [rip + tmp_buffer]
    mov rdx, qword ptr [rip + io_read]
    add rsp, 72
    ret
rf_close_fail:
    mov rcx, qword ptr [rip + tmp_handle]
    call qword ptr [rip + __imp_CloseHandle]
rf_fail:
    xor rax, rax
    xor rdx, rdx
    add rsp, 72
    ret

write_file:
    sub rsp, 72
    mov qword ptr [rip + tmp_buffer], rdx
    mov qword ptr [rip + tmp_size], r8
    mov rdx, GENERIC_WRITE
    xor r8, r8
    xor r9, r9
    mov qword ptr [rsp + 32], CREATE_ALWAYS
    mov qword ptr [rsp + 40], FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp + 48], 0
    call qword ptr [rip + __imp_CreateFileA]
    cmp rax, -1
    je wf_fail
    mov qword ptr [rip + tmp_handle], rax
    mov rcx, rax
    mov rdx, qword ptr [rip + tmp_buffer]
    mov r8, qword ptr [rip + tmp_size]
    lea r9, [rip + io_written]
    mov qword ptr [rsp + 32], 0
    call qword ptr [rip + __imp_WriteFile]
    mov rcx, qword ptr [rip + tmp_handle]
    call qword ptr [rip + __imp_CloseHandle]
    xor eax, eax
    add rsp, 72
    ret
wf_fail:
    mov eax, 1
    add rsp, 72
    ret

make_dir:
    sub rsp, 40
    xor rdx, rdx
    call qword ptr [rip + __imp_CreateDirectoryA]
    add rsp, 40
    ret

convert_one_file:
    push rbx
    push rsi
    push rdi
    push r14
    sub rsp, 40
    mov rsi, rdx
    call read_file
    test rax, rax
    jz cof_fail_open
    mov rbx, rax
    mov rdi, rdx

    mov rcx, rdi
    shl rcx, 2
    add rcx, 262144
    mov qword ptr [rip + tmp_outcap], rcx
    mov rcx, qword ptr [rip + h_heap]
    xor rdx, rdx
    mov r8, qword ptr [rip + tmp_outcap]
    call qword ptr [rip + __imp_HeapAlloc]
    test rax, rax
    jz cof_fail_mem
    mov qword ptr [rip + tmp_out], rax

    mov rcx, rbx
    mov rdx, rdi
    mov r8, qword ptr [rip + tmp_out]
    mov r9, qword ptr [rip + tmp_outcap]
    call r2h_convert
    mov qword ptr [rip + tmp_outlen], rax

    mov rcx, rsi
    mov rdx, qword ptr [rip + tmp_out]
    mov r8, qword ptr [rip + tmp_outlen]
    call write_file
    mov r14d, eax

    mov rcx, qword ptr [rip + h_heap]
    xor rdx, rdx
    mov r8, qword ptr [rip + tmp_out]
    call qword ptr [rip + __imp_HeapFree]
    mov rcx, qword ptr [rip + h_heap]
    xor rdx, rdx
    mov r8, rbx
    call qword ptr [rip + __imp_HeapFree]

    mov eax, r14d
    add rsp, 40
    pop r14
    pop rdi
    pop rsi
    pop rbx
    ret
cof_fail_mem:
    mov rcx, qword ptr [rip + h_heap]
    xor rdx, rdx
    mov r8, rbx
    call qword ptr [rip + __imp_HeapFree]
cof_fail_open:
    mov eax, 1
    add rsp, 40
    pop r14
    pop rdi
    pop rsi
    pop rbx
    ret

path_join:
    xor r9, r9
    xor r10, r10
pj_a:
    mov al, byte ptr [rdx + r10]
    test al, al
    jz pj_sep
    mov byte ptr [rcx + r9], al
    inc r9
    inc r10
    jmp pj_a
pj_sep:
    mov byte ptr [rcx + r9], 92
    inc r9
    xor r10, r10
pj_b:
    mov al, byte ptr [r8 + r10]
    test al, al
    jz pj_end
    mov byte ptr [rcx + r9], al
    inc r9
    inc r10
    jmp pj_b
pj_end:
    mov byte ptr [rcx + r9], 0
    ret

ends_with_rs:
    xor r10, r10
ewr_len:
    cmp byte ptr [rcx + r10], 0
    je ewr_have
    inc r10
    jmp ewr_len
ewr_have:
    cmp r10, 3
    jb ewr_no
    mov al, byte ptr [rcx + r10 - 3]
    cmp al, '.'
    jne ewr_no
    mov al, byte ptr [rcx + r10 - 2]
    cmp al, 'r'
    jne ewr_no
    mov al, byte ptr [rcx + r10 - 1]
    cmp al, 's'
    jne ewr_no
    mov eax, 1
    ret
ewr_no:
    xor eax, eax
    ret

name_to_hs:
    xor r10, r10
nth_copy:
    mov al, byte ptr [rdx + r10]
    mov byte ptr [rcx + r10], al
    test al, al
    jz nth_fix
    inc r10
    jmp nth_copy
nth_fix:
    cmp r10, 3
    jb nth_done
    mov byte ptr [rcx + r10 - 2], 'h'
nth_done:
    ret

convert_tree:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 96

    mov rax, qword ptr [rip + walk_depth]
    cmp rax, 24
    jae ct_ret
    inc qword ptr [rip + walk_depth]

    mov rbx, qword ptr [rip + walk_top]
    mov r12, rbx
    imul r12, 4128
    lea rax, [rip + walk_arena]
    add rax, r12
    inc qword ptr [rip + walk_top]

    mov rdi, rax
    mov r13, rax
    add r13, 32
    mov r14, rax
    add r14, 1056
    mov r15, rax
    add r15, 2080

    mov qword ptr [rdi], rcx
    mov qword ptr [rdi + 8], rdx

    mov rcx, r13
    mov rdx, qword ptr [rdi]
    lea r8, [rip + star_pattern]
    call path_join

    sub rsp, 48
    mov rcx, r13
    lea rdx, [rip + find_data]
    call qword ptr [rip + __imp_FindFirstFileA]
    add rsp, 48
    cmp rax, -1
    je ct_restore
    mov qword ptr [rdi + 16], rax

ct_entry:
    lea rsi, [rip + find_data]
    add rsi, 44
    mov rcx, rdi
    add rcx, 3104
    mov rdx, rsi
    call copy_cstr
    mov rsi, rdi
    add rsi, 3104

    cmp byte ptr [rsi], '.'
    jne ct_real
    cmp byte ptr [rsi + 1], 0
    je ct_next
    cmp byte ptr [rsi + 1], '.'
    jne ct_real
    cmp byte ptr [rsi + 2], 0
    je ct_next

ct_real:
    lea rax, [rip + find_data]
    mov eax, dword ptr [rax]
    test eax, FILE_ATTRIBUTE_DIRECTORY
    jnz ct_dir

    mov rcx, rsi
    call ends_with_rs
    test eax, eax
    jz ct_next

    mov rcx, r14
    mov rdx, qword ptr [rdi]
    mov r8, rsi
    call path_join
    mov rcx, r15
    mov rdx, rsi
    call name_to_hs
    mov rcx, r13
    mov rdx, qword ptr [rdi + 8]
    mov r8, r15
    call path_join

    mov rcx, r14
    mov rdx, r13
    call convert_one_file
    test eax, eax
    jnz ct_file_bad
    inc qword ptr [rip + files_ok]
    jmp ct_next
ct_file_bad:
    inc qword ptr [rip + files_failed]
    jmp ct_next

ct_dir:
    mov rcx, r14
    mov rdx, qword ptr [rdi]
    mov r8, rsi
    call path_join
    mov rcx, r13
    mov rdx, qword ptr [rdi + 8]
    mov r8, rsi
    call path_join
    mov rcx, r13
    call make_dir
    mov rcx, r14
    mov rdx, r13
    call convert_tree

ct_next:
    sub rsp, 48
    mov rcx, qword ptr [rdi + 16]
    lea rdx, [rip + find_data]
    call qword ptr [rip + __imp_FindNextFileA]
    add rsp, 48
    test eax, eax
    jz ct_close
    jmp ct_entry

ct_close:
    sub rsp, 48
    mov rcx, qword ptr [rdi + 16]
    call qword ptr [rip + __imp_FindClose]
    add rsp, 48

ct_restore:
    dec qword ptr [rip + walk_depth]
    dec qword ptr [rip + walk_top]
ct_ret:
    add rsp, 96
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

copy_cstr:
    xor r10, r10
cc_loop:
    mov al, byte ptr [rdx + r10]
    mov byte ptr [rcx + r10], al
    test al, al
    jz cc_done
    inc r10
    cmp r10, 1000
    jb cc_loop
cc_done:
    ret

# ---------------------------------------------------------------- interpreter

run_script_file:
    push rbx
    push rsi
    push rdi
    sub rsp, 48
    mov rbx, rcx
    lea rcx, [rip + msg_running]
    call print_cstr
    mov rcx, rbx
    call print_cstr
    call print_nl
    mov rcx, rbx
    call read_file
    test rax, rax
    jz rsf_missing
    mov rsi, rax
    mov rdi, rdx
    mov qword ptr [rip + var_count], 0
    mov rcx, rsi
    mov rdx, rdi
    call hi_run_source
    xor eax, eax
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret
rsf_missing:
    lea rcx, [rip + msg_cannot_open]
    call print_cstr
    mov rcx, rbx
    call print_cstr
    call print_nl
    mov eax, 1
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret

eval_source:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 48
    mov rsi, rcx
    mov rdi, rdx
    xor rbx, rbx
    mov r12, 1
es_line:
    cmp rbx, rdi
    jae es_done
    lea rcx, [rip + line_store]
    xor r13, r13
es_copy:
    cmp rbx, rdi
    jae es_run
    mov al, byte ptr [rsi + rbx]
    inc rbx
    cmp al, 10
    je es_run
    cmp al, 13
    je es_copy
    cmp r13, 1000
    jae es_copy
    mov byte ptr [rcx + r13], al
    inc r13
    jmp es_copy
es_run:
    mov byte ptr [rcx + r13], 0
    mov rdx, r12
    call eval_line
    inc r12
    jmp es_line
es_done:
    add rsp, 48
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

eval_line:
    push rbx
    push rsi
    push rdi
    sub rsp, 48
    mov rbx, rcx
    mov rsi, rdx
el_skip_ws:
    mov al, byte ptr [rbx]
    cmp al, ' '
    je el_ws_next
    cmp al, 9
    je el_ws_next
    jmp el_check
el_ws_next:
    inc rbx
    jmp el_skip_ws
el_check:
    mov al, byte ptr [rbx]
    test al, al
    jz el_ok

    mov rcx, rbx
    lea rdx, [rip + kw_print]
    call starts_with
    test eax, eax
    jnz el_print

    mov rcx, rbx
    call is_structural
    test eax, eax
    jnz el_ok

    mov rcx, rbx
    call try_assignment
    test eax, eax
    jnz el_ok

    lea rcx, [rip + msg_unsupported]
    call print_cstr
    mov rcx, rsi
    call print_uint
    call print_nl
    jmp el_ok

el_print:
    mov rcx, rbx
    call do_print
el_ok:
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret

starts_with:
    xor r10, r10
sw_loop:
    mov al, byte ptr [rdx + r10]
    test al, al
    jz sw_yes
    mov r11b, byte ptr [rcx + r10]
    cmp al, r11b
    jne sw_no
    inc r10
    jmp sw_loop
sw_yes:
    mov eax, 1
    ret
sw_no:
    xor eax, eax
    ret

is_structural:
    push r12
    sub rsp, 32
    mov r12, rcx
    lea rdx, [rip + kw_fn]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    lea rdx, [rip + kw_end]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    lea rdx, [rip + kw_use]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    lea rdx, [rip + kw_module]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    lea rdx, [rip + kw_const]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    lea rdx, [rip + kw_struct]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    lea rdx, [rip + kw_return]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    lea rdx, [rip + kw_at]
    mov rcx, r12
    call starts_with
    test eax, eax
    jnz is_yes
    xor eax, eax
    add rsp, 32
    pop r12
    ret
is_yes:
    mov eax, 1
    add rsp, 32
    pop r12
    ret

do_print:
    push rbx
    push rsi
    push r14
    sub rsp, 48
    mov rbx, rcx
    add rbx, 5
    mov al, byte ptr [rbx]
    cmp al, '('
    jne dp_bare
    inc rbx
dp_bare:
    mov al, byte ptr [rbx]
    cmp al, ' '
    jne dp_start
    inc rbx
    jmp dp_bare
dp_start:
    mov al, byte ptr [rbx]
    cmp al, '"'
    jne dp_ident
    inc rbx
    mov qword ptr [rip + out_line_len], 0
dp_str:
    movzx eax, byte ptr [rbx]
    test al, al
    jz dp_emit
    cmp al, '"'
    je dp_emit
    cmp al, '{'
    je dp_interp
    mov rcx, rax
    call out_line_ch
    inc rbx
    jmp dp_str
dp_interp:
    inc rbx
    lea rsi, [rip + name_store]
    xor r14, r14
dp_name:
    mov al, byte ptr [rbx]
    test al, al
    jz dp_emit
    cmp al, '}'
    je dp_name_done
    cmp r14, 100
    jae dp_name_next
    mov byte ptr [rsi + r14], al
    inc r14
dp_name_next:
    inc rbx
    jmp dp_name
dp_name_done:
    inc rbx
    mov byte ptr [rsi + r14], 0
    mov rcx, rsi
    call lookup_var
    test rax, rax
    jz dp_str
    mov rcx, rax
    call out_line_cstr
    jmp dp_str
dp_emit:
    lea rcx, [rip + out_line]
    mov rdx, qword ptr [rip + out_line_len]
    call write_out
    call print_nl
    add rsp, 48
    pop r14
    pop rsi
    pop rbx
    ret
dp_ident:
    mov qword ptr [rip + out_line_len], 0
    lea rsi, [rip + name_store]
    xor r14, r14
dp_ident_copy:
    mov al, byte ptr [rbx]
    test al, al
    jz dp_ident_done
    cmp al, ')'
    je dp_ident_done
    cmp al, ' '
    je dp_ident_done
    cmp r14, 100
    jae dp_ident_next
    mov byte ptr [rsi + r14], al
    inc r14
dp_ident_next:
    inc rbx
    jmp dp_ident_copy
dp_ident_done:
    mov byte ptr [rsi + r14], 0
    mov rcx, rsi
    call lookup_var
    test rax, rax
    jz dp_ident_unknown
    mov rcx, rax
    call print_cstr
    call print_nl
    add rsp, 48
    pop r14
    pop rsi
    pop rbx
    ret
dp_ident_unknown:
    mov rcx, rsi
    call print_cstr
    call print_nl
    add rsp, 48
    pop r14
    pop rsi
    pop rbx
    ret

out_line_ch:
    mov r10, qword ptr [rip + out_line_len]
    cmp r10, 4000
    jae olc_done
    lea r11, [rip + out_line]
    mov byte ptr [r11 + r10], cl
    inc r10
    mov qword ptr [rip + out_line_len], r10
olc_done:
    ret

out_line_cstr:
    push r12
    push r13
    sub rsp, 40
    mov r12, rcx
    xor r13, r13
olcs_loop:
    mov cl, byte ptr [r12 + r13]
    test cl, cl
    jz olcs_done
    call out_line_ch
    inc r13
    jmp olcs_loop
olcs_done:
    add rsp, 40
    pop r13
    pop r12
    ret

try_assignment:
    push rbx
    sub rsp, 32
    mov rbx, rcx
    xor r10, r10
ta_find:
    mov al, byte ptr [rbx + r10]
    test al, al
    jz ta_no
    cmp al, '='
    je ta_have
    cmp al, '('
    je ta_no
    inc r10
    jmp ta_find
ta_have:
    test r10, r10
    jz ta_no
    mov r11, r10
ta_trim:
    test r11, r11
    jz ta_no
    mov al, byte ptr [rbx + r11 - 1]
    cmp al, ' '
    jne ta_name
    dec r11
    jmp ta_trim
ta_name:
    lea rcx, [rip + name_store]
    xor r8, r8
ta_copy_name:
    cmp r8, r11
    jae ta_name_done
    mov al, byte ptr [rbx + r8]
    mov byte ptr [rcx + r8], al
    inc r8
    jmp ta_copy_name
ta_name_done:
    mov byte ptr [rcx + r8], 0
    inc r10
ta_skip_sp:
    mov al, byte ptr [rbx + r10]
    cmp al, ' '
    jne ta_value
    inc r10
    jmp ta_skip_sp
ta_value:
    lea rdx, [rip + value_store]
    xor r8, r8
    mov al, byte ptr [rbx + r10]
    cmp al, '"'
    jne ta_raw
    inc r10
ta_str:
    mov al, byte ptr [rbx + r10]
    test al, al
    jz ta_store
    cmp al, '"'
    je ta_store
    mov byte ptr [rdx + r8], al
    inc r8
    inc r10
    jmp ta_str
ta_raw:
    mov al, byte ptr [rbx + r10]
    test al, al
    jz ta_store
    cmp al, '('
    je ta_no
    mov byte ptr [rdx + r8], al
    inc r8
    inc r10
    jmp ta_raw
ta_store:
    mov byte ptr [rdx + r8], 0
    lea rcx, [rip + name_store]
    lea rdx, [rip + value_store]
    call store_var
    mov eax, 1
    add rsp, 32
    pop rbx
    ret
ta_no:
    xor eax, eax
    add rsp, 32
    pop rbx
    ret

store_var:
    mov r8, qword ptr [rip + var_count]
    cmp r8, 64
    jae sv_done
    mov rax, r8
    imul rax, 128
    lea r9, [rip + var_names]
    add r9, rax
    xor r10, r10
sv_name:
    mov al, byte ptr [rcx + r10]
    mov byte ptr [r9 + r10], al
    test al, al
    jz sv_value
    inc r10
    cmp r10, 120
    jb sv_name
sv_value:
    mov rax, r8
    imul rax, 256
    lea r9, [rip + var_values]
    add r9, rax
    xor r10, r10
sv_copy:
    mov al, byte ptr [rdx + r10]
    mov byte ptr [r9 + r10], al
    test al, al
    jz sv_count
    inc r10
    cmp r10, 250
    jb sv_copy
sv_count:
    inc r8
    mov qword ptr [rip + var_count], r8
sv_done:
    ret

lookup_var:
    mov r8, qword ptr [rip + var_count]
    xor r9, r9
lv_loop:
    cmp r9, r8
    jae lv_none
    mov rax, r9
    imul rax, 128
    lea r10, [rip + var_names]
    add r10, rax
    xor r11, r11
lv_cmp:
    mov al, byte ptr [rcx + r11]
    cmp al, byte ptr [r10 + r11]
    jne lv_next
    test al, al
    jz lv_hit
    inc r11
    jmp lv_cmp
lv_next:
    inc r9
    jmp lv_loop
lv_hit:
    mov rax, r9
    imul rax, 256
    lea r10, [rip + var_values]
    add r10, rax
    mov rax, r10
    ret
lv_none:
    xor rax, rax
    ret

repl_loop:
    sub rsp, 40
    lea rcx, [rip + msg_version]
    call print_cstr
    lea rcx, [rip + msg_repl_banner]
    call print_cstr
    mov qword ptr [rip + var_count], 0
rl_loop:
    lea rcx, [rip + msg_prompt]
    call print_cstr
    call read_line
    test eax, eax
    jz rl_done
    lea rcx, [rip + line_store]
    lea rdx, [rip + kw_exit]
    call streq
    test eax, eax
    jnz rl_done
    lea rcx, [rip + line_store]
    lea rdx, [rip + kw_quit]
    call streq
    test eax, eax
    jnz rl_done
    lea rcx, [rip + line_store]
    mov rdx, 1
    call eval_line
    jmp rl_loop
rl_done:
    add rsp, 40
    ret

read_line:
    sub rsp, 56
    mov rcx, qword ptr [rip + h_stdin]
    lea rdx, [rip + read_buf]
    mov r8, 1024
    lea r9, [rip + io_read]
    mov qword ptr [rsp + 32], 0
    call qword ptr [rip + __imp_ReadFile]
    add rsp, 56
    test eax, eax
    jz rdl_none
    mov r8, qword ptr [rip + io_read]
    test r8, r8
    jz rdl_none
    lea r9, [rip + read_buf]
    lea r10, [rip + line_store]
    xor r11, r11
rdl_copy:
    cmp r11, r8
    jae rdl_end
    mov al, byte ptr [r9 + r11]
    cmp al, 10
    je rdl_end
    cmp al, 13
    je rdl_skip
    mov byte ptr [r10 + r11], al
rdl_skip:
    inc r11
    jmp rdl_copy
rdl_end:
    mov byte ptr [r10 + r11], 0
    mov eax, 1
    ret
rdl_none:
    xor eax, eax
    ret

# ---------------------------------------------------------------- data

.section .rodata
msg_version: .asciz "Hust Interpreter 0.8.25\r\n"
msg_repl_banner: .asciz "Native bootstrap REPL - no Python/Rust/.NET runtime. Type exit to leave.\r\n"
msg_prompt: .asciz "hust> "
msg_help: .asciz "Usage: HustInterpreter.exe <file.hs>\r\n       HustInterpreter.exe --convert-rust <input.rs> <output.hs>\r\n       HustInterpreter.exe --convert-rust-dir <input_dir> <output_dir>\r\n       HustInterpreter.exe            (REPL)\r\n"
msg_convert_usage: .asciz "Usage: HustInterpreter.exe --convert-rust <input.rs> <output.hs>\r\n       HustInterpreter.exe --convert-rust-dir <input_dir> <output_dir>\r\n"
msg_running: .asciz "[HustInterpreter] running "
msg_cannot_open: .asciz "[HustInterpreter] cannot open: "
msg_unsupported: .asciz "[HustInterpreter] unsupported statement at line "
msg_converted: .asciz "[rust2hust] wrote "
msg_files_converted: .asciz "[rust2hust] converted files: "
msg_files_failed: .asciz "  failed: "
msg_stat_head: .asciz "[rust2hust] review counters\r\n"
msg_stat_lifetimes: .asciz "  lifetimes dropped: "
msg_stat_where: .asciz "\r\n  where clauses dropped: "
msg_stat_macro: .asciz "\r\n  unmapped macros: "
msg_stat_iflet: .asciz "\r\n  pattern conditions: "
msg_stat_closure: .asciz "\r\n  closures kept verbatim: "
msg_stat_unsafe: .asciz "\r\n  unsafe blocks: "
str_nl: .asciz "\r\n"
star_pattern: .asciz "*"

opt_version_long: .asciz "--version"
opt_version_short: .asciz "-v"
opt_help_long: .asciz "--help"
opt_help_short: .asciz "-h"
opt_convert: .asciz "--convert-rust"
opt_convert_dir: .asciz "--convert-rust-dir"

kw_print: .asciz "print"
kw_fn: .asciz "fn "
kw_end: .asciz "end"
kw_use: .asciz "use "
kw_module: .asciz "module "
kw_const: .asciz "const "
kw_struct: .asciz "struct "
kw_return: .asciz "return"
kw_at: .asciz "@"
kw_exit: .asciz "exit"
kw_quit: .asciz "quit"

.bss
.align 8
h_stdout: .space 8
h_stdin: .space 8
h_heap: .space 8
io_written: .space 8
io_read: .space 8
argc: .space 8
arg_table: .space 256
tmp_handle: .space 8
tmp_size: .space 8
tmp_buffer: .space 8
tmp_out: .space 8
tmp_outcap: .space 8
tmp_outlen: .space 8
files_ok: .space 8
files_failed: .space 8
walk_depth: .space 8
walk_top: .space 8
var_count: .space 8
out_line_len: .space 8
num_buf: .space 64
arg_buf: .space 8192
line_store: .space 4096
read_buf: .space 4096
name_store: .space 256
value_store: .space 512
out_line: .space 4096
var_names: .space 8192
var_values: .space 16384
find_data: .space 640
walk_arena: .space 132096
