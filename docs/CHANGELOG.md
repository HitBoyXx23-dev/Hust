# Changelog

## 0.8.30
String comparison, `break` and `continue`. `==` and `!=` on strings compare
contents rather than pointers, and both loops honour `break` and `continue`.

`examples/strings-and-loops/main.hs` exercises all three and runs:

```
string equality works
string inequality works
total skipping 3 and stopping at 5:
7
```

Numbering note: 0.8.28 and 0.8.29 were not separate builds. This release carries
the above on top of 0.8.27.

## 0.8.27
Lists and iteration. The interpreter now supports `list[...]` literals, indexing
`l[i]`, `l.length`, `l.push(v)` and `for x in list ... end`, on top of functions,
recursion, strings, interpolation, `if`/`else`, `while` and arithmetic.

`examples/lists-and-loops/main.hs` is a working mob-wander routine written in Hust
- a list of entity ids, a per-entity step function and a nested loop - and it runs:

```
tracking mobs:
3
tick 0 mob 101 step -160
tick 0 mob 102 step 160
tick 0 mob 103 step -320
...
```

That is the shape HustMC's server logic needs. Structs, maps and `match` are the
remaining pieces before protocol handlers and world state can move out of
assembly.

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
