.intel_syntax noprefix

# Hust 0.8.14 rust2hust converter core.
# Canonical high-level behavior: compiler/rust2hust/*.hs
# Pure transformation code: no imports, no syscalls, no allocation.

.equ LINE_MAX, 262144
.equ STACK_MAX, 4096
.equ TMP_MAX, 262144

.text
.globl r2h_convert
.globl r2h_stat_lifetime
.globl r2h_stat_where
.globl r2h_stat_macro
.globl r2h_stat_iflet
.globl r2h_stat_closure
.globl r2h_stat_unsafe
.globl r2h_stat_reset

r2h_stat_reset:
    xor eax, eax
    mov qword ptr [rip + r2h_stat_lifetime], rax
    mov qword ptr [rip + r2h_stat_where], rax
    mov qword ptr [rip + r2h_stat_macro], rax
    mov qword ptr [rip + r2h_stat_iflet], rax
    mov qword ptr [rip + r2h_stat_closure], rax
    mov qword ptr [rip + r2h_stat_unsafe], rax
    ret

# rcx = src, rdx = src length, r8 = out, r9 = out capacity -> rax = out length
r2h_convert:
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
    mov qword ptr [rip + out_ptr], r8
    mov qword ptr [rip + out_cap], r9
    xor eax, eax
    mov qword ptr [rip + out_len], rax
    mov qword ptr [rip + src_pos], rax
    mov qword ptr [rip + line_len], rax
    mov qword ptr [rip + stack_sp], rax
    mov qword ptr [rip + indent], rax
    mov qword ptr [rip + prev_op], rax
    mov qword ptr [rip + header_flag], rax
    mov qword ptr [rip + decl_flag], rax
    mov qword ptr [rip + pending_let], rax
    mov qword ptr [rip + paren_depth], rax
    mov qword ptr [rip + rhs_start], rax
    mov qword ptr [rip + erase_sp], rax
    mov qword ptr [rip + iflet_flag], rax
    mov qword ptr [rip + use_flag], rax
    mov qword ptr [rip + skip_paren_close], rax

conv_loop:
    call check_erase_skip
    call cur_ch
    cmp eax, -1
    je conv_done

    cmp eax, ' '
    je conv_space
    cmp eax, 9
    je conv_space
    cmp eax, 13
    je conv_space
    cmp eax, 10
    je conv_space

    cmp eax, '/'
    jne conv_not_slash
    call peek_ch
    cmp eax, '/'
    je conv_line_comment
    cmp eax, '*'
    je conv_block_comment
conv_not_slash:
    call cur_ch

    cmp eax, '"'
    je conv_string

    cmp eax, 0x27
    je conv_quote

    cmp eax, '_'
    je conv_ident
    cmp eax, 'a'
    jb conv_chk_upper
    cmp eax, 'z'
    jbe conv_ident
conv_chk_upper:
    cmp eax, 'A'
    jb conv_chk_digit
    cmp eax, 'Z'
    jbe conv_ident
conv_chk_digit:
    cmp eax, '0'
    jb conv_punct
    cmp eax, '9'
    jbe conv_number
    jmp conv_punct

conv_space:
    call adv
    call last_ch
    cmp eax, -1
    je conv_loop
    cmp eax, ' '
    je conv_loop
    mov cl, ' '
    call emit_ch
    jmp conv_loop

conv_line_comment:
    call adv
    call adv
cl_skip:
    call cur_ch
    cmp eax, -1
    je conv_loop
    cmp eax, 10
    je conv_loop
    call adv
    jmp cl_skip

conv_block_comment:
    call adv
    call adv
    mov r15, 1
bc_skip:
    call cur_ch
    cmp eax, -1
    je conv_loop
    cmp eax, '*'
    jne bc_chk_open
    call peek_ch
    cmp eax, '/'
    jne bc_next
    call adv
    call adv
    dec r15
    cmp r15, 0
    je conv_loop
    jmp bc_skip
bc_chk_open:
    cmp eax, '/'
    jne bc_next
    call peek_ch
    cmp eax, '*'
    jne bc_next
    call adv
    call adv
    inc r15
    jmp bc_skip
bc_next:
    call adv
    jmp bc_skip

conv_string:
    call copy_string
    mov qword ptr [rip + prev_op], 1
    jmp conv_loop

conv_quote:
    call handle_quote
    jmp conv_loop

conv_ident:
    call handle_ident
    jmp conv_loop

conv_number:
    call handle_number
    jmp conv_loop

conv_punct:
    call handle_punct
    jmp conv_loop

conv_done:
    call flush_line
    mov rax, qword ptr [rip + out_len]
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

# ---------------------------------------------------------------- primitives

cur_ch:
    mov r10, qword ptr [rip + src_pos]
    cmp r10, qword ptr [rip + src_len]
    jae cur_eof
    mov r11, qword ptr [rip + src_ptr]
    movzx eax, byte ptr [r11 + r10]
    ret
cur_eof:
    mov eax, -1
    ret

peek_ch:
    mov r10, qword ptr [rip + src_pos]
    inc r10
    cmp r10, qword ptr [rip + src_len]
    jae cur_eof
    mov r11, qword ptr [rip + src_ptr]
    movzx eax, byte ptr [r11 + r10]
    ret

# rcx = offset -> eax
peek_at:
    mov r10, qword ptr [rip + src_pos]
    add r10, rcx
    cmp r10, qword ptr [rip + src_len]
    jae cur_eof
    mov r11, qword ptr [rip + src_ptr]
    movzx eax, byte ptr [r11 + r10]
    ret

adv:
    mov r10, qword ptr [rip + src_pos]
    inc r10
    mov qword ptr [rip + src_pos], r10
    ret

check_erase_skip:
    mov r10, qword ptr [rip + erase_sp]
    test r10, r10
    jz ces_done
    mov r11, qword ptr [rip + src_pos]
    lea rax, [rip + erase_stack]
ces_scan:
    dec r10
    mov rcx, qword ptr [rax + r10 * 8]
    cmp rcx, r11
    je ces_hit
    test r10, r10
    jnz ces_scan
    ret
ces_hit:
    mov rcx, qword ptr [rip + erase_sp]
    dec rcx
    mov rdx, qword ptr [rax + rcx * 8]
    mov qword ptr [rax + r10 * 8], rdx
    mov qword ptr [rip + erase_sp], rcx
    call adv
    jmp check_erase_skip
ces_done:
    ret

# cl = char
emit_ch:
    mov r10, qword ptr [rip + line_len]
    cmp r10, LINE_MAX
    jae emit_ch_done
    lea r11, [rip + line_buf]
    mov byte ptr [r11 + r10], cl
    inc r10
    mov qword ptr [rip + line_len], r10
emit_ch_done:
    ret

# rcx = ptr, rdx = len
emit_bytes:
    test rdx, rdx
    jz eb_done
    mov r8, rcx
    mov r9, rdx
    xor r10, r10
eb_loop:
    mov cl, byte ptr [r8 + r10]
    push r8
    push r9
    push r10
    call emit_ch
    pop r10
    pop r9
    pop r8
    inc r10
    cmp r10, r9
    jb eb_loop
eb_done:
    ret

# rcx = nul terminated
emit_cstr:
    mov r8, rcx
    xor r10, r10
ec_loop:
    mov cl, byte ptr [r8 + r10]
    test cl, cl
    jz ec_done
    push r8
    push r10
    call emit_ch
    pop r10
    pop r8
    inc r10
    jmp ec_loop
ec_done:
    ret

last_ch:
    mov r10, qword ptr [rip + line_len]
    test r10, r10
    jz lc_none
    dec r10
    lea r11, [rip + line_buf]
    movzx eax, byte ptr [r11 + r10]
    ret
lc_none:
    mov eax, -1
    ret

drop_last:
    mov r10, qword ptr [rip + line_len]
    test r10, r10
    jz dl_done
    dec r10
    mov qword ptr [rip + line_len], r10
dl_done:
    ret

# cl = char
out_ch:
    mov r10, qword ptr [rip + out_len]
    cmp r10, qword ptr [rip + out_cap]
    jae out_ch_done
    mov r11, qword ptr [rip + out_ptr]
    mov byte ptr [r11 + r10], cl
    inc r10
    mov qword ptr [rip + out_len], r10
out_ch_done:
    ret

flush_line:
    mov r10, qword ptr [rip + line_len]
fl_trim:
    test r10, r10
    jz fl_empty
    lea r11, [rip + line_buf]
    mov al, byte ptr [r11 + r10 - 1]
    cmp al, ' '
    jne fl_have
    dec r10
    jmp fl_trim
fl_empty:
    mov qword ptr [rip + line_len], 0
    mov qword ptr [rip + rhs_start], 0
    ret
fl_have:
    push r12
    push r13
    mov qword ptr [rip + line_len], r10
    mov r12, qword ptr [rip + indent]
    shl r12, 2
fl_indent:
    test r12, r12
    jz fl_body
    mov cl, ' '
    push r12
    call out_ch
    pop r12
    dec r12
    jmp fl_indent
fl_body:
    xor r13, r13
fl_copy:
    mov r10, qword ptr [rip + line_len]
    cmp r13, r10
    jae fl_end
    lea r11, [rip + line_buf]
    mov cl, byte ptr [r11 + r13]
    push r13
    call out_ch
    pop r13
    inc r13
    jmp fl_copy
fl_end:
    mov cl, 10
    call out_ch
    mov qword ptr [rip + line_len], 0
    mov qword ptr [rip + rhs_start], 0
    pop r13
    pop r12
    ret

# cl = kind
push_kind:
    mov r10, qword ptr [rip + stack_sp]
    cmp r10, STACK_MAX
    jae pk_done
    lea r11, [rip + stack_buf]
    mov byte ptr [r11 + r10], cl
    inc r10
    mov qword ptr [rip + stack_sp], r10
pk_done:
    ret

pop_kind:
    mov r10, qword ptr [rip + stack_sp]
    test r10, r10
    jz pop_none
    dec r10
    mov qword ptr [rip + stack_sp], r10
    lea r11, [rip + stack_buf]
    movzx eax, byte ptr [r11 + r10]
    ret
pop_none:
    mov eax, -1
    ret

top_kind:
    mov r10, qword ptr [rip + stack_sp]
    test r10, r10
    jz pop_none
    dec r10
    lea r11, [rip + stack_buf]
    movzx eax, byte ptr [r11 + r10]
    ret

# ---------------------------------------------------------------- literals

copy_string:
    call cur_ch
    mov cl, al
    call emit_ch
    call adv
cs_loop:
    call cur_ch
    cmp eax, -1
    je cs_done
    cmp eax, '\\'
    je cs_escape
    cmp eax, '"'
    je cs_close
    mov cl, al
    call emit_ch
    call adv
    jmp cs_loop
cs_escape:
    mov cl, al
    call emit_ch
    call adv
    call cur_ch
    cmp eax, -1
    je cs_done
    mov cl, al
    call emit_ch
    call adv
    jmp cs_loop
cs_close:
    mov cl, al
    call emit_ch
    call adv
cs_done:
    ret

# raw string: pos is at 'r' already consumed by caller, cur is '#' or '"'
copy_raw_string:
    xor r14, r14
crs_hash:
    call cur_ch
    cmp eax, '#'
    jne crs_open
    inc r14
    call adv
    jmp crs_hash
crs_open:
    call cur_ch
    cmp eax, '"'
    jne crs_done
    mov cl, '"'
    call emit_ch
    call adv
crs_body:
    call cur_ch
    cmp eax, -1
    je crs_done
    cmp eax, '"'
    jne crs_copy
    mov rcx, 1
    mov r15, r14
crs_check:
    test r15, r15
    jz crs_end
    call peek_at
    cmp eax, '#'
    jne crs_copy
    inc rcx
    dec r15
    jmp crs_check
crs_end:
    mov cl, '"'
    call emit_ch
    call adv
    mov r15, r14
crs_eat:
    test r15, r15
    jz crs_done
    call adv
    dec r15
    jmp crs_eat
crs_copy:
    call cur_ch
    cmp eax, '\\'
    jne crs_plain
    mov cl, '\\'
    call emit_ch
crs_plain:
    call cur_ch
    mov cl, al
    call emit_ch
    call adv
    jmp crs_body
crs_done:
    mov qword ptr [rip + prev_op], 1
    ret

handle_quote:
    mov rcx, 1
    call peek_at
    cmp eax, '\\'
    je hq_char
    mov rcx, 2
    call peek_at
    cmp eax, 0x27
    je hq_char
    call adv
    inc qword ptr [rip + r2h_stat_lifetime]
hq_skip_ident:
    call cur_ch
    call is_ident_ch
    test eax, eax
    jz hq_done
    call adv
    jmp hq_skip_ident
hq_char:
    call cur_ch
    mov cl, al
    call emit_ch
    call adv
hq_body:
    call cur_ch
    cmp eax, -1
    je hq_done
    cmp eax, '\\'
    jne hq_body_chk
    mov cl, al
    call emit_ch
    call adv
    call cur_ch
    mov cl, al
    call emit_ch
    call adv
    jmp hq_body
hq_body_chk:
    mov cl, al
    call emit_ch
    call adv
    cmp eax, 0x27
    jne hq_body
    mov qword ptr [rip + prev_op], 1
hq_done:
    ret

# eax = char -> eax = 1 if identifier char
is_ident_ch:
    cmp eax, '_'
    je iic_yes
    cmp eax, '0'
    jb iic_no
    cmp eax, '9'
    jbe iic_yes
    cmp eax, 'A'
    jb iic_no
    cmp eax, 'Z'
    jbe iic_yes
    cmp eax, 'a'
    jb iic_no
    cmp eax, 'z'
    jbe iic_yes
iic_no:
    xor eax, eax
    ret
iic_yes:
    mov eax, 1
    ret

handle_number:
    xor r14, r14
    lea r15, [rip + ident_buf]
hn_loop:
    call cur_ch
    cmp eax, -1
    je hn_end
    cmp eax, '_'
    je hn_skip
    cmp eax, '.'
    je hn_dot
    push rax
    call is_ident_ch
    test eax, eax
    pop rax
    jz hn_end
    cmp r14, 200
    jae hn_next
    mov byte ptr [r15 + r14], al
    inc r14
hn_next:
    call adv
    jmp hn_loop
hn_skip:
    call adv
    jmp hn_loop
hn_dot:
    mov rcx, 1
    call peek_at
    cmp eax, '0'
    jb hn_end
    cmp eax, '9'
    ja hn_end
    mov byte ptr [r15 + r14], '.'
    inc r14
    call adv
    jmp hn_loop
hn_end:
    mov qword ptr [rip + ident_len], r14
    call strip_num_suffix
    mov rcx, r15
    mov rdx, qword ptr [rip + ident_len]
    call emit_bytes
    mov qword ptr [rip + prev_op], 1
    ret

strip_num_suffix:
    lea rcx, [rip + sfx_usize]
    call try_strip
    lea rcx, [rip + sfx_isize]
    call try_strip
    lea rcx, [rip + sfx_u8]
    call try_strip
    lea rcx, [rip + sfx_u16]
    call try_strip
    lea rcx, [rip + sfx_u32]
    call try_strip
    lea rcx, [rip + sfx_u64]
    call try_strip
    lea rcx, [rip + sfx_i8]
    call try_strip
    lea rcx, [rip + sfx_i16]
    call try_strip
    lea rcx, [rip + sfx_i32]
    call try_strip
    lea rcx, [rip + sfx_i64]
    call try_strip
    lea rcx, [rip + sfx_f32]
    call try_strip
    lea rcx, [rip + sfx_f64]
    call try_strip
    ret

# rcx = suffix cstr
try_strip:
    mov r8, rcx
    xor r9, r9
ts_len:
    cmp byte ptr [r8 + r9], 0
    je ts_have
    inc r9
    jmp ts_len
ts_have:
    mov r10, qword ptr [rip + ident_len]
    cmp r10, r9
    jbe ts_done
    mov r11, r10
    sub r11, r9
    lea rax, [rip + ident_buf]
    add rax, r11
    xor rdx, rdx
ts_cmp:
    cmp rdx, r9
    jae ts_hit
    mov cl, byte ptr [rax + rdx]
    cmp cl, byte ptr [r8 + rdx]
    jne ts_done
    inc rdx
    jmp ts_cmp
ts_hit:
    mov qword ptr [rip + ident_len], r11
ts_done:
    ret

# ---------------------------------------------------------------- identifiers

scan_ident:
    xor r14, r14
    lea r15, [rip + ident_buf]
si_loop:
    call cur_ch
    push rax
    call is_ident_ch
    test eax, eax
    pop rax
    jz si_done
    cmp r14, 200
    jae si_next
    mov byte ptr [r15 + r14], al
    inc r14
si_next:
    call adv
    jmp si_loop
si_done:
    mov qword ptr [rip + ident_len], r14
    ret

# rcx = literal cstr -> eax = 1 if equal to ident_buf
ident_eq:
    mov r8, rcx
    mov r9, qword ptr [rip + ident_len]
    lea r10, [rip + ident_buf]
    xor r11, r11
ie_loop:
    cmp r11, r9
    jae ie_tail
    mov al, byte ptr [r8 + r11]
    test al, al
    jz ie_no
    cmp al, byte ptr [r10 + r11]
    jne ie_no
    inc r11
    jmp ie_loop
ie_tail:
    cmp byte ptr [r8 + r11], 0
    jne ie_no
    mov eax, 1
    ret
ie_no:
    xor eax, eax
    ret

emit_ident:
    lea rcx, [rip + ident_buf]
    mov rdx, qword ptr [rip + ident_len]
    call emit_bytes
    mov qword ptr [rip + prev_op], 1
    ret

skip_spaces:
ss_loop:
    call cur_ch
    cmp eax, ' '
    je ss_next
    cmp eax, 9
    je ss_next
    cmp eax, 13
    je ss_next
    cmp eax, 10
    je ss_next
    ret
ss_next:
    call adv
    jmp ss_loop

# registers the matching '>' of the '<' at current position, then skips the '<'
erase_generic:
    call skip_spaces
    call cur_ch
    cmp eax, '<'
    jne eg_done
    mov r14, qword ptr [rip + src_pos]
    mov r15, 0
eg_scan:
    mov rcx, r14
    sub rcx, qword ptr [rip + src_pos]
    call peek_at
    cmp eax, -1
    je eg_done
    cmp eax, '<'
    jne eg_chk_close
    inc r15
    jmp eg_next
eg_chk_close:
    cmp eax, '>'
    jne eg_next
    dec r15
    test r15, r15
    jz eg_found
eg_next:
    inc r14
    jmp eg_scan
eg_found:
    mov r10, qword ptr [rip + erase_sp]
    cmp r10, 60
    jae eg_done
    lea r11, [rip + erase_stack]
    mov qword ptr [r11 + r10 * 8], r14
    inc r10
    mov qword ptr [rip + erase_sp], r10
    call adv
eg_done:
    ret

skip_balanced_paren:
    call skip_spaces
    call cur_ch
    cmp eax, '('
    jne sbp_done
    mov r15, 0
sbp_loop:
    call cur_ch
    cmp eax, -1
    je sbp_done
    cmp eax, '('
    jne sbp_chk
    inc r15
    jmp sbp_next
sbp_chk:
    cmp eax, ')'
    jne sbp_next
    dec r15
    test r15, r15
    jnz sbp_next
    call adv
    ret
sbp_next:
    call adv
    jmp sbp_loop
sbp_done:
    ret

skip_balanced_angle:
    call skip_spaces
    call cur_ch
    cmp eax, '<'
    jne sba_done
    mov r15, 0
sba_loop:
    call cur_ch
    cmp eax, -1
    je sba_done
    cmp eax, '<'
    jne sba_chk
    inc r15
    jmp sba_next
sba_chk:
    cmp eax, '>'
    jne sba_next
    dec r15
    test r15, r15
    jnz sba_next
    call adv
    ret
sba_next:
    call adv
    jmp sba_loop
sba_done:
    ret

handle_ident:
    call scan_ident

    lea rcx, [rip + kw_r]
    call ident_eq
    test eax, eax
    jz hi_not_raw
    call cur_ch
    cmp eax, '"'
    je hi_raw
    cmp eax, '#'
    je hi_raw
    jmp hi_not_raw
hi_raw:
    call copy_raw_string
    ret
hi_not_raw:

    call last_ch
    cmp eax, '.'
    jne hi_not_method

    lea rcx, [rip + kw_unwrap]
    call ident_eq
    test eax, eax
    jnz hi_unwrap
    lea rcx, [rip + kw_expect]
    call ident_eq
    test eax, eax
    jnz hi_expect
    lea rcx, [rip + kw_await]
    call ident_eq
    test eax, eax
    jnz hi_await
    jmp hi_not_method

hi_unwrap:
    call cur_ch
    cmp eax, '('
    jne hi_not_method
    call drop_last
    call skip_balanced_paren
    mov cl, '?'
    call emit_ch
    mov qword ptr [rip + prev_op], 1
    ret

hi_expect:
    call cur_ch
    cmp eax, '('
    jne hi_not_method
    call drop_last
    call skip_balanced_paren
    mov cl, '?'
    call emit_ch
    mov qword ptr [rip + prev_op], 1
    ret

hi_await:
    call drop_last
    call insert_await
    mov qword ptr [rip + prev_op], 1
    ret

hi_not_method:
    call cur_ch
    cmp eax, '!'
    jne hi_not_macro
    mov rcx, 1
    call peek_at
    cmp eax, '('
    je hi_macro
    cmp eax, '['
    je hi_macro
    cmp eax, '{'
    je hi_macro
    jmp hi_not_macro
hi_macro:
    call handle_macro
    ret

hi_not_macro:
    call handle_keyword
    test eax, eax
    jnz hi_done
    call handle_rename
hi_done:
    ret

insert_await:
    mov r14, qword ptr [rip + rhs_start]
    mov r15, qword ptr [rip + line_len]
    lea r11, [rip + line_buf]
ia_skip_sp:
    cmp r14, r15
    jae ia_have
    cmp byte ptr [r11 + r14], ' '
    jne ia_have
    inc r14
    jmp ia_skip_sp
ia_have:
    cmp r14, r15
    ja ia_done
    mov r10, r15
    add r10, 6
    cmp r10, LINE_MAX
    jae ia_done
    lea r11, [rip + line_buf]
ia_shift:
    cmp r15, r14
    jbe ia_write
    dec r15
    mov al, byte ptr [r11 + r15]
    mov byte ptr [r11 + r15 + 6], al
    jmp ia_shift
ia_write:
    mov byte ptr [r11 + r14 + 0], 'a'
    mov byte ptr [r11 + r14 + 1], 'w'
    mov byte ptr [r11 + r14 + 2], 'a'
    mov byte ptr [r11 + r14 + 3], 'i'
    mov byte ptr [r11 + r14 + 4], 't'
    mov byte ptr [r11 + r14 + 5], ' '
    mov r10, qword ptr [rip + line_len]
    add r10, 6
    mov qword ptr [rip + line_len], r10
ia_done:
    ret

# -> eax = 1 when the identifier was a handled keyword
handle_keyword:
    lea rcx, [rip + kw_fn]
    call ident_eq
    test eax, eax
    jnz hk_fn
    lea rcx, [rip + kw_let]
    call ident_eq
    test eax, eax
    jnz hk_let
    lea rcx, [rip + kw_mut]
    call ident_eq
    test eax, eax
    jnz hk_mut
    lea rcx, [rip + kw_pub]
    call ident_eq
    test eax, eax
    jnz hk_pub
    lea rcx, [rip + kw_dyn]
    call ident_eq
    test eax, eax
    jnz hk_skip
    lea rcx, [rip + kw_move]
    call ident_eq
    test eax, eax
    jnz hk_skip
    lea rcx, [rip + kw_ref]
    call ident_eq
    test eax, eax
    jnz hk_ref
    lea rcx, [rip + kw_where]
    call ident_eq
    test eax, eax
    jnz hk_where
    lea rcx, [rip + kw_crate]
    call ident_eq
    test eax, eax
    jnz hk_path_root
    lea rcx, [rip + kw_super]
    call ident_eq
    test eax, eax
    jnz hk_path_root
    lea rcx, [rip + kw_impl]
    call ident_eq
    test eax, eax
    jnz hk_impl
    lea rcx, [rip + kw_trait]
    call ident_eq
    test eax, eax
    jnz hk_trait
    lea rcx, [rip + kw_mod]
    call ident_eq
    test eax, eax
    jnz hk_mod
    lea rcx, [rip + kw_struct]
    call ident_eq
    test eax, eax
    jnz hk_struct
    lea rcx, [rip + kw_union]
    call ident_eq
    test eax, eax
    jnz hk_struct
    lea rcx, [rip + kw_enum]
    call ident_eq
    test eax, eax
    jnz hk_enum
    lea rcx, [rip + kw_if]
    call ident_eq
    test eax, eax
    jnz hk_if
    lea rcx, [rip + kw_while]
    call ident_eq
    test eax, eax
    jnz hk_while
    lea rcx, [rip + kw_for]
    call ident_eq
    test eax, eax
    jnz hk_for
    lea rcx, [rip + kw_loop]
    call ident_eq
    test eax, eax
    jnz hk_loop
    lea rcx, [rip + kw_match]
    call ident_eq
    test eax, eax
    jnz hk_match
    lea rcx, [rip + kw_else]
    call ident_eq
    test eax, eax
    jnz hk_else
    lea rcx, [rip + kw_return]
    call ident_eq
    test eax, eax
    jnz hk_return
    lea rcx, [rip + kw_unsafe]
    call ident_eq
    test eax, eax
    jnz hk_unsafe
    lea rcx, [rip + kw_use]
    call ident_eq
    test eax, eax
    jnz hk_use
    lea rcx, [rip + kw_as]
    call ident_eq
    test eax, eax
    jnz hk_as
    lea rcx, [rip + kw_in]
    call ident_eq
    test eax, eax
    jnz hk_in
    xor eax, eax
    ret

hk_fn:
    mov qword ptr [rip + decl_flag], 1
    lea rcx, [rip + word_fn]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_let:
    mov qword ptr [rip + pending_let], 1
    mov eax, 1
    ret
hk_mut:
    lea rcx, [rip + word_mut]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_pub:
    call cur_ch
    cmp eax, '('
    jne hk_pub_done
    call skip_balanced_paren
hk_pub_done:
    mov eax, 1
    ret
hk_skip:
    mov eax, 1
    ret
hk_ref:
    lea rcx, [rip + word_ref]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_where:
    inc qword ptr [rip + r2h_stat_where]
hk_where_skip:
    call cur_ch
    cmp eax, -1
    je hk_where_done
    cmp eax, '{'
    je hk_where_done
    cmp eax, ';'
    je hk_where_done
    call adv
    jmp hk_where_skip
hk_where_done:
    mov eax, 1
    ret
hk_path_root:
    call cur_ch
    cmp eax, ':'
    jne hk_path_emit
    mov rcx, 1
    call peek_at
    cmp eax, ':'
    jne hk_path_emit
    call adv
    call adv
    mov eax, 1
    ret
hk_path_emit:
    call emit_ident
    mov eax, 1
    ret
hk_impl:
    mov qword ptr [rip + decl_flag], 1
    lea rcx, [rip + word_impl]
    call emit_cstr
    call skip_balanced_angle
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_trait:
    mov qword ptr [rip + decl_flag], 1
    lea rcx, [rip + word_interface]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_mod:
    mov qword ptr [rip + decl_flag], 1
    lea rcx, [rip + word_module]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_struct:
    mov qword ptr [rip + decl_flag], 1
    lea rcx, [rip + word_struct]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_enum:
    mov qword ptr [rip + decl_flag], 1
    lea rcx, [rip + word_enum]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_if:
    mov qword ptr [rip + header_flag], 1
    lea rcx, [rip + word_if]
    call emit_cstr
    call maybe_pattern_let
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_while:
    mov qword ptr [rip + header_flag], 1
    lea rcx, [rip + word_while]
    call emit_cstr
    call maybe_pattern_let
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_for:
    mov qword ptr [rip + header_flag], 1
    lea rcx, [rip + word_for]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_loop:
    mov qword ptr [rip + header_flag], 1
    lea rcx, [rip + word_whiletrue]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_match:
    mov qword ptr [rip + header_flag], 1
    lea rcx, [rip + word_match]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_else:
    lea rcx, [rip + word_else]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_return:
    lea rcx, [rip + word_return]
    call emit_cstr
    mov r10, qword ptr [rip + line_len]
    mov qword ptr [rip + rhs_start], r10
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_unsafe:
    inc qword ptr [rip + r2h_stat_unsafe]
    mov qword ptr [rip + decl_flag], 1
    lea rcx, [rip + word_unsafe]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_use:
    mov qword ptr [rip + use_flag], 1
    lea rcx, [rip + word_use]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_as:
    lea rcx, [rip + word_as]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret
hk_in:
    lea rcx, [rip + word_in]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    mov eax, 1
    ret

maybe_pattern_let:
    call skip_spaces
    call cur_ch
    cmp eax, 'l'
    jne mpl_done
    mov rcx, 1
    call peek_at
    cmp eax, 'e'
    jne mpl_done
    mov rcx, 2
    call peek_at
    cmp eax, 't'
    jne mpl_done
    mov rcx, 3
    call peek_at
    cmp eax, ' '
    jne mpl_done
    call adv
    call adv
    call adv
    inc qword ptr [rip + r2h_stat_iflet]
    call skip_spaces
    call try_unwrap_pattern
mpl_done:
    ret

try_unwrap_pattern:
    mov rax, qword ptr [rip + src_pos]
    mov qword ptr [rip + save_pos], rax
    call scan_ident
    lea rcx, [rip + pat_some]
    call ident_eq
    test eax, eax
    jnz tup_open
    lea rcx, [rip + pat_ok]
    call ident_eq
    test eax, eax
    jnz tup_open
    mov rax, qword ptr [rip + save_pos]
    mov qword ptr [rip + src_pos], rax
    ret
tup_open:
    call cur_ch
    cmp eax, '('
    jne tup_restore
    call adv
    mov qword ptr [rip + skip_paren_close], 1
    ret
tup_restore:
    mov rax, qword ptr [rip + save_pos]
    mov qword ptr [rip + src_pos], rax
    ret

handle_rename:
    lea r13, [rip + rename_table]
hr_loop:
    mov rcx, qword ptr [r13]
    test rcx, rcx
    jz hr_plain
    call ident_eq
    test eax, eax
    jnz hr_hit
    add r13, 24
    jmp hr_loop
hr_hit:
    mov rcx, qword ptr [r13 + 8]
    test rcx, rcx
    jz hr_no_text
    call emit_cstr
hr_no_text:
    mov rax, qword ptr [r13 + 16]
    test rax, rax
    jz hr_done
    call erase_generic
hr_done:
    mov qword ptr [rip + prev_op], 1
    ret
hr_plain:
    call emit_ident
    ret

# ---------------------------------------------------------------- macros

handle_macro:
    lea rcx, [rip + mac_println]
    call ident_eq
    test eax, eax
    jnz hm_print
    lea rcx, [rip + mac_print]
    call ident_eq
    test eax, eax
    jnz hm_print
    lea rcx, [rip + mac_eprintln]
    call ident_eq
    test eax, eax
    jnz hm_print
    lea rcx, [rip + mac_eprint]
    call ident_eq
    test eax, eax
    jnz hm_print
    lea rcx, [rip + mac_format]
    call ident_eq
    test eax, eax
    jnz hm_format
    lea rcx, [rip + mac_panic]
    call ident_eq
    test eax, eax
    jnz hm_panic
    lea rcx, [rip + mac_vec]
    call ident_eq
    test eax, eax
    jnz hm_vec
    lea rcx, [rip + mac_todo]
    call ident_eq
    test eax, eax
    jnz hm_todo
    lea rcx, [rip + mac_unimpl]
    call ident_eq
    test eax, eax
    jnz hm_todo
    lea rcx, [rip + mac_writeln]
    call ident_eq
    test eax, eax
    jnz hm_write
    lea rcx, [rip + mac_write]
    call ident_eq
    test eax, eax
    jnz hm_write

    inc qword ptr [rip + r2h_stat_macro]
    call emit_ident
    call adv
    mov qword ptr [rip + prev_op], 1
    ret

hm_print:
    call adv
    call capture_args
    lea rcx, [rip + word_print]
    call emit_cstr
    mov rcx, 0
    call emit_format_args
    mov cl, ')'
    call emit_ch
    mov qword ptr [rip + prev_op], 1
    ret

hm_format:
    call adv
    call capture_args
    mov rcx, 0
    call emit_format_string_only
    mov qword ptr [rip + prev_op], 1
    ret

hm_panic:
    call adv
    call capture_args
    lea rcx, [rip + word_panic]
    call emit_cstr
    mov rcx, 0
    call emit_format_args
    mov cl, ')'
    call emit_ch
    mov qword ptr [rip + prev_op], 1
    ret

hm_write:
    call adv
    call capture_args
    mov rcx, 0
    call emit_arg_raw
    lea rcx, [rip + word_write_call]
    call emit_cstr
    mov rcx, 1
    call emit_format_string_only
    mov cl, ')'
    call emit_ch
    mov qword ptr [rip + prev_op], 1
    ret

hm_vec:
    lea rcx, [rip + word_list]
    call emit_cstr
    call adv
    mov qword ptr [rip + prev_op], 1
    ret

hm_todo:
    call adv
    call capture_args
    lea rcx, [rip + word_todo]
    call emit_cstr
    mov qword ptr [rip + prev_op], 1
    ret

capture_args:
    call skip_spaces
    call cur_ch
    mov r13d, eax
    cmp eax, '('
    je ca_start
    cmp eax, '['
    je ca_start
    cmp eax, '{'
    je ca_start
    mov qword ptr [rip + tmp_len], 0
    mov qword ptr [rip + arg_count], 0
    ret
ca_start:
    call adv
    mov r15, 1
    xor r14, r14
    lea r12, [rip + tmp_buf]
ca_loop:
    call cur_ch
    cmp eax, -1
    je ca_end
    cmp eax, '"'
    je ca_string
    cmp eax, '('
    je ca_open
    cmp eax, '['
    je ca_open
    cmp eax, '{'
    je ca_open
    cmp eax, ')'
    je ca_close
    cmp eax, ']'
    je ca_close
    cmp eax, '}'
    je ca_close
    jmp ca_store
ca_open:
    inc r15
    jmp ca_store
ca_close:
    dec r15
    test r15, r15
    jz ca_fin
    jmp ca_store
ca_store:
    cmp r14, TMP_MAX
    jae ca_next
    mov byte ptr [r12 + r14], al
    inc r14
ca_next:
    call adv
    jmp ca_loop
ca_string:
    mov byte ptr [r12 + r14], al
    inc r14
    call adv
ca_str_body:
    call cur_ch
    cmp eax, -1
    je ca_end
    cmp eax, '\\'
    je ca_str_esc
    mov byte ptr [r12 + r14], al
    inc r14
    call adv
    cmp eax, '"'
    jne ca_str_body
    jmp ca_loop
ca_str_esc:
    mov byte ptr [r12 + r14], al
    inc r14
    call adv
    call cur_ch
    mov byte ptr [r12 + r14], al
    inc r14
    call adv
    jmp ca_str_body
ca_fin:
    call adv
ca_end:
    mov qword ptr [rip + tmp_len], r14
    call split_args
    ret

split_args:
    mov qword ptr [rip + arg_count], 0
    mov r14, qword ptr [rip + tmp_len]
    test r14, r14
    jz sa_done
    lea r12, [rip + tmp_buf]
    xor r13, r13
    xor r15, r15
    lea r8, [rip + arg_off]
    lea r9, [rip + arg_len]
    mov qword ptr [r8], 0
    mov r11, 0
sa_loop:
    cmp r13, r14
    jae sa_last
    movzx eax, byte ptr [r12 + r13]
    cmp eax, '"'
    je sa_string
    cmp eax, '('
    je sa_open
    cmp eax, '['
    je sa_open
    cmp eax, '<'
    je sa_open
    cmp eax, ')'
    je sa_close
    cmp eax, ']'
    je sa_close
    cmp eax, '>'
    je sa_close
    cmp eax, ','
    jne sa_next
    test r15, r15
    jnz sa_next
    mov rax, r13
    sub rax, qword ptr [r8 + r11 * 8]
    mov qword ptr [r9 + r11 * 8], rax
    inc r11
    cmp r11, 30
    jae sa_done_count
    inc r13
sa_skip_sp:
    cmp r13, r14
    jae sa_set
    movzx eax, byte ptr [r12 + r13]
    cmp eax, ' '
    jne sa_set
    inc r13
    jmp sa_skip_sp
sa_set:
    mov qword ptr [r8 + r11 * 8], r13
    jmp sa_loop
sa_open:
    inc r15
    jmp sa_next
sa_close:
    test r15, r15
    jz sa_next
    dec r15
    jmp sa_next
sa_string:
    inc r13
sa_str_body:
    cmp r13, r14
    jae sa_last
    movzx eax, byte ptr [r12 + r13]
    cmp eax, '\\'
    jne sa_str_chk
    add r13, 2
    jmp sa_str_body
sa_str_chk:
    inc r13
    cmp eax, '"'
    jne sa_str_body
    jmp sa_loop
sa_next:
    inc r13
    jmp sa_loop
sa_last:
    mov rax, r14
    sub rax, qword ptr [r8 + r11 * 8]
    mov qword ptr [r9 + r11 * 8], rax
    inc r11
sa_done_count:
    mov qword ptr [rip + arg_count], r11
sa_done:
    ret

# rcx = index -> r10 = ptr, r11 = len (0 length when missing)
get_arg:
    mov rax, qword ptr [rip + arg_count]
    cmp rcx, rax
    jae ga_none
    lea r10, [rip + arg_off]
    mov r10, qword ptr [r10 + rcx * 8]
    lea r11, [rip + arg_len]
    mov r11, qword ptr [r11 + rcx * 8]
    lea rax, [rip + tmp_buf]
    add r10, rax
    ret
ga_none:
    xor r10, r10
    xor r11, r11
    ret

# rcx = first argument index
emit_format_args:
    mov cl, '('
    call emit_ch
    mov rcx, 0
    call emit_format_string_only
    ret

# rcx = index of the format string argument
emit_format_string_only:
    mov r13, rcx
    mov rcx, r13
    call get_arg
    test r11, r11
    jz efs_empty
    cmp byte ptr [r10], '"'
    jne efs_plain

    mov r12, r13
    inc r12
    mov cl, '"'
    push r10
    push r11
    call emit_ch
    pop r11
    pop r10
    mov rbx, 1
efs_loop:
    cmp rbx, r11
    jae efs_close
    movzx eax, byte ptr [r10 + rbx]
    cmp eax, '"'
    je efs_close
    cmp eax, '{'
    je efs_brace
    cmp eax, '\\'
    je efs_escape
    mov cl, al
    push r10
    push r11
    call emit_ch
    pop r11
    pop r10
    inc rbx
    jmp efs_loop
efs_escape:
    mov cl, al
    push r10
    push r11
    call emit_ch
    pop r11
    pop r10
    inc rbx
    cmp rbx, r11
    jae efs_close
    movzx eax, byte ptr [r10 + rbx]
    mov cl, al
    push r10
    push r11
    call emit_ch
    pop r11
    pop r10
    inc rbx
    jmp efs_loop
efs_brace:
    inc rbx
    cmp rbx, r11
    jae efs_close
    movzx eax, byte ptr [r10 + rbx]
    cmp eax, '{'
    jne efs_placeholder
    mov cl, '{'
    push r10
    push r11
    call emit_ch
    pop r11
    pop r10
    inc rbx
    jmp efs_loop
efs_placeholder:
    mov r14, rbx
efs_find_end:
    cmp rbx, r11
    jae efs_close
    movzx eax, byte ptr [r10 + rbx]
    cmp eax, '}'
    je efs_have_ph
    inc rbx
    jmp efs_find_end
efs_have_ph:
    mov r15, rbx
    sub r15, r14
    inc rbx
    mov cl, '{'
    push r10
    push r11
    call emit_ch
    pop r11
    pop r10
    test r15, r15
    jz efs_positional
    movzx eax, byte ptr [r10 + r14]
    cmp eax, ':'
    je efs_positional
    push r10
    push r11
    lea rcx, [r10 + r14]
    mov rdx, r15
    call emit_named_ph
    pop r11
    pop r10
    jmp efs_ph_close
efs_positional:
    push r10
    push r11
    mov rcx, r12
    call emit_arg_converted
    pop r11
    pop r10
    inc r12
efs_ph_close:
    mov cl, '}'
    push r10
    push r11
    call emit_ch
    pop r11
    pop r10
    jmp efs_loop
efs_close:
    mov cl, '"'
    call emit_ch
    ret
efs_plain:
    mov rcx, r13
    call emit_arg_converted
    ret
efs_empty:
    lea rcx, [rip + word_empty_string]
    call emit_cstr
    ret

# rcx = ptr, rdx = len ; keeps the name, drops any format spec
emit_named_ph:
    mov r8, rcx
    mov r9, rdx
    xor r10, r10
enp_loop:
    cmp r10, r9
    jae enp_done
    movzx eax, byte ptr [r8 + r10]
    cmp eax, ':'
    je enp_done
    mov cl, al
    push r8
    push r9
    push r10
    call emit_ch
    pop r10
    pop r9
    pop r8
    inc r10
    jmp enp_loop
enp_done:
    ret

# rcx = argument index
emit_arg_converted:
    call get_arg
    test r11, r11
    jz eac_done
    xor r13, r13
eac_loop:
    cmp r13, r11
    jae eac_done
    movzx eax, byte ptr [r10 + r13]
    cmp eax, '&'
    je eac_skip
    cmp eax, ':'
    jne eac_emit
    mov r14, r13
    inc r14
    cmp r14, r11
    jae eac_emit
    movzx eax, byte ptr [r10 + r14]
    cmp eax, ':'
    jne eac_emit_colon
    mov cl, '.'
    push r10
    push r11
    push r13
    call emit_ch
    pop r13
    pop r11
    pop r10
    add r13, 2
    jmp eac_loop
eac_emit_colon:
    mov eax, ':'
eac_emit:
    mov cl, al
    push r10
    push r11
    push r13
    call emit_ch
    pop r13
    pop r11
    pop r10
eac_skip:
    inc r13
    jmp eac_loop
eac_done:
    ret

# rcx = argument index, raw copy
emit_arg_raw:
    call get_arg
    test r11, r11
    jz ear_done
    mov rcx, r10
    mov rdx, r11
    call emit_bytes
ear_done:
    ret

# ---------------------------------------------------------------- punctuation

handle_punct:
    call cur_ch
    mov r13d, eax

    cmp eax, ':'
    je hp_colon
    cmp eax, '&'
    je hp_amp
    cmp eax, '|'
    je hp_pipe
    cmp eax, '!'
    je hp_bang
    cmp eax, ';'
    je hp_semi
    cmp eax, ','
    je hp_comma
    cmp eax, '{'
    je hp_open_brace
    cmp eax, '}'
    je hp_close_brace
    cmp eax, '('
    je hp_open_paren
    cmp eax, ')'
    je hp_close_paren
    cmp eax, '['
    je hp_open_bracket
    cmp eax, ']'
    je hp_close_bracket
    cmp eax, '#'
    je hp_hash
    cmp eax, '='
    je hp_equal
    cmp eax, '-'
    je hp_minus
    cmp eax, '<'
    je hp_lt
    cmp eax, '>'
    je hp_gt

    mov cl, al
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 0
    ret

hp_lt:
    call last_ch
    push rax
    call is_ident_ch
    test eax, eax
    pop rax
    jnz hp_lt_open
    cmp eax, '>'
    je hp_lt_open
    jmp hp_lt_emit
hp_lt_open:
    inc qword ptr [rip + angle_depth]
hp_lt_emit:
    mov cl, '<'
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 0
    ret

hp_gt:
    mov rax, qword ptr [rip + angle_depth]
    test rax, rax
    jz hp_gt_emit
    dec rax
    mov qword ptr [rip + angle_depth], rax
hp_gt_emit:
    mov cl, '>'
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 1
    ret

hp_colon:
    mov rcx, 1
    call peek_at
    cmp eax, ':'
    je hp_path
    mov cl, ':'
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 0
    ret
hp_path:
    call adv
    call adv
    call cur_ch
    cmp eax, '<'
    je hp_turbofish
    call last_ch
    cmp eax, ' '
    je hp_path_emit
    cmp eax, -1
    je hp_path_emit
    mov cl, '.'
    call emit_ch
hp_path_emit:
    mov qword ptr [rip + prev_op], 0
    ret
hp_turbofish:
    mov qword ptr [rip + prev_op], 0
    ret

hp_amp:
    mov rcx, 1
    call peek_at
    cmp eax, '&'
    je hp_and_and
    mov rax, qword ptr [rip + prev_op]
    test rax, rax
    jnz hp_amp_plain
    call adv
    call skip_spaces
    call try_mut_after_amp
    test eax, eax
    jnz hp_amp_done
    lea rcx, [rip + word_ref]
    call emit_cstr
hp_amp_done:
    mov qword ptr [rip + prev_op], 0
    ret
hp_amp_plain:
    mov cl, '&'
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 0
    ret
hp_and_and:
    mov rax, qword ptr [rip + prev_op]
    test rax, rax
    jz hp_double_ref
    call adv
    call adv
    lea rcx, [rip + word_and]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    ret
hp_double_ref:
    call adv
    call adv
    lea rcx, [rip + word_ref]
    call emit_cstr
    lea rcx, [rip + word_ref]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    ret

try_mut_after_amp:
    call cur_ch
    cmp eax, 'm'
    jne tmaa_no
    mov rcx, 1
    call peek_at
    cmp eax, 'u'
    jne tmaa_no
    mov rcx, 2
    call peek_at
    cmp eax, 't'
    jne tmaa_no
    mov rcx, 3
    call peek_at
    cmp eax, ' '
    jne tmaa_no
    call adv
    call adv
    call adv
    call skip_spaces
    lea rcx, [rip + word_mut_ref]
    call emit_cstr
    mov eax, 1
    ret
tmaa_no:
    xor eax, eax
    ret

hp_pipe:
    mov rcx, 1
    call peek_at
    cmp eax, '|'
    je hp_or_or
    inc qword ptr [rip + r2h_stat_closure]
    mov cl, '|'
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 0
    ret
hp_or_or:
    mov rax, qword ptr [rip + prev_op]
    test rax, rax
    jz hp_empty_closure
    call adv
    call adv
    lea rcx, [rip + word_or]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    ret
hp_empty_closure:
    inc qword ptr [rip + r2h_stat_closure]
    mov cl, '|'
    call emit_ch
    mov cl, '|'
    call emit_ch
    call adv
    call adv
    mov qword ptr [rip + prev_op], 0
    ret

hp_bang:
    mov rcx, 1
    call peek_at
    cmp eax, '='
    je hp_bang_eq
    mov rax, qword ptr [rip + prev_op]
    test rax, rax
    jnz hp_bang_plain
    call adv
    lea rcx, [rip + word_not]
    call emit_cstr
    mov qword ptr [rip + prev_op], 0
    ret
hp_bang_plain:
    mov cl, '!'
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 0
    ret
hp_bang_eq:
    mov cl, '!'
    call emit_ch
    mov cl, '='
    call emit_ch
    call adv
    call adv
    mov qword ptr [rip + prev_op], 0
    ret

hp_semi:
    call adv
    call expand_use_line
    call flush_line
    mov qword ptr [rip + prev_op], 0
    mov qword ptr [rip + pending_let], 0
    mov qword ptr [rip + decl_flag], 0
    mov qword ptr [rip + header_flag], 0
    mov qword ptr [rip + use_flag], 0
    ret

hp_comma:
    call adv
    mov rax, qword ptr [rip + paren_depth]
    test rax, rax
    jnz hp_comma_inline
    mov rax, qword ptr [rip + angle_depth]
    test rax, rax
    jnz hp_comma_inline
    call top_kind
    cmp eax, 0
    jne hp_comma_inline
    call flush_line
    mov qword ptr [rip + prev_op], 0
    ret
hp_comma_inline:
    mov cl, ','
    call emit_ch
    mov cl, ' '
    call emit_ch
    mov qword ptr [rip + prev_op], 0
    ret

hp_open_brace:
    call adv
    call classify_brace
    test eax, eax
    jz hp_brace_inline
    call rewrite_header
    call flush_line
    mov cl, 0
    call push_kind
    inc qword ptr [rip + indent]
    mov qword ptr [rip + prev_op], 0
    mov qword ptr [rip + decl_flag], 0
    mov qword ptr [rip + header_flag], 0
    mov qword ptr [rip + pending_let], 0
    ret
hp_brace_inline:
    call last_ch
    cmp eax, ' '
    je hp_brace_write
    cmp eax, -1
    je hp_brace_write
    mov cl, ' '
    call emit_ch
hp_brace_write:
    mov cl, '{'
    call emit_ch
    mov cl, ' '
    call emit_ch
    mov cl, 1
    call push_kind
    mov qword ptr [rip + prev_op], 0
    ret

hp_close_brace:
    call adv
    call pop_kind
    cmp eax, 0
    jne hp_close_inline
    call flush_line
    mov rax, qword ptr [rip + indent]
    test rax, rax
    jz hp_close_no_dec
    dec rax
    mov qword ptr [rip + indent], rax
hp_close_no_dec:
    call lookahead_else
    test eax, eax
    jnz hp_close_else
    lea rcx, [rip + word_end]
    call emit_cstr
    call flush_line
    mov qword ptr [rip + prev_op], 0
    ret
hp_close_else:
    lea rcx, [rip + word_else]
    call emit_cstr
    mov cl, ' '
    call emit_ch
    mov qword ptr [rip + prev_op], 0
    ret

lookahead_else:
    mov r14, qword ptr [rip + src_pos]
la_skip:
    call cur_ch
    cmp eax, ' '
    je la_next
    cmp eax, 9
    je la_next
    cmp eax, 13
    je la_next
    cmp eax, 10
    je la_next
    jmp la_word
la_next:
    call adv
    jmp la_skip
la_word:
    mov rcx, 0
    call peek_at
    cmp eax, 'e'
    jne la_no
    mov rcx, 1
    call peek_at
    cmp eax, 'l'
    jne la_no
    mov rcx, 2
    call peek_at
    cmp eax, 's'
    jne la_no
    mov rcx, 3
    call peek_at
    cmp eax, 'e'
    jne la_no
    mov rcx, 4
    call peek_at
    push rax
    call is_ident_ch
    test eax, eax
    pop rax
    jnz la_no
    call adv
    call adv
    call adv
    call adv
    mov eax, 1
    ret
la_no:
    mov qword ptr [rip + src_pos], r14
    xor eax, eax
    ret
hp_close_inline:
    call last_ch
    cmp eax, ' '
    je hp_close_write
    mov cl, ' '
    call emit_ch
hp_close_write:
    mov cl, '}'
    call emit_ch
    mov qword ptr [rip + prev_op], 1
    ret

hp_open_paren:
    mov rcx, 1
    call peek_at
    cmp eax, ')'
    jne hp_paren_normal
    call last_ch
    cmp eax, '>'
    je hp_unit
    cmp eax, '<'
    je hp_unit
    cmp eax, ','
    je hp_unit
    cmp eax, '('
    je hp_drop_unit
    cmp eax, ' '
    je hp_check_arrow
    jmp hp_paren_normal
hp_check_arrow:
    mov r14, qword ptr [rip + line_len]
    cmp r14, 3
    jb hp_paren_normal
    lea r15, [rip + line_buf]
    movzx eax, byte ptr [r15 + r14 - 2]
    cmp eax, '>'
    je hp_unit
    cmp eax, ','
    je hp_unit
    jmp hp_paren_normal
hp_drop_unit:
    call adv
    call adv
    mov qword ptr [rip + prev_op], 1
    ret
hp_unit:
    call adv
    call adv
    lea rcx, [rip + word_void]
    call emit_cstr
    mov qword ptr [rip + prev_op], 1
    ret
hp_paren_normal:
    call adv
    mov cl, '('
    call emit_ch
    inc qword ptr [rip + paren_depth]
    mov qword ptr [rip + prev_op], 0
    ret

hp_close_paren:
    call adv
    mov rax, qword ptr [rip + skip_paren_close]
    test rax, rax
    jz hp_close_paren_emit
    mov qword ptr [rip + skip_paren_close], 0
    mov qword ptr [rip + prev_op], 1
    ret
hp_close_paren_emit:
    mov cl, ')'
    call emit_ch
    mov rax, qword ptr [rip + paren_depth]
    test rax, rax
    jz hp_close_paren_done
    dec rax
    mov qword ptr [rip + paren_depth], rax
hp_close_paren_done:
    mov qword ptr [rip + prev_op], 1
    ret

hp_open_bracket:
    call adv
    mov cl, '['
    call emit_ch
    inc qword ptr [rip + paren_depth]
    mov qword ptr [rip + prev_op], 0
    ret

hp_close_bracket:
    call adv
    mov cl, ']'
    call emit_ch
    mov rax, qword ptr [rip + paren_depth]
    test rax, rax
    jz hp_close_bracket_done
    dec rax
    mov qword ptr [rip + paren_depth], rax
hp_close_bracket_done:
    mov qword ptr [rip + prev_op], 1
    ret

hp_equal:
    mov cl, '='
    call emit_ch
    call adv
    call cur_ch
    cmp eax, '='
    je hp_equal_eq
    cmp eax, '>'
    je hp_arrow
    mov r10, qword ptr [rip + line_len]
    mov qword ptr [rip + rhs_start], r10
    mov qword ptr [rip + prev_op], 0
    ret
hp_equal_eq:
    mov cl, '='
    call emit_ch
    call adv
    mov qword ptr [rip + prev_op], 0
    ret
hp_arrow:
    mov cl, '>'
    call emit_ch
    call adv
    mov r10, qword ptr [rip + line_len]
    mov qword ptr [rip + rhs_start], r10
    mov qword ptr [rip + prev_op], 0
    ret

hp_minus:
    mov cl, '-'
    call emit_ch
    call adv
    call cur_ch
    cmp eax, '>'
    jne hp_minus_done
    mov cl, '>'
    call emit_ch
    call adv
hp_minus_done:
    mov qword ptr [rip + prev_op], 0
    ret

hp_hash:
    call adv
    call cur_ch
    cmp eax, '!'
    je hp_inner_attr
    cmp eax, '['
    jne hp_hash_done
    call flush_line
    call adv
    mov cl, '@'
    call emit_ch
    mov r15, 1
hp_attr_loop:
    call cur_ch
    cmp eax, -1
    je hp_attr_end
    cmp eax, '['
    jne hp_attr_chk
    inc r15
    jmp hp_attr_emit
hp_attr_chk:
    cmp eax, ']'
    jne hp_attr_emit
    dec r15
    test r15, r15
    jz hp_attr_fin
hp_attr_emit:
    mov cl, al
    call emit_ch
    call adv
    jmp hp_attr_loop
hp_attr_fin:
    call adv
hp_attr_end:
    call flush_line
    mov qword ptr [rip + prev_op], 0
    ret
hp_inner_attr:
    call adv
    call cur_ch
    cmp eax, '['
    jne hp_hash_done
    call adv
    mov r15, 1
hp_inner_loop:
    call cur_ch
    cmp eax, -1
    je hp_hash_done
    cmp eax, '['
    jne hp_inner_chk
    inc r15
    jmp hp_inner_next
hp_inner_chk:
    cmp eax, ']'
    jne hp_inner_next
    dec r15
    test r15, r15
    jz hp_inner_fin
hp_inner_next:
    call adv
    jmp hp_inner_loop
hp_inner_fin:
    call adv
hp_hash_done:
    mov qword ptr [rip + prev_op], 0
    ret

# -> eax = 1 for a block brace, 0 for an inline brace
classify_brace:
    mov rax, qword ptr [rip + use_flag]
    test rax, rax
    jnz cb_inline
    mov rax, qword ptr [rip + header_flag]
    test rax, rax
    jnz cb_block
    mov rax, qword ptr [rip + decl_flag]
    test rax, rax
    jnz cb_block
    call last_ch
    cmp eax, ')'
    je cb_block
    cmp eax, '|'
    je cb_inline
    cmp eax, '>'
    je cb_check_arrow
    mov rax, qword ptr [rip + prev_op]
    test rax, rax
    jnz cb_inline
cb_block:
    mov eax, 1
    ret
cb_inline:
    xor eax, eax
    ret
cb_check_arrow:
    mov r14, qword ptr [rip + line_len]
    cmp r14, 2
    jb cb_inline
    lea r15, [rip + line_buf]
    mov al, byte ptr [r15 + r14 - 2]
    cmp al, '='
    je cb_block
    jmp cb_inline

rewrite_header:
    lea rcx, [rip + word_impl]
    call line_starts_with
    test eax, eax
    jz rh_done
    call rewrite_impl
rh_done:
    ret

# rcx = cstr prefix -> eax = 1 when line_buf starts with it
line_starts_with:
    mov r8, rcx
    xor r9, r9
    mov r10, qword ptr [rip + line_len]
    lea r11, [rip + line_buf]
lsw_loop:
    mov al, byte ptr [r8 + r9]
    test al, al
    jz lsw_yes
    cmp r9, r10
    jae lsw_no
    cmp al, byte ptr [r11 + r9]
    jne lsw_no
    inc r9
    jmp lsw_loop
lsw_yes:
    mov eax, 1
    ret
lsw_no:
    xor eax, eax
    ret

rewrite_impl:
    mov r12, qword ptr [rip + line_len]
    lea r13, [rip + line_buf]
    mov r14, 5
    xor r15, r15
ri_find_for:
    mov rax, r14
    add rax, 5
    cmp rax, r12
    ja ri_no_for
    cmp byte ptr [r13 + r14], ' '
    jne ri_next
    cmp byte ptr [r13 + r14 + 1], 'f'
    jne ri_next
    cmp byte ptr [r13 + r14 + 2], 'o'
    jne ri_next
    cmp byte ptr [r13 + r14 + 3], 'r'
    jne ri_next
    cmp byte ptr [r13 + r14 + 4], ' '
    jne ri_next
    mov r15, r14
    jmp ri_have
ri_next:
    inc r14
    jmp ri_find_for
ri_no_for:
    lea rcx, [rip + tmp_line]
    mov rdx, 5
    mov r8, r12
    sub r8, 5
    lea r9, [rip + line_buf]
    add r9, 5
    call copy_to_tmp_line
    mov qword ptr [rip + line_len], 0
    lea rcx, [rip + word_class]
    call emit_cstr
    lea rcx, [rip + tmp_line]
    mov rdx, qword ptr [rip + tmp_line_len]
    call emit_bytes
    ret
ri_have:
    lea r9, [rip + line_buf]
    add r9, 5
    mov r8, r15
    sub r8, 5
    lea rcx, [rip + tmp_line]
    call copy_to_tmp_line
    mov r10, r15
    add r10, 5
    lea r9, [rip + line_buf]
    add r9, r10
    mov r8, r12
    sub r8, r10
    lea rcx, [rip + tmp_line2]
    call copy_to_tmp_line2
    mov qword ptr [rip + line_len], 0
    lea rcx, [rip + word_class]
    call emit_cstr
    lea rcx, [rip + tmp_line2]
    mov rdx, qword ptr [rip + tmp_line2_len]
    call emit_bytes
    lea rcx, [rip + word_implements]
    call emit_cstr
    lea rcx, [rip + tmp_line]
    mov rdx, qword ptr [rip + tmp_line_len]
    call emit_bytes
    ret

# r9 = src, r8 = len
copy_to_tmp_line:
ctl_trim:
    test r8, r8
    jz ctl_set
    mov al, byte ptr [r9 + r8 - 1]
    cmp al, ' '
    jne ctl_set
    dec r8
    jmp ctl_trim
ctl_set:
    mov qword ptr [rip + tmp_line_len], r8
    xor r10, r10
ctl_loop:
    cmp r10, r8
    jae ctl_done
    mov al, byte ptr [r9 + r10]
    lea r11, [rip + tmp_line]
    mov byte ptr [r11 + r10], al
    inc r10
    jmp ctl_loop
ctl_done:
    ret

copy_to_tmp_line2:
ctl2_trim:
    test r8, r8
    jz ctl2_set
    mov al, byte ptr [r9 + r8 - 1]
    cmp al, ' '
    jne ctl2_set
    dec r8
    jmp ctl2_trim
ctl2_set:
    mov qword ptr [rip + tmp_line2_len], r8
    xor r10, r10
ctl2_loop:
    cmp r10, r8
    jae ctl2_done
    mov al, byte ptr [r9 + r10]
    lea r11, [rip + tmp_line2]
    mov byte ptr [r11 + r10], al
    inc r10
    jmp ctl2_loop
ctl2_done:
    ret

expand_use_line:
    mov rax, qword ptr [rip + use_flag]
    test rax, rax
    jz eul_done
    mov r8, qword ptr [rip + line_len]
    lea r9, [rip + line_buf]
    call copy_to_tmp_line2
    mov r12, qword ptr [rip + tmp_line2_len]
    lea r13, [rip + tmp_line2]
    xor r14, r14
eul_find:
    cmp r14, r12
    jae eul_done
    cmp byte ptr [r13 + r14], '{'
    je eul_split
    inc r14
    jmp eul_find
eul_split:
    mov r15, r14
eul_trim:
    test r15, r15
    jz eul_prefix
    mov al, byte ptr [r13 + r15 - 1]
    cmp al, ' '
    je eul_trim_dec
    cmp al, '.'
    je eul_trim_dec
    jmp eul_prefix
eul_trim_dec:
    dec r15
    jmp eul_trim
eul_prefix:
    mov r8, r15
    mov r9, r13
    call copy_to_tmp_line
    inc r14
    mov qword ptr [rip + line_len], 0
eul_item:
    cmp r14, r12
    jae eul_done
    mov al, byte ptr [r13 + r14]
    cmp al, '}'
    je eul_done
    cmp al, ' '
    je eul_item_skip
    cmp al, ','
    je eul_item_break
    mov rax, qword ptr [rip + line_len]
    test rax, rax
    jnz eul_item_emit
    lea rcx, [rip + tmp_line]
    mov rdx, qword ptr [rip + tmp_line_len]
    call emit_bytes
    mov cl, '.'
    call emit_ch
eul_item_emit:
    mov al, byte ptr [r13 + r14]
    mov cl, al
    call emit_ch
eul_item_skip:
    inc r14
    jmp eul_item
eul_item_break:
    push r12
    push r13
    push r14
    call flush_line
    pop r14
    pop r13
    pop r12
    inc r14
    jmp eul_item
eul_done:
    ret

# ---------------------------------------------------------------- data

.section .rodata
kw_r: .asciz "r"
kw_fn: .asciz "fn"
kw_let: .asciz "let"
kw_mut: .asciz "mut"
kw_pub: .asciz "pub"
kw_dyn: .asciz "dyn"
kw_move: .asciz "move"
kw_ref: .asciz "ref"
kw_where: .asciz "where"
kw_crate: .asciz "crate"
kw_super: .asciz "super"
kw_impl: .asciz "impl"
kw_trait: .asciz "trait"
kw_mod: .asciz "mod"
kw_struct: .asciz "struct"
kw_union: .asciz "union"
kw_enum: .asciz "enum"
kw_if: .asciz "if"
kw_while: .asciz "while"
kw_for: .asciz "for"
kw_loop: .asciz "loop"
kw_match: .asciz "match"
kw_else: .asciz "else"
kw_return: .asciz "return"
kw_unsafe: .asciz "unsafe"
kw_use: .asciz "use"
kw_as: .asciz "as"
kw_in: .asciz "in"
kw_unwrap: .asciz "unwrap"
kw_expect: .asciz "expect"
kw_await: .asciz "await"

pat_some: .asciz "Some"
pat_ok: .asciz "Ok"

mac_println: .asciz "println"
mac_print: .asciz "print"
mac_eprintln: .asciz "eprintln"
mac_eprint: .asciz "eprint"
mac_format: .asciz "format"
mac_panic: .asciz "panic"
mac_vec: .asciz "vec"
mac_todo: .asciz "todo"
mac_unimpl: .asciz "unimplemented"
mac_write: .asciz "write"
mac_writeln: .asciz "writeln"

word_fn: .asciz "fn "
word_mut: .asciz "mut "
word_mut_ref: .asciz "mut ref "
word_ref: .asciz "ref "
word_impl: .asciz "impl "
word_class: .asciz "class "
word_implements: .asciz " implements "
word_interface: .asciz "interface "
word_module: .asciz "module "
word_struct: .asciz "struct "
word_enum: .asciz "enum "
word_if: .asciz "if "
word_while: .asciz "while "
word_whiletrue: .asciz "while true"
word_for: .asciz "for "
word_match: .asciz "match "
word_else: .asciz "else"
word_return: .asciz "return "
word_unsafe: .asciz "unsafe"
word_use: .asciz "use "
word_as: .asciz "as "
word_in: .asciz "in "
word_end: .asciz "end"
word_and: .asciz "and "
word_or: .asciz "or "
word_not: .asciz "not "
word_print: .asciz "print"
word_panic: .asciz "panic("
word_list: .asciz "list"
word_void: .asciz "void"
word_todo: .asciz "panic(\"not implemented\")"
word_write_call: .asciz ".write("
word_empty_string: .asciz "\"\""

rn_Vec: .asciz "Vec"
rn_list: .asciz "list"
rn_VecDeque: .asciz "VecDeque"
rn_String: .asciz "String"
rn_string: .asciz "string"
rn_str: .asciz "str"
rn_Option: .asciz "Option"
rn_optional: .asciz "optional"
rn_Result: .asciz "Result"
rn_result: .asciz "result"
rn_HashMap: .asciz "HashMap"
rn_BTreeMap: .asciz "BTreeMap"
rn_map: .asciz "map"
rn_HashSet: .asciz "HashSet"
rn_BTreeSet: .asciz "BTreeSet"
rn_set: .asciz "set"
rn_Some: .asciz "Some"
rn_some: .asciz "some"
rn_None: .asciz "None"
rn_none: .asciz "none"
rn_Ok: .asciz "Ok"
rn_ok: .asciz "ok"
rn_Err: .asciz "Err"
rn_err: .asciz "err"
rn_Box: .asciz "Box"
rn_RefCell: .asciz "RefCell"
rn_Cell: .asciz "Cell"
rn_Mutex: .asciz "Mutex"
rn_RwLock: .asciz "RwLock"
rn_Cow: .asciz "Cow"
rn_Pin: .asciz "Pin"
rn_Arc: .asciz "Arc"
rn_Rc: .asciz "Rc"
rn_shared: .asciz "shared "
rn_Weak: .asciz "Weak"
rn_weak: .asciz "weak "

.align 8
rename_table:
    .quad rn_Vec, rn_list, 0
    .quad rn_VecDeque, rn_list, 0
    .quad rn_String, rn_string, 0
    .quad rn_str, rn_string, 0
    .quad rn_Option, rn_optional, 0
    .quad rn_Result, rn_result, 0
    .quad rn_HashMap, rn_map, 0
    .quad rn_BTreeMap, rn_map, 0
    .quad rn_HashSet, rn_set, 0
    .quad rn_BTreeSet, rn_set, 0
    .quad rn_Some, rn_some, 0
    .quad rn_None, rn_none, 0
    .quad rn_Ok, rn_ok, 0
    .quad rn_Err, rn_err, 0
    .quad rn_Box, 0, 1
    .quad rn_RefCell, 0, 1
    .quad rn_Cell, 0, 1
    .quad rn_Mutex, 0, 1
    .quad rn_RwLock, 0, 1
    .quad rn_Cow, 0, 1
    .quad rn_Pin, 0, 1
    .quad rn_Arc, rn_shared, 1
    .quad rn_Rc, rn_shared, 1
    .quad rn_Weak, rn_weak, 1
    .quad 0, 0, 0

sfx_usize: .asciz "usize"
sfx_isize: .asciz "isize"
sfx_u8: .asciz "u8"
sfx_u16: .asciz "u16"
sfx_u32: .asciz "u32"
sfx_u64: .asciz "u64"
sfx_i8: .asciz "i8"
sfx_i16: .asciz "i16"
sfx_i32: .asciz "i32"
sfx_i64: .asciz "i64"
sfx_f32: .asciz "f32"
sfx_f64: .asciz "f64"

.bss
.align 8
src_ptr: .space 8
src_len: .space 8
src_pos: .space 8
out_ptr: .space 8
out_cap: .space 8
out_len: .space 8
line_len: .space 8
stack_sp: .space 8
indent: .space 8
prev_op: .space 8
header_flag: .space 8
decl_flag: .space 8
pending_let: .space 8
paren_depth: .space 8
rhs_start: .space 8
erase_sp: .space 8
iflet_flag: .space 8
angle_depth: .space 8
save_pos: .space 8
fn_flag: .space 8
use_flag: .space 8
skip_paren_close: .space 8
ident_len: .space 8
tmp_len: .space 8
arg_count: .space 8
tmp_line_len: .space 8
tmp_line2_len: .space 8
r2h_stat_lifetime: .space 8
r2h_stat_where: .space 8
r2h_stat_macro: .space 8
r2h_stat_iflet: .space 8
r2h_stat_closure: .space 8
r2h_stat_unsafe: .space 8
erase_stack: .space 512
arg_off: .space 256
arg_len: .space 256
ident_buf: .space 256
stack_buf: .space 4096
line_buf: .space 262144
tmp_line: .space 262144
tmp_line2: .space 262144
tmp_buf: .space 262144
