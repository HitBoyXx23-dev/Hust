.intel_syntax noprefix

# Hust interpreter core - Windows x64.
#
# Executes Hust source directly: functions, calls, recursion, integers, strings,
# string interpolation, if/else, while, arithmetic, comparison and logic.
# This is the piece that lets server logic live in .hs instead of in HAsm.
#
# Canonical high-level behavior: interpreter/evaluator.hs

.equ TOK_EOF, 0
.equ TOK_IDENT, 1
.equ TOK_NUM, 2
.equ TOK_STR, 3
.equ TOK_PUNCT, 4

.equ TAG_NONE, 0
.equ TAG_INT, 1
.equ TAG_STR, 2
.equ TAG_BOOL, 3

.equ MAX_TOKENS, 65536
.equ MAX_FUNCS, 256
.equ MAX_ENV, 1024
.equ ARENA_SIZE, 4194304

.text
.globl hi_run_source
.globl hi_error_count
.extern write_out
.extern h_heap
.extern __imp_HeapAlloc

# ---------------------------------------------------------------- entry

# RCX = source pointer, RDX = source length
hi_run_source:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov qword ptr [rip + src_ptr], rcx
    mov qword ptr [rip + src_len], rdx
    mov qword ptr [rip + src_pos], 0
    mov qword ptr [rip + tok_count], 0
    mov qword ptr [rip + func_count], 0
    mov qword ptr [rip + env_count], 0
    mov qword ptr [rip + frame_base], 0
    mov qword ptr [rip + hi_error_count], 0
    mov qword ptr [rip + arena_used], 0

    mov rcx, qword ptr [rip + h_heap]
    xor rdx, rdx
    mov r8, ARENA_SIZE
    call qword ptr [rip + __imp_HeapAlloc]
    mov qword ptr [rip + arena_ptr], rax

    call hi_lex
    call hi_prescan

    lea rcx, [rip + kw_main]
    mov rdx, 4
    call hi_find_func
    test rax, rax
    jz .hrs_toplevel
    mov qword ptr [rip + call_argc], 0
    mov rcx, rax
    call hi_call_function
    jmp .hrs_done

.hrs_toplevel:
    mov qword ptr [rip + tp], 0
    call hi_exec_block

.hrs_done:
    mov rax, qword ptr [rip + hi_error_count]
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

# ---------------------------------------------------------------- lexer

hi_lex:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
.hl_loop:
    call hi_skip_space
    mov r12, qword ptr [rip + src_pos]
    cmp r12, qword ptr [rip + src_len]
    jae .hl_done
    mov rsi, qword ptr [rip + src_ptr]
    movzx eax, byte ptr [rsi + r12]

    cmp eax, '#'
    je .hl_comment
    cmp eax, '"'
    je .hl_string
    cmp eax, '_'
    je .hl_ident
    cmp eax, 'a'
    jb .hl_upper
    cmp eax, 'z'
    jbe .hl_ident
.hl_upper:
    cmp eax, 'A'
    jb .hl_digit
    cmp eax, 'Z'
    jbe .hl_ident
.hl_digit:
    cmp eax, '0'
    jb .hl_punct
    cmp eax, '9'
    jbe .hl_number
    jmp .hl_punct

.hl_comment:
    mov r13, r12
.hl_comment_scan:
    cmp r13, qword ptr [rip + src_len]
    jae .hl_comment_end
    movzx eax, byte ptr [rsi + r13]
    cmp eax, 10
    je .hl_comment_end
    inc r13
    jmp .hl_comment_scan
.hl_comment_end:
    mov qword ptr [rip + src_pos], r13
    jmp .hl_loop

.hl_ident:
    mov r13, r12
.hl_ident_scan:
    cmp r13, qword ptr [rip + src_len]
    jae .hl_ident_end
    movzx eax, byte ptr [rsi + r13]
    call hi_is_ident_char
    test eax, eax
    jz .hl_ident_end
    inc r13
    jmp .hl_ident_scan
.hl_ident_end:
    mov ecx, TOK_IDENT
    call hi_push_token
    jmp .hl_loop

.hl_number:
    mov r13, r12
.hl_num_scan:
    cmp r13, qword ptr [rip + src_len]
    jae .hl_num_end
    movzx eax, byte ptr [rsi + r13]
    cmp eax, '0'
    jb .hl_num_end
    cmp eax, '9'
    ja .hl_num_end
    inc r13
    jmp .hl_num_scan
.hl_num_end:
    mov ecx, TOK_NUM
    call hi_push_token
    jmp .hl_loop

.hl_string:
    inc r12
    mov r13, r12
.hl_str_scan:
    cmp r13, qword ptr [rip + src_len]
    jae .hl_str_end
    movzx eax, byte ptr [rsi + r13]
    cmp eax, '"'
    je .hl_str_end
    inc r13
    jmp .hl_str_scan
.hl_str_end:
    mov ecx, TOK_STR
    call hi_push_token
    mov rax, qword ptr [rip + src_pos]
    inc rax
    mov qword ptr [rip + src_pos], rax
    jmp .hl_loop

.hl_punct:
    mov r13, r12
    inc r13
    movzx eax, byte ptr [rsi + r12]
    cmp eax, '='
    je .hl_maybe_two
    cmp eax, '!'
    je .hl_maybe_two
    cmp eax, '<'
    je .hl_maybe_two
    cmp eax, '>'
    je .hl_maybe_two
    jmp .hl_punct_emit
.hl_maybe_two:
    cmp r13, qword ptr [rip + src_len]
    jae .hl_punct_emit
    movzx eax, byte ptr [rsi + r13]
    cmp eax, '='
    jne .hl_punct_emit
    inc r13
.hl_punct_emit:
    mov ecx, TOK_PUNCT
    call hi_push_token
    jmp .hl_loop

.hl_done:
    mov ecx, TOK_EOF
    mov r12, qword ptr [rip + src_len]
    mov r13, r12
    call hi_push_token
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

hi_skip_space:
    push rsi
.hss_loop:
    mov rax, qword ptr [rip + src_pos]
    cmp rax, qword ptr [rip + src_len]
    jae .hss_done
    mov rsi, qword ptr [rip + src_ptr]
    movzx ecx, byte ptr [rsi + rax]
    cmp ecx, ' '
    je .hss_next
    cmp ecx, 9
    je .hss_next
    cmp ecx, 13
    je .hss_next
    cmp ecx, 10
    je .hss_next
    jmp .hss_done
.hss_next:
    inc rax
    mov qword ptr [rip + src_pos], rax
    jmp .hss_loop
.hss_done:
    pop rsi
    ret

# EAX = character -> EAX = 1 when identifier character
hi_is_ident_char:
    cmp eax, '_'
    je .hiic_yes
    cmp eax, '0'
    jb .hiic_no
    cmp eax, '9'
    jbe .hiic_yes
    cmp eax, 'A'
    jb .hiic_no
    cmp eax, 'Z'
    jbe .hiic_yes
    cmp eax, 'a'
    jb .hiic_no
    cmp eax, 'z'
    jbe .hiic_yes
.hiic_no:
    xor eax, eax
    ret
.hiic_yes:
    mov eax, 1
    ret

# ECX = kind, R12 = start offset, R13 = end offset
hi_push_token:
    mov rax, qword ptr [rip + tok_count]
    cmp rax, MAX_TOKENS
    jae .hpt_done
    mov r9, rax
    shl r9, 4
    lea r10, [rip + tokens]
    add r10, r9
    mov dword ptr [r10], ecx
    mov r11, r13
    sub r11, r12
    mov dword ptr [r10 + 4], r11d
    mov r11, qword ptr [rip + src_ptr]
    add r11, r12
    mov qword ptr [r10 + 8], r11
    inc rax
    mov qword ptr [rip + tok_count], rax
.hpt_done:
    mov qword ptr [rip + src_pos], r13
    ret

# ---------------------------------------------------------------- token access

# RCX = index -> RAX = record pointer
hi_tok:
    mov rax, rcx
    cmp rax, qword ptr [rip + tok_count]
    jb .ht_ok
    mov rax, qword ptr [rip + tok_count]
    dec rax
.ht_ok:
    shl rax, 4
    lea r10, [rip + tokens]
    add rax, r10
    ret

# -> EAX = kind of current token
hi_kind:
    mov rcx, qword ptr [rip + tp]
    call hi_tok
    mov eax, dword ptr [rax]
    ret

# RCX = literal cstr -> EAX = 1 when current token matches it
hi_is:
    push rbx
    push rsi
    mov rbx, rcx
    mov rcx, qword ptr [rip + tp]
    call hi_tok
    mov ecx, dword ptr [rax + 4]
    mov rsi, qword ptr [rax + 8]
    xor r10, r10
.his_loop:
    mov al, byte ptr [rbx + r10]
    test al, al
    jz .his_tail
    cmp r10, rcx
    jae .his_no
    cmp al, byte ptr [rsi + r10]
    jne .his_no
    inc r10
    jmp .his_loop
.his_tail:
    cmp r10, rcx
    jne .his_no
    mov eax, 1
    pop rsi
    pop rbx
    ret
.his_no:
    xor eax, eax
    pop rsi
    pop rbx
    ret

hi_advance:
    inc qword ptr [rip + tp]
    ret

# RCX = literal cstr; consumes the token when it matches. EAX = 1 on match.
hi_accept:
    call hi_is
    test eax, eax
    jz .hac_no
    call hi_advance
    mov eax, 1
    ret
.hac_no:
    xor eax, eax
    ret

# ---------------------------------------------------------------- prescan

hi_prescan:
    push rbx
    push rsi
    push r12
    mov qword ptr [rip + tp], 0
.hps_loop:
    call hi_kind
    cmp eax, TOK_EOF
    je .hps_done
    lea rcx, [rip + kw_fn]
    call hi_is
    test eax, eax
    jz .hps_next
    call hi_advance

    mov rcx, qword ptr [rip + tp]
    call hi_tok
    mov r12, qword ptr [rip + func_count]
    cmp r12, MAX_FUNCS
    jae .hps_next
    mov rsi, r12
    imul rsi, 40
    lea rbx, [rip + funcs]
    add rbx, rsi
    mov rcx, qword ptr [rax + 8]
    mov qword ptr [rbx], rcx
    mov ecx, dword ptr [rax + 4]
    mov qword ptr [rbx + 8], rcx
    call hi_advance

    # parameter list
    lea rcx, [rip + p_lparen]
    call hi_accept
    mov r8, qword ptr [rip + tp]
    mov qword ptr [rbx + 16], r8
    xor r9, r9
.hps_params:
    lea rcx, [rip + p_rparen]
    call hi_is
    test eax, eax
    jnz .hps_params_done
    call hi_kind
    cmp eax, TOK_EOF
    je .hps_params_done
    call hi_kind
    cmp eax, TOK_IDENT
    jne .hps_param_skip
    inc r9
.hps_param_skip:
    call hi_advance
    jmp .hps_params
.hps_params_done:
    mov qword ptr [rbx + 24], r9
    call hi_advance
    mov r8, qword ptr [rip + tp]
    mov qword ptr [rbx + 32], r8
    inc qword ptr [rip + func_count]
.hps_next:
    call hi_advance
    jmp .hps_loop
.hps_done:
    mov qword ptr [rip + tp], 0
    pop r12
    pop rsi
    pop rbx
    ret

# RCX = name pointer, RDX = name length -> RAX = function record or 0
hi_find_func:
    push rbx
    push rsi
    push rdi
    mov rsi, rcx
    mov rdi, rdx
    xor rbx, rbx
.hff_loop:
    cmp rbx, qword ptr [rip + func_count]
    jae .hff_none
    mov rax, rbx
    imul rax, 40
    lea r10, [rip + funcs]
    add r10, rax
    mov rcx, qword ptr [r10 + 8]
    cmp rcx, rdi
    jne .hff_next
    mov r8, qword ptr [r10]
    xor r9, r9
.hff_cmp:
    cmp r9, rdi
    jae .hff_hit
    mov al, byte ptr [r8 + r9]
    cmp al, byte ptr [rsi + r9]
    jne .hff_next
    inc r9
    jmp .hff_cmp
.hff_hit:
    mov rax, r10
    pop rdi
    pop rsi
    pop rbx
    ret
.hff_next:
    inc rbx
    jmp .hff_loop
.hff_none:
    xor rax, rax
    pop rdi
    pop rsi
    pop rbx
    ret

# ---------------------------------------------------------------- environment

# RCX = name ptr, RDX = name len -> RAX = entry pointer or 0
hi_env_lookup:
    push rbx
    mov rbx, qword ptr [rip + env_count]
.hel_loop:
    cmp rbx, qword ptr [rip + frame_base]
    jbe .hel_none
    dec rbx
    mov rax, rbx
    imul rax, 40
    lea r10, [rip + env]
    add r10, rax
    cmp qword ptr [r10 + 8], rdx
    jne .hel_loop
    mov r8, qword ptr [r10]
    xor r9, r9
.hel_cmp:
    cmp r9, rdx
    jae .hel_hit
    mov al, byte ptr [r8 + r9]
    cmp al, byte ptr [rcx + r9]
    jne .hel_loop
    inc r9
    jmp .hel_cmp
.hel_hit:
    mov rax, r10
    pop rbx
    ret
.hel_none:
    xor rax, rax
    pop rbx
    ret

# RCX = name ptr, RDX = name len, R8 = tag, R9 = a, [rsp+40] = b
hi_env_define:
    mov r10, qword ptr [rip + env_count]
    cmp r10, MAX_ENV
    jae .hed_done
    mov rax, r10
    imul rax, 40
    lea r11, [rip + env]
    add r11, rax
    mov qword ptr [r11], rcx
    mov qword ptr [r11 + 8], rdx
    mov qword ptr [r11 + 16], r8
    mov qword ptr [r11 + 24], r9
    mov rax, qword ptr [rsp + 40]
    mov qword ptr [r11 + 32], rax
    inc r10
    mov qword ptr [rip + env_count], r10
.hed_done:
    ret

# ---------------------------------------------------------------- arena

# RCX = length -> RAX = pointer
hi_alloc:
    mov rax, qword ptr [rip + arena_used]
    mov r10, rax
    add r10, rcx
    cmp r10, ARENA_SIZE
    jae .hal_full
    mov qword ptr [rip + arena_used], r10
    add rax, qword ptr [rip + arena_ptr]
    ret
.hal_full:
    mov rax, qword ptr [rip + arena_ptr]
    ret

# ---------------------------------------------------------------- values
# Values travel in RAX = tag, RDX = a (integer value or string pointer),
# R8 = b (string length).

# RCX = value pointer/len in RDX/R8 with tag RAX -> RDX/R8 as text
hi_to_text:
    cmp rax, TAG_STR
    je .htt_done
    cmp rax, TAG_BOOL
    je .htt_bool
    cmp rax, TAG_INT
    je .htt_int
    lea rdx, [rip + text_none]
    mov r8, 4
    ret
.htt_bool:
    test rdx, rdx
    jz .htt_false
    lea rdx, [rip + text_true]
    mov r8, 4
    ret
.htt_false:
    lea rdx, [rip + text_false]
    mov r8, 5
    ret
.htt_int:
    push rbx
    push rsi
    push rdi
    mov rcx, 24
    call hi_alloc
    mov rsi, rax
    mov rax, rdx
    mov rbx, 0
    test rax, rax
    jns .htt_positive
    neg rax
    mov rbx, 1
.htt_positive:
    mov rdi, 24
    mov byte ptr [rsi + 23], '0'
    test rax, rax
    jz .htt_zero
    mov rdi, 24
    mov r9, 10
.htt_digits:
    xor rdx, rdx
    div r9
    add dl, '0'
    dec rdi
    mov byte ptr [rsi + rdi], dl
    test rax, rax
    jnz .htt_digits
    test rbx, rbx
    jz .htt_emit
    dec rdi
    mov byte ptr [rsi + rdi], '-'
    jmp .htt_emit
.htt_zero:
    mov rdi, 23
.htt_emit:
    lea rdx, [rsi + rdi]
    mov r8, 24
    sub r8, rdi
    pop rdi
    pop rsi
    pop rbx
    mov rax, TAG_STR
    ret
.htt_done:
    ret

# RDX = pointer, R8 = length -> printed with a newline
hi_print_text:
    push rbx
    sub rsp, 32
    mov rcx, rdx
    mov rdx, r8
    call write_out
    lea rcx, [rip + text_newline]
    mov rdx, 2
    call write_out
    add rsp, 32
    pop rbx
    ret

# ---------------------------------------------------------------- execution

# Executes statements until end/else/EOF. RAX = 1 when a return happened.
hi_exec_block:
    push rbx
    sub rsp, 32
.heb_loop:
    call hi_kind
    cmp eax, TOK_EOF
    je .heb_normal
    lea rcx, [rip + kw_end]
    call hi_is
    test eax, eax
    jnz .heb_normal
    lea rcx, [rip + kw_else]
    call hi_is
    test eax, eax
    jnz .heb_normal
    call hi_exec_stmt
    test rax, rax
    jnz .heb_returned
    jmp .heb_loop
.heb_normal:
    xor rax, rax
    add rsp, 32
    pop rbx
    ret
.heb_returned:
    mov rax, 1
    add rsp, 32
    pop rbx
    ret

# Skips a block including its terminating end.
hi_skip_block:
    push rbx
    sub rsp, 32
    xor rbx, rbx
.hsb_loop:
    call hi_kind
    cmp eax, TOK_EOF
    je .hsb_done
    lea rcx, [rip + kw_end]
    call hi_is
    test eax, eax
    jz .hsb_check_open
    test rbx, rbx
    jz .hsb_done
    dec rbx
    call hi_advance
    jmp .hsb_loop
.hsb_check_open:
    lea rcx, [rip + kw_else]
    call hi_is
    test eax, eax
    jz .hsb_check_nested
    test rbx, rbx
    jz .hsb_done
    call hi_advance
    jmp .hsb_loop
.hsb_check_nested:
    lea rcx, [rip + kw_if]
    call hi_is
    test eax, eax
    jnz .hsb_open
    lea rcx, [rip + kw_while]
    call hi_is
    test eax, eax
    jnz .hsb_open
    lea rcx, [rip + kw_fn]
    call hi_is
    test eax, eax
    jnz .hsb_open
    call hi_advance
    jmp .hsb_loop
.hsb_open:
    inc rbx
    call hi_advance
    jmp .hsb_loop
.hsb_done:
    add rsp, 32
    pop rbx
    ret

hi_exec_stmt:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    sub rsp, 32

    lea rcx, [rip + kw_fn]
    call hi_is
    test eax, eax
    jnz .hes_fn
    lea rcx, [rip + kw_module]
    call hi_is
    test eax, eax
    jnz .hes_skip_line
    lea rcx, [rip + kw_use]
    call hi_is
    test eax, eax
    jnz .hes_skip_line
    lea rcx, [rip + kw_if]
    call hi_is
    test eax, eax
    jnz .hes_if
    lea rcx, [rip + kw_while]
    call hi_is
    test eax, eax
    jnz .hes_while
    lea rcx, [rip + kw_return]
    call hi_is
    test eax, eax
    jnz .hes_return
    lea rcx, [rip + kw_print]
    call hi_is
    test eax, eax
    jnz .hes_print
    lea rcx, [rip + kw_mut]
    call hi_is
    test eax, eax
    jnz .hes_mut

    # assignment or bare expression
    call hi_kind
    cmp eax, TOK_IDENT
    jne .hes_expr
    mov rcx, qword ptr [rip + tp]
    inc rcx
    call hi_tok
    mov ecx, dword ptr [rax + 4]
    cmp ecx, 1
    jne .hes_expr
    mov r9, qword ptr [rax + 8]
    movzx eax, byte ptr [r9]
    cmp eax, '='
    jne .hes_expr

.hes_assign:
    mov rcx, qword ptr [rip + tp]
    call hi_tok
    mov rsi, qword ptr [rax + 8]
    mov edi, dword ptr [rax + 4]
    call hi_advance
    call hi_advance
    call hi_eval_expr
    mov r12, rax
    mov r13, rdx
    mov r14, r8
    mov rcx, rsi
    mov rdx, rdi
    call hi_env_lookup
    test rax, rax
    jz .hes_define
    mov qword ptr [rax + 16], r12
    mov qword ptr [rax + 24], r13
    mov qword ptr [rax + 32], r14
    jmp .hes_ok
.hes_define:
    sub rsp, 48
    mov rcx, rsi
    mov rdx, rdi
    mov r8, r12
    mov r9, r13
    mov qword ptr [rsp + 32], r14
    call hi_env_define
    add rsp, 48
    jmp .hes_ok

.hes_mut:
    call hi_advance
    jmp .hes_assign

.hes_fn:
    call hi_advance
    call hi_skip_block
    call hi_advance
    jmp .hes_ok

.hes_skip_line:
    call hi_advance
.hes_skip_scan:
    call hi_kind
    cmp eax, TOK_EOF
    je .hes_ok
    call hi_kind
    cmp eax, TOK_IDENT
    jne .hes_skip_step
    lea rcx, [rip + kw_fn]
    call hi_is
    test eax, eax
    jnz .hes_ok
    lea rcx, [rip + kw_print]
    call hi_is
    test eax, eax
    jnz .hes_ok
.hes_skip_step:
    call hi_advance
    jmp .hes_skip_scan

.hes_if:
    call hi_advance
    call hi_eval_expr
    call hi_truthy
    test rax, rax
    jz .hes_if_false
    call hi_exec_block
    test rax, rax
    jnz .hes_returned
    lea rcx, [rip + kw_else]
    call hi_is
    test eax, eax
    jz .hes_if_close
    call hi_advance
    call hi_skip_block
.hes_if_close:
    call hi_advance
    jmp .hes_ok
.hes_if_false:
    call hi_skip_block
    lea rcx, [rip + kw_else]
    call hi_is
    test eax, eax
    jz .hes_if_close2
    call hi_advance
    call hi_exec_block
    test rax, rax
    jnz .hes_returned
.hes_if_close2:
    call hi_advance
    jmp .hes_ok

.hes_while:
    call hi_advance
    mov rbx, qword ptr [rip + tp]
.hes_while_iter:
    mov qword ptr [rip + tp], rbx
    call hi_eval_expr
    call hi_truthy
    test rax, rax
    jz .hes_while_exit
    call hi_exec_block
    test rax, rax
    jnz .hes_returned
    jmp .hes_while_iter
.hes_while_exit:
    call hi_skip_block
    call hi_advance
    jmp .hes_ok

.hes_return:
    call hi_advance
    call hi_kind
    cmp eax, TOK_EOF
    je .hes_return_none
    lea rcx, [rip + kw_end]
    call hi_is
    test eax, eax
    jnz .hes_return_none
    call hi_eval_expr
    mov qword ptr [rip + ret_tag], rax
    mov qword ptr [rip + ret_a], rdx
    mov qword ptr [rip + ret_b], r8
    jmp .hes_returned
.hes_return_none:
    mov qword ptr [rip + ret_tag], TAG_NONE
    mov qword ptr [rip + ret_a], 0
    mov qword ptr [rip + ret_b], 0
    jmp .hes_returned

.hes_print:
    call hi_advance
    lea rcx, [rip + p_lparen]
    call hi_accept
    call hi_eval_expr
    call hi_to_text
    call hi_print_text
    lea rcx, [rip + p_rparen]
    call hi_accept
    jmp .hes_ok

.hes_expr:
    call hi_eval_expr
    jmp .hes_ok

.hes_ok:
    xor rax, rax
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret
.hes_returned:
    mov rax, 1
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

# RAX/RDX/R8 = value -> RAX = 0 or 1
hi_truthy:
    cmp rax, TAG_NONE
    je .htr_false
    cmp rax, TAG_STR
    je .htr_str
    test rdx, rdx
    jz .htr_false
    mov rax, 1
    ret
.htr_str:
    test r8, r8
    jz .htr_false
    mov rax, 1
    ret
.htr_false:
    xor rax, rax
    ret

# ---------------------------------------------------------------- expressions

hi_eval_expr:
    push rbx
    sub rsp, 32
    call hi_eval_and
.hee_loop:
    push rax
    push rdx
    push r8
    lea rcx, [rip + kw_or]
    call hi_is
    test eax, eax
    pop r8
    pop rdx
    pop rax
    jz .hee_done
    call hi_truthy
    push rax
    call hi_advance
    call hi_eval_and
    call hi_truthy
    pop rcx
    or rax, rcx
    mov rdx, rax
    mov rax, TAG_BOOL
    xor r8, r8
    jmp .hee_loop
.hee_done:
    add rsp, 32
    pop rbx
    ret

hi_eval_and:
    push rbx
    sub rsp, 32
    call hi_eval_cmp
.hea_loop:
    push rax
    push rdx
    push r8
    lea rcx, [rip + kw_and]
    call hi_is
    test eax, eax
    pop r8
    pop rdx
    pop rax
    jz .hea_done
    call hi_truthy
    push rax
    call hi_advance
    call hi_eval_cmp
    call hi_truthy
    pop rcx
    and rax, rcx
    mov rdx, rax
    mov rax, TAG_BOOL
    xor r8, r8
    jmp .hea_loop
.hea_done:
    add rsp, 32
    pop rbx
    ret

hi_eval_cmp:
    push rbx
    push rsi
    push rdi
    sub rsp, 40
    call hi_eval_add
.hec_loop:
    mov rsi, rdx
    mov rdi, rax
    mov rbx, r8

    lea rcx, [rip + p_eqeq]
    call hi_is
    test eax, eax
    jnz .hec_op_eq
    lea rcx, [rip + p_noteq]
    call hi_is
    test eax, eax
    jnz .hec_op_ne
    lea rcx, [rip + p_le]
    call hi_is
    test eax, eax
    jnz .hec_op_le
    lea rcx, [rip + p_ge]
    call hi_is
    test eax, eax
    jnz .hec_op_ge
    lea rcx, [rip + p_lt]
    call hi_is
    test eax, eax
    jnz .hec_op_lt
    lea rcx, [rip + p_gt]
    call hi_is
    test eax, eax
    jnz .hec_op_gt
    mov rax, rdi
    mov rdx, rsi
    mov r8, rbx
    add rsp, 40
    pop rdi
    pop rsi
    pop rbx
    ret

.hec_op_eq:
    mov r15, 0
    jmp .hec_apply
.hec_op_ne:
    mov r15, 1
    jmp .hec_apply
.hec_op_lt:
    mov r15, 2
    jmp .hec_apply
.hec_op_gt:
    mov r15, 3
    jmp .hec_apply
.hec_op_le:
    mov r15, 4
    jmp .hec_apply
.hec_op_ge:
    mov r15, 5
.hec_apply:
    call hi_advance
    push r15
    call hi_eval_add
    pop r15
    mov rcx, rdx
    mov rdx, rsi
    # RDX = left integer, RCX = right integer
    xor r9, r9
    cmp r15, 0
    jne .hec_try_ne
    cmp rdx, rcx
    je .hec_true
    jmp .hec_store
.hec_try_ne:
    cmp r15, 1
    jne .hec_try_lt
    cmp rdx, rcx
    jne .hec_true
    jmp .hec_store
.hec_try_lt:
    cmp r15, 2
    jne .hec_try_gt
    cmp rdx, rcx
    jl .hec_true
    jmp .hec_store
.hec_try_gt:
    cmp r15, 3
    jne .hec_try_le
    cmp rdx, rcx
    jg .hec_true
    jmp .hec_store
.hec_try_le:
    cmp r15, 4
    jne .hec_try_ge
    cmp rdx, rcx
    jle .hec_true
    jmp .hec_store
.hec_try_ge:
    cmp rdx, rcx
    jge .hec_true
    jmp .hec_store
.hec_true:
    mov r9, 1
.hec_store:
    mov rax, TAG_BOOL
    mov rdx, r9
    xor r8, r8
    jmp .hec_loop

hi_eval_add:
    push rbx
    push rsi
    push rdi
    sub rsp, 40
    call hi_eval_mul
.hea2_loop:
    mov rsi, rdx
    mov rdi, rax
    mov rbx, r8
    lea rcx, [rip + p_plus]
    call hi_is
    test eax, eax
    jnz .hea2_plus
    lea rcx, [rip + p_minus]
    call hi_is
    test eax, eax
    jnz .hea2_minus
    mov rax, rdi
    mov rdx, rsi
    mov r8, rbx
    add rsp, 40
    pop rdi
    pop rsi
    pop rbx
    ret
.hea2_plus:
    call hi_advance
    call hi_eval_mul
    cmp rdi, TAG_STR
    je .hea2_concat
    cmp rax, TAG_STR
    je .hea2_concat
    add rdx, rsi
    mov rax, TAG_INT
    xor r8, r8
    jmp .hea2_loop
.hea2_concat:
    call hi_to_text
    push rdx
    push r8
    mov rax, rdi
    mov rdx, rsi
    mov r8, rbx
    call hi_to_text
    mov rsi, rdx
    mov rbx, r8
    pop r8
    pop rdx
    # RSI/RBX = left text, RDX/R8 = right text
    mov rcx, rbx
    add rcx, r8
    push rdx
    push r8
    call hi_alloc
    pop r8
    pop rdx
    mov rdi, rax
    xor r9, r9
.hea2_copy_left:
    cmp r9, rbx
    jae .hea2_copy_right_init
    mov cl, byte ptr [rsi + r9]
    mov byte ptr [rdi + r9], cl
    inc r9
    jmp .hea2_copy_left
.hea2_copy_right_init:
    xor r10, r10
.hea2_copy_right:
    cmp r10, r8
    jae .hea2_concat_done
    mov cl, byte ptr [rdx + r10]
    mov byte ptr [rdi + r9], cl
    inc r9
    inc r10
    jmp .hea2_copy_right
.hea2_concat_done:
    mov rax, TAG_STR
    mov rdx, rdi
    mov r8, r9
    jmp .hea2_loop
.hea2_minus:
    call hi_advance
    call hi_eval_mul
    mov rcx, rdx
    mov rdx, rsi
    sub rdx, rcx
    mov rax, TAG_INT
    xor r8, r8
    jmp .hea2_loop

hi_eval_mul:
    push rbx
    push rsi
    push rdi
    sub rsp, 40
    call hi_eval_unary
.hem_loop:
    mov rsi, rdx
    mov rdi, rax
    mov rbx, r8
    lea rcx, [rip + p_star]
    call hi_is
    test eax, eax
    jnz .hem_star
    lea rcx, [rip + p_slash]
    call hi_is
    test eax, eax
    jnz .hem_slash
    lea rcx, [rip + p_percent]
    call hi_is
    test eax, eax
    jnz .hem_percent
    mov rax, rdi
    mov rdx, rsi
    mov r8, rbx
    add rsp, 40
    pop rdi
    pop rsi
    pop rbx
    ret
.hem_star:
    call hi_advance
    call hi_eval_unary
    mov rax, rsi
    imul rax, rdx
    mov rdx, rax
    mov rax, TAG_INT
    xor r8, r8
    jmp .hem_loop
.hem_slash:
    call hi_advance
    call hi_eval_unary
    mov rcx, rdx
    test rcx, rcx
    jz .hem_div_zero
    mov rax, rsi
    cqo
    idiv rcx
    mov rdx, rax
    mov rax, TAG_INT
    xor r8, r8
    jmp .hem_loop
.hem_div_zero:
    mov rax, TAG_INT
    xor rdx, rdx
    xor r8, r8
    jmp .hem_loop
.hem_percent:
    call hi_advance
    call hi_eval_unary
    mov rcx, rdx
    test rcx, rcx
    jz .hem_div_zero
    mov rax, rsi
    cqo
    idiv rcx
    mov rax, TAG_INT
    xor r8, r8
    jmp .hem_loop

hi_eval_unary:
    push rbx
    sub rsp, 32
    lea rcx, [rip + kw_not]
    call hi_is
    test eax, eax
    jnz .heu_not
    lea rcx, [rip + p_minus]
    call hi_is
    test eax, eax
    jnz .heu_neg
    call hi_eval_primary
    add rsp, 32
    pop rbx
    ret
.heu_not:
    call hi_advance
    call hi_eval_unary
    call hi_truthy
    xor rax, 1
    mov rdx, rax
    mov rax, TAG_BOOL
    xor r8, r8
    add rsp, 32
    pop rbx
    ret
.heu_neg:
    call hi_advance
    call hi_eval_unary
    neg rdx
    mov rax, TAG_INT
    xor r8, r8
    add rsp, 32
    pop rbx
    ret

hi_eval_primary:
    push rbx
    push rsi
    push rdi
    sub rsp, 40

    lea rcx, [rip + p_lparen]
    call hi_is
    test eax, eax
    jnz .hep_paren

    call hi_kind
    cmp eax, TOK_NUM
    je .hep_number
    cmp eax, TOK_STR
    je .hep_string
    cmp eax, TOK_IDENT
    je .hep_ident

    call hi_advance
    mov rax, TAG_NONE
    xor rdx, rdx
    xor r8, r8
    jmp .hep_done

.hep_paren:
    call hi_advance
    call hi_eval_expr
    push rax
    push rdx
    push r8
    lea rcx, [rip + p_rparen]
    call hi_accept
    pop r8
    pop rdx
    pop rax
    jmp .hep_done

.hep_number:
    mov rcx, qword ptr [rip + tp]
    call hi_tok
    mov rsi, qword ptr [rax + 8]
    mov edi, dword ptr [rax + 4]
    call hi_advance
    xor rax, rax
    xor r9, r9
.hep_num_loop:
    cmp r9, rdi
    jae .hep_num_done
    movzx ecx, byte ptr [rsi + r9]
    sub ecx, '0'
    imul rax, rax, 10
    add rax, rcx
    inc r9
    jmp .hep_num_loop
.hep_num_done:
    mov rdx, rax
    mov rax, TAG_INT
    xor r8, r8
    jmp .hep_done

.hep_string:
    mov rcx, qword ptr [rip + tp]
    call hi_tok
    mov rsi, qword ptr [rax + 8]
    mov edi, dword ptr [rax + 4]
    call hi_advance
    mov rcx, rsi
    mov rdx, rdi
    call hi_interpolate
    jmp .hep_done

.hep_ident:
    lea rcx, [rip + kw_true]
    call hi_is
    test eax, eax
    jnz .hep_true
    lea rcx, [rip + kw_false]
    call hi_is
    test eax, eax
    jnz .hep_false

    mov rcx, qword ptr [rip + tp]
    call hi_tok
    mov rsi, qword ptr [rax + 8]
    mov edi, dword ptr [rax + 4]
    call hi_advance

    lea rcx, [rip + p_lparen]
    call hi_is
    test eax, eax
    jnz .hep_call

    mov rcx, rsi
    mov rdx, rdi
    call hi_env_lookup
    test rax, rax
    jz .hep_unknown
    mov rdx, qword ptr [rax + 24]
    mov r8, qword ptr [rax + 32]
    mov rax, qword ptr [rax + 16]
    jmp .hep_done
.hep_unknown:
    mov rax, TAG_NONE
    xor rdx, rdx
    xor r8, r8
    jmp .hep_done

.hep_true:
    call hi_advance
    mov rax, TAG_BOOL
    mov rdx, 1
    xor r8, r8
    jmp .hep_done
.hep_false:
    call hi_advance
    mov rax, TAG_BOOL
    xor rdx, rdx
    xor r8, r8
    jmp .hep_done

.hep_call:
    call hi_advance
    xor rbx, rbx
.hep_args:
    lea rcx, [rip + p_rparen]
    call hi_is
    test eax, eax
    jnz .hep_args_done
    call hi_kind
    cmp eax, TOK_EOF
    je .hep_args_done
    push rbx
    call hi_eval_expr
    pop rbx
    cmp rbx, 8
    jae .hep_arg_skip
    mov r9, rbx
    imul r9, 24
    lea r10, [rip + call_args]
    add r10, r9
    mov qword ptr [r10], rax
    mov qword ptr [r10 + 8], rdx
    mov qword ptr [r10 + 16], r8
    inc rbx
.hep_arg_skip:
    lea rcx, [rip + p_comma]
    call hi_accept
    jmp .hep_args
.hep_args_done:
    call hi_advance
    mov qword ptr [rip + call_argc], rbx
    mov rcx, rsi
    mov rdx, rdi
    call hi_find_func
    test rax, rax
    jz .hep_unknown
    mov rcx, rax
    call hi_call_function
.hep_done:
    add rsp, 40
    pop rdi
    pop rsi
    pop rbx
    ret

# RCX = function record. Arguments in call_args/call_argc.
hi_call_function:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 40
    mov rbx, rcx

    mov r12, qword ptr [rip + tp]
    mov r13, qword ptr [rip + frame_base]
    mov rsi, qword ptr [rip + env_count]
    mov qword ptr [rip + frame_base], rsi

    # bind parameters
    mov rdi, qword ptr [rbx + 16]
    xor r14, r14
.hcf_bind:
    cmp r14, qword ptr [rbx + 24]
    jae .hcf_body
    mov rcx, rdi
    call hi_tok
    mov ecx, dword ptr [rax]
    cmp ecx, TOK_IDENT
    jne .hcf_bind_next
    mov r9, r14
    imul r9, 24
    lea r10, [rip + call_args]
    add r10, r9
    mov rcx, qword ptr [rax + 8]
    mov edx, dword ptr [rax + 4]
    mov r8, qword ptr [r10]
    mov r9, qword ptr [r10 + 8]
    mov r11, qword ptr [r10 + 16]
    sub rsp, 48
    mov qword ptr [rsp + 32], r11
    call hi_env_define
    add rsp, 48
    inc r14
.hcf_bind_next:
    inc rdi
    jmp .hcf_bind

.hcf_body:
    mov qword ptr [rip + ret_tag], TAG_NONE
    mov qword ptr [rip + ret_a], 0
    mov qword ptr [rip + ret_b], 0
    mov rax, qword ptr [rbx + 32]
    mov qword ptr [rip + tp], rax
    call hi_exec_block

    mov qword ptr [rip + env_count], rsi
    mov qword ptr [rip + frame_base], r13
    mov qword ptr [rip + tp], r12

    mov rax, qword ptr [rip + ret_tag]
    mov rdx, qword ptr [rip + ret_a]
    mov r8, qword ptr [rip + ret_b]
    add rsp, 40
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

# RCX = raw text pointer, RDX = length. Expands {name} using the environment.
hi_interpolate:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40
    mov rsi, rcx
    mov rbx, rdx

    mov rcx, rbx
    add rcx, 1024
    call hi_alloc
    mov rdi, rax
    xor r12, r12                    # output length
    xor r13, r13                    # input index
.hin_loop:
    cmp r13, rbx
    jae .hin_done
    movzx eax, byte ptr [rsi + r13]
    cmp eax, '{'
    je .hin_open
    mov byte ptr [rdi + r12], al
    inc r12
    inc r13
    jmp .hin_loop
.hin_open:
    inc r13
    mov r14, r13
.hin_find:
    cmp r13, rbx
    jae .hin_done
    movzx eax, byte ptr [rsi + r13]
    cmp eax, '}'
    je .hin_name
    inc r13
    jmp .hin_find
.hin_name:
    mov r15, r13
    sub r15, r14
    inc r13
    lea rcx, [rsi + r14]
    mov rdx, r15
    call hi_env_lookup
    test rax, rax
    jz .hin_loop
    mov rdx, qword ptr [rax + 24]
    mov r8, qword ptr [rax + 32]
    mov rax, qword ptr [rax + 16]
    call hi_to_text
    xor r9, r9
.hin_copy:
    cmp r9, r8
    jae .hin_loop
    mov cl, byte ptr [rdx + r9]
    mov byte ptr [rdi + r12], cl
    inc r12
    inc r9
    jmp .hin_copy
.hin_done:
    mov rax, TAG_STR
    mov rdx, rdi
    mov r8, r12
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

# ---------------------------------------------------------------- data

.section .rodata
kw_fn: .asciz "fn"
kw_end: .asciz "end"
kw_if: .asciz "if"
kw_else: .asciz "else"
kw_while: .asciz "while"
kw_return: .asciz "return"
kw_print: .asciz "print"
kw_mut: .asciz "mut"
kw_module: .asciz "module"
kw_use: .asciz "use"
kw_main: .asciz "main"
kw_true: .asciz "true"
kw_false: .asciz "false"
kw_and: .asciz "and"
kw_or: .asciz "or"
kw_not: .asciz "not"
p_lparen: .asciz "("
p_rparen: .asciz ")"
p_comma: .asciz ","
p_plus: .asciz "+"
p_minus: .asciz "-"
p_star: .asciz "*"
p_slash: .asciz "/"
p_percent: .asciz "%"
p_eqeq: .asciz "=="
p_noteq: .asciz "!="
p_lt: .asciz "<"
p_gt: .asciz ">"
p_le: .asciz "<="
p_ge: .asciz ">="
text_none: .ascii "none"
text_true: .ascii "true"
text_false: .ascii "false"
text_newline: .ascii "\r\n"

.bss
.align 8
src_ptr: .space 8
src_len: .space 8
src_pos: .space 8
tok_count: .space 8
tp: .space 8
func_count: .space 8
env_count: .space 8
frame_base: .space 8
arena_ptr: .space 8
arena_used: .space 8
ret_tag: .space 8
ret_a: .space 8
ret_b: .space 8
call_argc: .space 8
hi_error_count: .space 8
call_args: .space 192
funcs: .space 10240
env: .space 40960
tokens: .space 1048576
