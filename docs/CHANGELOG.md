# Changelog

## 0.8.25
Native sources renamed from `.ha` to `.asm`. They were always x86-64 assembly in
GNU assembler syntax; the extension was the only thing suggesting otherwise.

## 0.8.24
Repository layout: executables and scripts under `bin/`, sources at the root,
`.gitignore` and `.gitattributes` added, build metadata files dropped.

## 0.8.23
The interpreter executes real programs: functions with parameters, recursion,
integers, strings, `{name}` interpolation, concatenation, `if`/`else`, `while`,
`return`, arithmetic, comparison, `and`/`or`/`not`. `examples/language-tour`
exercises all of it.

## 0.8.22
Added `docs/HUST_VS_RUST.md`.

## 0.8.14
`rust2hust` added to the interpreter. Hust and HustMC split into separate
packages.
