#!/bin/sh
# Rebuilds bin/HustInterpreter.exe from the native sources in runtime/native.
# Requires an x86_64-w64-mingw32 assembler and linker.
set -e
cd "$(dirname "$0")/.."
AS=x86_64-w64-mingw32-as
LD=x86_64-w64-mingw32-ld
$AS -o /tmp/hust_interpreter.o runtime/native/hust_interpreter_win64.asm
$AS -o /tmp/hust_rust2hust.o  runtime/native/hust_rust2hust_win64.asm
$AS -o /tmp/hust_interp_core.o runtime/native/hust_interp_core_win64.asm
$LD -o bin/HustInterpreter.exe \
  /tmp/hust_interpreter.o /tmp/hust_rust2hust.o /tmp/hust_interp_core.o \
  --entry=_start \
  --subsystem=console \
  --image-base=0x140000000 \
  --dynamicbase --nxcompat --high-entropy-va \
  -lkernel32
echo "built bin/HustInterpreter.exe"
