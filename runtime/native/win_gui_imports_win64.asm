.intel_syntax noprefix

# Hust Studio owns its Win32 import table.  No MSVC/MinGW import libraries are
# required to build the IDE bootstrap.

.section .idata$2,"dw"
.globl __IMPORT_DESCRIPTOR_KERNEL32
__IMPORT_DESCRIPTOR_KERNEL32:
 .long k32_ilt@IMGREL; .long 0; .long 0; .long k32_name@IMGREL; .long k32_iat@IMGREL
.globl __IMPORT_DESCRIPTOR_USER32
__IMPORT_DESCRIPTOR_USER32:
 .long user_ilt@IMGREL; .long 0; .long 0; .long user_name@IMGREL; .long user_iat@IMGREL
.globl __IMPORT_DESCRIPTOR_COMDLG32
__IMPORT_DESCRIPTOR_COMDLG32:
 .long comdlg_ilt@IMGREL; .long 0; .long 0; .long comdlg_name@IMGREL; .long comdlg_iat@IMGREL
.globl __IMPORT_DESCRIPTOR_GDI32
__IMPORT_DESCRIPTOR_GDI32:
 .long gdi_ilt@IMGREL; .long 0; .long 0; .long gdi_name@IMGREL; .long gdi_iat@IMGREL
.globl __IMPORT_DESCRIPTOR_SHELL32
__IMPORT_DESCRIPTOR_SHELL32:
 .long shell_ilt@IMGREL; .long 0; .long 0; .long shell_name@IMGREL; .long shell_iat@IMGREL

.section .idata$3,"dw"
 .long 0,0,0,0,0

.section .idata$4,"dw"
k32_ilt:
 .long hn_GetModuleHandleA@IMGREL; .long 0
 .long hn_ExitProcess@IMGREL; .long 0
 .long hn_CreateFileA@IMGREL; .long 0
 .long hn_ReadFile@IMGREL; .long 0
 .long hn_WriteFile@IMGREL; .long 0
 .long hn_CloseHandle@IMGREL; .long 0
 .long hn_GetFileSize@IMGREL; .long 0
 .quad 0
user_ilt:
 .long hn_RegisterClassExA@IMGREL; .long 0
 .long hn_CreateWindowExA@IMGREL; .long 0
 .long hn_DefWindowProcA@IMGREL; .long 0
 .long hn_ShowWindow@IMGREL; .long 0
 .long hn_UpdateWindow@IMGREL; .long 0
 .long hn_GetMessageA@IMGREL; .long 0
 .long hn_TranslateMessage@IMGREL; .long 0
 .long hn_DispatchMessageA@IMGREL; .long 0
 .long hn_PostQuitMessage@IMGREL; .long 0
 .long hn_DestroyWindow@IMGREL; .long 0
 .long hn_LoadCursorA@IMGREL; .long 0
 .long hn_LoadImageA@IMGREL; .long 0
 .long hn_MessageBoxA@IMGREL; .long 0
 .long hn_SendMessageA@IMGREL; .long 0
 .long hn_MoveWindow@IMGREL; .long 0
 .long hn_GetWindowTextLengthA@IMGREL; .long 0
 .long hn_GetWindowTextA@IMGREL; .long 0
 .long hn_SetWindowTextA@IMGREL; .long 0
 .long hn_SetFocus@IMGREL; .long 0
 .quad 0
comdlg_ilt:
 .long hn_GetOpenFileNameA@IMGREL; .long 0
 .long hn_GetSaveFileNameA@IMGREL; .long 0
 .quad 0
gdi_ilt:
 .long hn_GetStockObject@IMGREL; .long 0
 .quad 0
shell_ilt:
 .long hn_ShellExecuteA@IMGREL; .long 0
 .quad 0

.section .idata$5,"dw"
k32_iat:
.globl __imp_GetModuleHandleA
__imp_GetModuleHandleA: .long hn_GetModuleHandleA@IMGREL; .long 0
.globl __imp_ExitProcess
__imp_ExitProcess: .long hn_ExitProcess@IMGREL; .long 0
.globl __imp_CreateFileA
__imp_CreateFileA: .long hn_CreateFileA@IMGREL; .long 0
.globl __imp_ReadFile
__imp_ReadFile: .long hn_ReadFile@IMGREL; .long 0
.globl __imp_WriteFile
__imp_WriteFile: .long hn_WriteFile@IMGREL; .long 0
.globl __imp_CloseHandle
__imp_CloseHandle: .long hn_CloseHandle@IMGREL; .long 0
.globl __imp_GetFileSize
__imp_GetFileSize: .long hn_GetFileSize@IMGREL; .long 0
 .quad 0
user_iat:
.globl __imp_RegisterClassExA
__imp_RegisterClassExA: .long hn_RegisterClassExA@IMGREL; .long 0
.globl __imp_CreateWindowExA
__imp_CreateWindowExA: .long hn_CreateWindowExA@IMGREL; .long 0
.globl __imp_DefWindowProcA
__imp_DefWindowProcA: .long hn_DefWindowProcA@IMGREL; .long 0
.globl __imp_ShowWindow
__imp_ShowWindow: .long hn_ShowWindow@IMGREL; .long 0
.globl __imp_UpdateWindow
__imp_UpdateWindow: .long hn_UpdateWindow@IMGREL; .long 0
.globl __imp_GetMessageA
__imp_GetMessageA: .long hn_GetMessageA@IMGREL; .long 0
.globl __imp_TranslateMessage
__imp_TranslateMessage: .long hn_TranslateMessage@IMGREL; .long 0
.globl __imp_DispatchMessageA
__imp_DispatchMessageA: .long hn_DispatchMessageA@IMGREL; .long 0
.globl __imp_PostQuitMessage
__imp_PostQuitMessage: .long hn_PostQuitMessage@IMGREL; .long 0
.globl __imp_DestroyWindow
__imp_DestroyWindow: .long hn_DestroyWindow@IMGREL; .long 0
.globl __imp_LoadCursorA
__imp_LoadCursorA: .long hn_LoadCursorA@IMGREL; .long 0
.globl __imp_LoadImageA
__imp_LoadImageA: .long hn_LoadImageA@IMGREL; .long 0
 .long hn_LoadImageA@IMGREL; .long 0
.globl __imp_MessageBoxA
__imp_MessageBoxA: .long hn_MessageBoxA@IMGREL; .long 0
.globl __imp_SendMessageA
__imp_SendMessageA: .long hn_SendMessageA@IMGREL; .long 0
.globl __imp_MoveWindow
__imp_MoveWindow: .long hn_MoveWindow@IMGREL; .long 0
.globl __imp_GetWindowTextLengthA
__imp_GetWindowTextLengthA: .long hn_GetWindowTextLengthA@IMGREL; .long 0
.globl __imp_GetWindowTextA
__imp_GetWindowTextA: .long hn_GetWindowTextA@IMGREL; .long 0
.globl __imp_SetWindowTextA
__imp_SetWindowTextA: .long hn_SetWindowTextA@IMGREL; .long 0
.globl __imp_SetFocus
__imp_SetFocus: .long hn_SetFocus@IMGREL; .long 0
 .quad 0
comdlg_iat:
.globl __imp_GetOpenFileNameA
__imp_GetOpenFileNameA: .long hn_GetOpenFileNameA@IMGREL; .long 0
.globl __imp_GetSaveFileNameA
__imp_GetSaveFileNameA: .long hn_GetSaveFileNameA@IMGREL; .long 0
 .quad 0
gdi_iat:
.globl __imp_GetStockObject
__imp_GetStockObject: .long hn_GetStockObject@IMGREL; .long 0
 .quad 0
shell_iat:
.globl __imp_ShellExecuteA
__imp_ShellExecuteA: .long hn_ShellExecuteA@IMGREL; .long 0
 .quad 0

.section .idata$6,"dr"
.macro HN label,name
\label: .short 0; .asciz "\name"; .p2align 1
.endm
HN hn_GetModuleHandleA,GetModuleHandleA
HN hn_ExitProcess,ExitProcess
HN hn_CreateFileA,CreateFileA
HN hn_ReadFile,ReadFile
HN hn_WriteFile,WriteFile
HN hn_CloseHandle,CloseHandle
HN hn_GetFileSize,GetFileSize
HN hn_RegisterClassExA,RegisterClassExA
HN hn_CreateWindowExA,CreateWindowExA
HN hn_DefWindowProcA,DefWindowProcA
HN hn_ShowWindow,ShowWindow
HN hn_UpdateWindow,UpdateWindow
HN hn_GetMessageA,GetMessageA
HN hn_TranslateMessage,TranslateMessage
HN hn_DispatchMessageA,DispatchMessageA
HN hn_PostQuitMessage,PostQuitMessage
HN hn_DestroyWindow,DestroyWindow
HN hn_LoadCursorA,LoadCursorA
HN hn_LoadImageA,LoadImageA
HN hn_MessageBoxA,MessageBoxA
HN hn_SendMessageA,SendMessageA
HN hn_MoveWindow,MoveWindow
HN hn_GetWindowTextLengthA,GetWindowTextLengthA
HN hn_GetWindowTextA,GetWindowTextA
HN hn_SetWindowTextA,SetWindowTextA
HN hn_SetFocus,SetFocus
HN hn_GetOpenFileNameA,GetOpenFileNameA
HN hn_GetSaveFileNameA,GetSaveFileNameA
HN hn_GetStockObject,GetStockObject
HN hn_ShellExecuteA,ShellExecuteA
k32_name: .asciz "KERNEL32.dll"; .p2align 1
user_name: .asciz "USER32.dll"; .p2align 1
comdlg_name: .asciz "COMDLG32.dll"; .p2align 1
gdi_name: .asciz "GDI32.dll"; .p2align 1
shell_name: .asciz "SHELL32.dll"; .p2align 1
