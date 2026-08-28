# Hust Studio 0.8.1

`HustStudio.exe` is a native Windows x64 IDE written directly in internal HAsm (`runtime/native/hust_studio_win64.asm`). The IDE executable itself is not written in Hust and does not require the Hust runtime to draw its UI.

## Current native features

- Win32 GUI application, not a console stub;
- multiline source editor;
- New;
- Open `.hs` using the native Windows file dialog;
- Save / Save As using native Windows file dialogs;
- direct Windows file I/O;
- resize-aware editor/buttons;
- Run, which saves the file and starts `HustInterpreter.exe` with the active source path;
- normal Win32 status/error message dialogs;
- Hust titlebar/taskbar logo loaded from `assets\HustLogo.ico` with `LoadImageA`.

The executable is linked using Hust's custom HAsm PE/import-table source. Its imported DLLs are Windows system GUI libraries only: KERNEL32, USER32, COMDLG32, GDI32 and SHELL32.

## Validation boundary

The HAsm assembled and the final executable linked as a PE32+ Windows GUI x86-64 application. This Linux packaging environment does not have Wine/Windows GUI access, so mouse/keyboard/dialog behavior still needs a real Windows launch test.
