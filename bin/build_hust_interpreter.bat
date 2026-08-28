@echo off
REM Rebuilds bin\HustInterpreter.exe from the native sources in runtime\native.
setlocal
cd /d "%~dp0.."
x86_64-w64-mingw32-as -o hust_interpreter.o runtime\native\hust_interpreter_win64.ha
if errorlevel 1 goto fail
x86_64-w64-mingw32-as -o hust_rust2hust.o runtime\native\hust_rust2hust_win64.ha
if errorlevel 1 goto fail
x86_64-w64-mingw32-as -o hust_interp_core.o runtime\native\hust_interp_core_win64.ha
if errorlevel 1 goto fail
x86_64-w64-mingw32-ld -o bin\HustInterpreter.exe hust_interpreter.o hust_rust2hust.o hust_interp_core.o --entry=_start --subsystem=console --image-base=0x140000000 --dynamicbase --nxcompat --high-entropy-va -lkernel32
if errorlevel 1 goto fail
del hust_interpreter.o hust_rust2hust.o hust_interp_core.o
echo Built bin\HustInterpreter.exe
goto :eof
:fail
echo BUILD FAILED
exit /b 1
