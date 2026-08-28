.intel_syntax noprefix

# Hust Studio 0.8.1
# Native Win32 IDE shell written directly in x86-64 HAsm.  It does not host the
# Hust VM and it is not a renamed console bootstrap: the executable owns a real
# Win32 window, editor control, file dialogs, file I/O and Run integration.

.extern __imp_GetModuleHandleA
.extern __imp_ExitProcess
.extern __imp_CreateFileA
.extern __imp_ReadFile
.extern __imp_WriteFile
.extern __imp_CloseHandle
.extern __imp_GetFileSize
.extern __imp_RegisterClassExA
.extern __imp_CreateWindowExA
.extern __imp_DefWindowProcA
.extern __imp_ShowWindow
.extern __imp_UpdateWindow
.extern __imp_GetMessageA
.extern __imp_TranslateMessage
.extern __imp_DispatchMessageA
.extern __imp_PostQuitMessage
.extern __imp_DestroyWindow
.extern __imp_LoadCursorA
.extern __imp_LoadImageA
.extern __imp_MessageBoxA
.extern __imp_SendMessageA
.extern __imp_MoveWindow
.extern __imp_GetWindowTextLengthA
.extern __imp_GetWindowTextA
.extern __imp_SetWindowTextA
.extern __imp_SetFocus
.extern __imp_GetOpenFileNameA
.extern __imp_GetSaveFileNameA
.extern __imp_GetStockObject
.extern __imp_ShellExecuteA

.equ WM_CREATE, 0x0001
.equ WM_DESTROY, 0x0002
.equ WM_SIZE, 0x0005
.equ WM_CLOSE, 0x0010
.equ WM_COMMAND, 0x0111
.equ WM_SETFONT, 0x0030
.equ EM_SETLIMITTEXT, 0x00c5
.equ SW_SHOW, 5
.equ SW_SHOWNORMAL, 1
.equ IMAGE_ICON, 1
.equ LR_LOADFROMFILE, 0x0010
.equ WS_OVERLAPPEDWINDOW, 0x00cf0000
.equ WS_CLIPCHILDREN, 0x02000000
.equ WS_CHILD_VISIBLE, 0x50000000
.equ EDIT_STYLE, 0x50b010c4
.equ WS_EX_CLIENTEDGE, 0x00000200
.equ GENERIC_READ, 0x80000000
.equ GENERIC_WRITE, 0x40000000
.equ FILE_SHARE_READ, 1
.equ OPEN_EXISTING, 3
.equ CREATE_ALWAYS, 2
.equ FILE_ATTRIBUTE_NORMAL, 0x80
.equ INVALID_HANDLE_VALUE, -1
.equ ID_NEW, 1001
.equ ID_OPEN, 1002
.equ ID_SAVE, 1003
.equ ID_RUN, 1004
.equ EDIT_LIMIT, 1048575

.section .text,"xr"
.globl _start
_start:
    sub rsp, 216
    xor ecx, ecx
    call qword ptr [rip + __imp_GetModuleHandleA]
    mov qword ptr [rip + app_instance], rax

    # Load the packaged Hust brand icon.  Failure is non-fatal; Windows falls back
    # to its default application icon if the asset was moved away from the EXE.
    xor ecx, ecx
    lea rdx, [rip + logo_icon_path]
    mov r8d, IMAGE_ICON
    mov r9d, 64
    mov qword ptr [rsp + 32], 64
    mov qword ptr [rsp + 40], LR_LOADFROMFILE
    call qword ptr [rip + __imp_LoadImageA]
    mov qword ptr [rip + app_icon], rax

    xor ecx, ecx
    mov edx, 32512                    # IDC_ARROW
    call qword ptr [rip + __imp_LoadCursorA]
    mov qword ptr [rip + arrow_cursor], rax

    # WNDCLASSEXA (80 bytes)
    lea rdi, [rip + wndclass]
    xor eax, eax
    mov ecx, 10
    rep stosq
    lea rdi, [rip + wndclass]
    mov dword ptr [rdi], 80
    mov dword ptr [rdi + 4], 0x0003   # CS_VREDRAW | CS_HREDRAW
    lea rax, [rip + window_proc]
    mov qword ptr [rdi + 8], rax
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rdi + 24], rax
    mov rax, qword ptr [rip + app_icon]
    mov qword ptr [rdi + 32], rax
    mov qword ptr [rdi + 72], rax
    mov rax, qword ptr [rip + arrow_cursor]
    mov qword ptr [rdi + 40], rax
    mov qword ptr [rdi + 48], 6       # COLOR_WINDOW + 1 brush pseudo-handle
    lea rax, [rip + class_name]
    mov qword ptr [rdi + 64], rax
    mov rcx, rdi
    call qword ptr [rip + __imp_RegisterClassExA]
    test ax, ax
    jz .fatal

    # Create main window.
    xor ecx, ecx
    lea rdx, [rip + class_name]
    lea r8, [rip + window_title]
    mov r9d, WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN
    mov eax, 0x80000000
    mov qword ptr [rsp + 32], rax
    mov qword ptr [rsp + 40], rax
    mov qword ptr [rsp + 48], 1100
    mov qword ptr [rsp + 56], 760
    mov qword ptr [rsp + 64], 0
    mov qword ptr [rsp + 72], 0
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rsp + 80], rax
    mov qword ptr [rsp + 88], 0
    call qword ptr [rip + __imp_CreateWindowExA]
    test rax, rax
    jz .fatal
    mov qword ptr [rip + main_window], rax

    mov rcx, rax
    mov edx, SW_SHOW
    call qword ptr [rip + __imp_ShowWindow]
    mov rcx, qword ptr [rip + main_window]
    call qword ptr [rip + __imp_UpdateWindow]

.msg_loop:
    lea rcx, [rip + msg_buffer]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call qword ptr [rip + __imp_GetMessageA]
    test eax, eax
    jle .quit
    lea rcx, [rip + msg_buffer]
    call qword ptr [rip + __imp_TranslateMessage]
    lea rcx, [rip + msg_buffer]
    call qword ptr [rip + __imp_DispatchMessageA]
    jmp .msg_loop

.quit:
    mov ecx, dword ptr [rip + msg_buffer + 16]
    call qword ptr [rip + __imp_ExitProcess]
.fatal:
    xor ecx, ecx
    lea rdx, [rip + fatal_text]
    lea r8, [rip + window_title]
    mov r9d, 0x10
    call qword ptr [rip + __imp_MessageBoxA]
    mov ecx, 1
    call qword ptr [rip + __imp_ExitProcess]

# LRESULT CALLBACK WindowProc(HWND, UINT, WPARAM, LPARAM)
window_proc:
    push rbx
    push rsi
    push rdi
    sub rsp, 96
    mov qword ptr [rsp + 32], rcx
    mov dword ptr [rsp + 40], edx
    mov qword ptr [rsp + 48], r8
    mov qword ptr [rsp + 56], r9
    mov rbx, rcx
    mov esi, edx

    cmp esi, WM_CREATE
    je .wp_create
    cmp esi, WM_SIZE
    je .wp_size
    cmp esi, WM_COMMAND
    je .wp_command
    cmp esi, WM_CLOSE
    je .wp_close
    cmp esi, WM_DESTROY
    je .wp_destroy
    jmp .wp_default

.wp_create:
    mov rcx, rbx
    call create_controls
    xor eax, eax
    jmp .wp_done

.wp_size:
    mov eax, dword ptr [rsp + 56]
    mov ecx, eax
    and ecx, 0xffff                   # width
    shr eax, 16
    and eax, 0xffff                   # height
    mov edx, eax
    mov rcx, rbx
    call layout_controls
    xor eax, eax
    jmp .wp_done

.wp_command:
    mov eax, dword ptr [rsp + 48]
    and eax, 0xffff
    cmp eax, ID_NEW
    je .wp_new
    cmp eax, ID_OPEN
    je .wp_open
    cmp eax, ID_SAVE
    je .wp_save
    cmp eax, ID_RUN
    je .wp_run
    xor eax, eax
    jmp .wp_done
.wp_new:
    call action_new
    xor eax, eax
    jmp .wp_done
.wp_open:
    mov rcx, rbx
    call action_open
    xor eax, eax
    jmp .wp_done
.wp_save:
    mov rcx, rbx
    call action_save
    xor eax, eax
    jmp .wp_done
.wp_run:
    mov rcx, rbx
    call action_run
    xor eax, eax
    jmp .wp_done

.wp_close:
    mov rcx, rbx
    call qword ptr [rip + __imp_DestroyWindow]
    xor eax, eax
    jmp .wp_done
.wp_destroy:
    xor ecx, ecx
    call qword ptr [rip + __imp_PostQuitMessage]
    xor eax, eax
    jmp .wp_done

.wp_default:
    mov rcx, qword ptr [rsp + 32]
    mov edx, dword ptr [rsp + 40]
    mov r8, qword ptr [rsp + 48]
    mov r9, qword ptr [rsp + 56]
    call qword ptr [rip + __imp_DefWindowProcA]
.wp_done:
    add rsp, 96
    pop rdi
    pop rsi
    pop rbx
    ret

# RCX=main window
create_controls:
    push rbx
    push rsi
    sub rsp, 104
    mov rbx, rcx

    # Shared stock UI font.
    mov ecx, 17                       # DEFAULT_GUI_FONT
    call qword ptr [rip + __imp_GetStockObject]
    mov qword ptr [rip + ui_font], rax

    # New
    xor ecx, ecx
    lea rdx, [rip + button_class]
    lea r8, [rip + text_new]
    mov r9d, WS_CHILD_VISIBLE
    mov qword ptr [rsp + 32], 10
    mov qword ptr [rsp + 40], 10
    mov qword ptr [rsp + 48], 82
    mov qword ptr [rsp + 56], 30
    mov qword ptr [rsp + 64], rbx
    mov qword ptr [rsp + 72], ID_NEW
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rsp + 80], rax
    mov qword ptr [rsp + 88], 0
    call qword ptr [rip + __imp_CreateWindowExA]
    mov qword ptr [rip + btn_new], rax

    # Open
    xor ecx, ecx
    lea rdx, [rip + button_class]
    lea r8, [rip + text_open]
    mov r9d, WS_CHILD_VISIBLE
    mov qword ptr [rsp + 32], 100
    mov qword ptr [rsp + 40], 10
    mov qword ptr [rsp + 48], 82
    mov qword ptr [rsp + 56], 30
    mov qword ptr [rsp + 64], rbx
    mov qword ptr [rsp + 72], ID_OPEN
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rsp + 80], rax
    mov qword ptr [rsp + 88], 0
    call qword ptr [rip + __imp_CreateWindowExA]
    mov qword ptr [rip + btn_open], rax

    # Save
    xor ecx, ecx
    lea rdx, [rip + button_class]
    lea r8, [rip + text_save]
    mov r9d, WS_CHILD_VISIBLE
    mov qword ptr [rsp + 32], 190
    mov qword ptr [rsp + 40], 10
    mov qword ptr [rsp + 48], 82
    mov qword ptr [rsp + 56], 30
    mov qword ptr [rsp + 64], rbx
    mov qword ptr [rsp + 72], ID_SAVE
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rsp + 80], rax
    mov qword ptr [rsp + 88], 0
    call qword ptr [rip + __imp_CreateWindowExA]
    mov qword ptr [rip + btn_save], rax

    # Run
    xor ecx, ecx
    lea rdx, [rip + button_class]
    lea r8, [rip + text_run]
    mov r9d, WS_CHILD_VISIBLE
    mov qword ptr [rsp + 32], 280
    mov qword ptr [rsp + 40], 10
    mov qword ptr [rsp + 48], 82
    mov qword ptr [rsp + 56], 30
    mov qword ptr [rsp + 64], rbx
    mov qword ptr [rsp + 72], ID_RUN
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rsp + 80], rax
    mov qword ptr [rsp + 88], 0
    call qword ptr [rip + __imp_CreateWindowExA]
    mov qword ptr [rip + btn_run], rax

    # Editor
    mov ecx, WS_EX_CLIENTEDGE
    lea rdx, [rip + edit_class]
    xor r8d, r8d
    mov r9d, EDIT_STYLE
    mov qword ptr [rsp + 32], 10
    mov qword ptr [rsp + 40], 50
    mov qword ptr [rsp + 48], 1064
    mov qword ptr [rsp + 56], 640
    mov qword ptr [rsp + 64], rbx
    mov qword ptr [rsp + 72], 1100
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rsp + 80], rax
    mov qword ptr [rsp + 88], 0
    call qword ptr [rip + __imp_CreateWindowExA]
    mov qword ptr [rip + editor_hwnd], rax

    # Status
    xor ecx, ecx
    lea rdx, [rip + static_class]
    lea r8, [rip + status_ready]
    mov r9d, WS_CHILD_VISIBLE
    mov qword ptr [rsp + 32], 10
    mov qword ptr [rsp + 40], 698
    mov qword ptr [rsp + 48], 1064
    mov qword ptr [rsp + 56], 22
    mov qword ptr [rsp + 64], rbx
    mov qword ptr [rsp + 72], 1101
    mov rax, qword ptr [rip + app_instance]
    mov qword ptr [rsp + 80], rax
    mov qword ptr [rsp + 88], 0
    call qword ptr [rip + __imp_CreateWindowExA]
    mov qword ptr [rip + status_hwnd], rax

    # Apply stock font to all controls.
    lea rsi, [rip + btn_new]
    mov ebx, 6
.cc_font_loop:
    mov rcx, qword ptr [rsi]
    test rcx, rcx
    jz .cc_font_next
    mov edx, WM_SETFONT
    mov r8, qword ptr [rip + ui_font]
    mov r9d, 1
    call qword ptr [rip + __imp_SendMessageA]
.cc_font_next:
    add rsi, 8
    dec ebx
    jnz .cc_font_loop

    mov rcx, qword ptr [rip + editor_hwnd]
    mov edx, EM_SETLIMITTEXT
    mov r8d, EDIT_LIMIT
    xor r9d, r9d
    call qword ptr [rip + __imp_SendMessageA]
    mov rcx, qword ptr [rip + editor_hwnd]
    call qword ptr [rip + __imp_SetFocus]
    add rsp, 104
    pop rsi
    pop rbx
    ret

# RCX=main, EDX=client width, R8D=client height
layout_controls:
    push rbx
    push rsi
    push rdi
    sub rsp, 48
    mov ebx, edx
    mov esi, r8d
    sub ebx, 20
    cmp ebx, 200
    jge .lc_w_ok
    mov ebx, 200
.lc_w_ok:
    mov edi, esi
    sub edi, 82
    cmp edi, 80
    jge .lc_h_ok
    mov edi, 80
.lc_h_ok:
    mov rcx, qword ptr [rip + editor_hwnd]
    mov edx, 10
    mov r8d, 50
    mov r9d, ebx
    mov dword ptr [rsp + 32], edi
    mov dword ptr [rsp + 40], 1
    call qword ptr [rip + __imp_MoveWindow]
    mov rcx, qword ptr [rip + status_hwnd]
    mov edx, 10
    mov r8d, esi
    sub r8d, 26
    mov r9d, ebx
    mov dword ptr [rsp + 32], 22
    mov dword ptr [rsp + 40], 1
    call qword ptr [rip + __imp_MoveWindow]
    add rsp, 48
    pop rdi
    pop rsi
    pop rbx
    ret

action_new:
    sub rsp, 40
    mov byte ptr [rip + file_path], 0
    mov rcx, qword ptr [rip + editor_hwnd]
    lea rdx, [rip + empty_text]
    call qword ptr [rip + __imp_SetWindowTextA]
    mov rcx, qword ptr [rip + status_hwnd]
    lea rdx, [rip + status_new]
    call qword ptr [rip + __imp_SetWindowTextA]
    mov rcx, qword ptr [rip + editor_hwnd]
    call qword ptr [rip + __imp_SetFocus]
    add rsp, 40
    ret

# RCX owner -> EAX 1 if opened, 0 if cancelled/failed
action_open:
    push rbx
    sub rsp, 104
    mov rbx, rcx
    lea rdi, [rip + open_filename]
    xor eax, eax
    mov ecx, 19                       # 152 / 8
    rep stosq
    lea rdi, [rip + open_filename]
    mov dword ptr [rdi], 152
    mov qword ptr [rdi + 8], rbx
    lea rax, [rip + file_filter]
    mov qword ptr [rdi + 24], rax
    lea rax, [rip + file_path]
    mov qword ptr [rdi + 48], rax
    mov dword ptr [rdi + 56], 1024
    lea rax, [rip + open_title]
    mov qword ptr [rdi + 88], rax
    mov dword ptr [rdi + 96], 0x00081800
    lea rax, [rip + default_ext]
    mov qword ptr [rdi + 104], rax
    mov rcx, rdi
    call qword ptr [rip + __imp_GetOpenFileNameA]
    test eax, eax
    jz .ao_cancel

    lea rcx, [rip + file_path]
    mov edx, GENERIC_READ
    mov r8d, FILE_SHARE_READ
    xor r9d, r9d
    mov qword ptr [rsp + 32], OPEN_EXISTING
    mov qword ptr [rsp + 40], FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp + 48], 0
    call qword ptr [rip + __imp_CreateFileA]
    cmp rax, INVALID_HANDLE_VALUE
    je .ao_fail
    mov qword ptr [rip + file_handle], rax
    mov rcx, rax
    xor edx, edx
    call qword ptr [rip + __imp_GetFileSize]
    cmp eax, EDIT_LIMIT
    jbe .ao_size_ok
    mov eax, EDIT_LIMIT
.ao_size_ok:
    mov ebx, eax
    mov rcx, qword ptr [rip + file_handle]
    lea rdx, [rip + editor_buffer]
    mov r8d, ebx
    lea r9, [rip + io_count]
    mov qword ptr [rsp + 32], 0
    call qword ptr [rip + __imp_ReadFile]
    test eax, eax
    jz .ao_close_fail
    mov eax, dword ptr [rip + io_count]
    lea rdx, [rip + editor_buffer]
    mov byte ptr [rdx + rax], 0
    mov rcx, qword ptr [rip + editor_hwnd]
    call qword ptr [rip + __imp_SetWindowTextA]
    mov rcx, qword ptr [rip + file_handle]
    call qword ptr [rip + __imp_CloseHandle]
    mov rcx, qword ptr [rip + status_hwnd]
    lea rdx, [rip + status_opened]
    call qword ptr [rip + __imp_SetWindowTextA]
    mov rcx, qword ptr [rip + editor_hwnd]
    call qword ptr [rip + __imp_SetFocus]
    mov eax, 1
    jmp .ao_done
.ao_close_fail:
    mov rcx, qword ptr [rip + file_handle]
    call qword ptr [rip + __imp_CloseHandle]
.ao_fail:
    mov rcx, qword ptr [rip + main_window]
    lea rdx, [rip + file_error]
    lea r8, [rip + window_title]
    mov r9d, 0x10
    call qword ptr [rip + __imp_MessageBoxA]
.ao_cancel:
    xor eax, eax
.ao_done:
    add rsp, 104
    pop rbx
    ret

# RCX owner -> EAX 1 on success
action_save:
    push rbx
    push rsi
    sub rsp, 104
    mov rbx, rcx
    cmp byte ptr [rip + file_path], 0
    jne .as_have_path

    lea rdi, [rip + open_filename]
    xor eax, eax
    mov ecx, 19
    rep stosq
    lea rdi, [rip + open_filename]
    mov dword ptr [rdi], 152
    mov qword ptr [rdi + 8], rbx
    lea rax, [rip + file_filter]
    mov qword ptr [rdi + 24], rax
    lea rax, [rip + file_path]
    mov qword ptr [rdi + 48], rax
    mov dword ptr [rdi + 56], 1024
    lea rax, [rip + save_title]
    mov qword ptr [rdi + 88], rax
    mov dword ptr [rdi + 96], 0x00080802
    lea rax, [rip + default_ext]
    mov qword ptr [rdi + 104], rax
    mov rcx, rdi
    call qword ptr [rip + __imp_GetSaveFileNameA]
    test eax, eax
    jz .as_cancel
.as_have_path:
    mov rcx, qword ptr [rip + editor_hwnd]
    call qword ptr [rip + __imp_GetWindowTextLengthA]
    cmp eax, EDIT_LIMIT
    jbe .as_len_ok
    mov eax, EDIT_LIMIT
.as_len_ok:
    mov esi, eax
    mov rcx, qword ptr [rip + editor_hwnd]
    lea rdx, [rip + editor_buffer]
    lea r8d, [rsi + 1]
    call qword ptr [rip + __imp_GetWindowTextA]
    mov esi, eax

    lea rcx, [rip + file_path]
    mov edx, GENERIC_WRITE
    xor r8d, r8d
    xor r9d, r9d
    mov qword ptr [rsp + 32], CREATE_ALWAYS
    mov qword ptr [rsp + 40], FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp + 48], 0
    call qword ptr [rip + __imp_CreateFileA]
    cmp rax, INVALID_HANDLE_VALUE
    je .as_fail
    mov qword ptr [rip + file_handle], rax
    mov rcx, rax
    lea rdx, [rip + editor_buffer]
    mov r8d, esi
    lea r9, [rip + io_count]
    mov qword ptr [rsp + 32], 0
    call qword ptr [rip + __imp_WriteFile]
    test eax, eax
    jz .as_close_fail
    mov rcx, qword ptr [rip + file_handle]
    call qword ptr [rip + __imp_CloseHandle]
    mov rcx, qword ptr [rip + status_hwnd]
    lea rdx, [rip + status_saved]
    call qword ptr [rip + __imp_SetWindowTextA]
    mov eax, 1
    jmp .as_done
.as_close_fail:
    mov rcx, qword ptr [rip + file_handle]
    call qword ptr [rip + __imp_CloseHandle]
.as_fail:
    mov rcx, rbx
    lea rdx, [rip + file_error]
    lea r8, [rip + window_title]
    mov r9d, 0x10
    call qword ptr [rip + __imp_MessageBoxA]
.as_cancel:
    xor eax, eax
.as_done:
    add rsp, 104
    pop rsi
    pop rbx
    ret

# RCX owner
action_run:
    push rbx
    push rsi
    push rdi
    sub rsp, 72
    mov rbx, rcx
    call action_save
    test eax, eax
    jz .ar_done

    lea rdi, [rip + run_params]
    mov byte ptr [rdi], '"'
    inc rdi
    lea rsi, [rip + file_path]
.ar_copy:
    mov al, byte ptr [rsi]
    test al, al
    jz .ar_quote
    mov byte ptr [rdi], al
    inc rdi
    inc rsi
    jmp .ar_copy
.ar_quote:
    mov byte ptr [rdi], '"'
    mov byte ptr [rdi + 1], 0

    mov rcx, rbx
    lea rdx, [rip + verb_open]
    lea r8, [rip + interpreter_exe]
    lea r9, [rip + run_params]
    mov qword ptr [rsp + 32], 0
    mov qword ptr [rsp + 40], SW_SHOWNORMAL
    call qword ptr [rip + __imp_ShellExecuteA]
    cmp rax, 32
    jg .ar_ok
    mov rcx, rbx
    lea rdx, [rip + run_error]
    lea r8, [rip + window_title]
    mov r9d, 0x10
    call qword ptr [rip + __imp_MessageBoxA]
    jmp .ar_done
.ar_ok:
    mov rcx, qword ptr [rip + status_hwnd]
    lea rdx, [rip + status_running]
    call qword ptr [rip + __imp_SetWindowTextA]
.ar_done:
    add rsp, 72
    pop rdi
    pop rsi
    pop rbx
    ret

.section .rdata,"dr"
class_name: .asciz "HustStudioWindowClass072"
window_title: .asciz "Hust Studio 0.8.1 - Native HAsm IDE"
button_class: .asciz "BUTTON"
edit_class: .asciz "EDIT"
static_class: .asciz "STATIC"
text_new: .asciz "New"
text_open: .asciz "Open"
text_save: .asciz "Save"
text_run: .asciz "Run"
status_ready: .asciz "Ready - open or create a .hs file. Ctrl+S is available through the Save button in this bootstrap."
status_new: .asciz "New unsaved Hust source"
status_opened: .asciz "Hust source opened"
status_saved: .asciz "Saved"
status_running: .asciz "Saved and launched with HustInterpreter.exe"
open_title: .asciz "Open Hust source"
save_title: .asciz "Save Hust source"
default_ext: .asciz "hs"
file_filter:
    .ascii "Hust source (*.hs)\0*.hs\0All files (*.*)\0*.*\0\0"
verb_open: .asciz "open"
interpreter_exe: .asciz "HustInterpreter.exe"
logo_icon_path: .asciz "assets\\HustLogo.ico"
file_error: .asciz "Hust Studio could not read or write that file."
run_error: .asciz "HustInterpreter.exe could not be launched. Keep it next to HustStudio.exe or add Hust to PATH."
fatal_text: .asciz "Hust Studio could not create its native Win32 window."
empty_text: .asciz ""

.section .data
.p2align 3
app_instance: .quad 0
app_icon: .quad 0
arrow_cursor: .quad 0
main_window: .quad 0
# Keep the six control handles contiguous; create_controls applies the font as an array.
btn_new: .quad 0
btn_open: .quad 0
btn_save: .quad 0
btn_run: .quad 0
editor_hwnd: .quad 0
status_hwnd: .quad 0
ui_font: .quad 0
file_handle: .quad -1
io_count: .long 0
.p2align 3
wndclass: .space 80
msg_buffer: .space 48
open_filename: .space 152
file_path: .space 1024
run_params: .space 1100
editor_buffer: .space 1048576
