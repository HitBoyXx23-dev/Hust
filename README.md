# Hust

A systems language with Rust's model and less ceremony: ownership instead of a
garbage collector, `result` instead of exceptions, no null, immutable by default,
traits — written with `end` blocks, no semicolons, and no lifetime annotations.

```hust
module demo

fn fib(n)
    if n < 2
        return n
    end
    return fib(n - 1) + fib(n - 2)
end

fn main()
    name = "world"
    print("hello {name}, fib(12) = ")
    print(fib(12))
end
```

```
bin\HustInterpreter.exe examples\language-tour\main.hs
```

## What ships here

| Path | What it is |
| --- | --- |
| `bin/HustRuntime.exe` | runtime and service host |
| `bin/HustInterpreter.exe` | interpreter, REPL and the Rust-to-Hust converter |
| `bin/HustStudio.exe` | native Win32 IDE |
| `compiler/` | compiler sources, including `rust2hust/` |
| `interpreter/`, `std/`, `ide/`, `assembler/` | language sources |
| `runtime/native/` | the x86-64 bootstrap the executables are built from |
| `examples/` | runnable programs |
| `docs/` | language reference, Rust comparison, conversion tables |

Windows x64. No Python, Rust, Node.js or .NET runtime is required to run the
executables.

## What works today

The interpreter executes functions with parameters, recursion, integers, strings,
`{name}` interpolation, string concatenation, `if`/`else`, `while`, `return`,
arithmetic, comparison and `and`/`or`/`not`.

Not yet: structs, lists, maps, traits, `match`, `for`, closures, async.

## Rust to Hust

```
bin\HustInterpreter.exe --convert-rust input.rs output.hs
bin\HustInterpreter.exe --convert-rust-dir src out
```

A source translator, not a compiler: it does not type-check or resolve traits, and
it prints counters for every construct it could not translate one-to-one. See
`docs/RUST_TO_HUST.md`.

## Honest status

The compiler is not self-hosting. `.hs` under `compiler/`, `std/` and `ide/` is
canonical source that the current interpreter cannot yet run; the shipped
executables are built from the `.ha` bootstrap in `runtime/native/`. Closing that
gap is the main line of work.

## Building

```
bin\build_hust_interpreter.bat        (MSYS2 mingw-w64)
bin/build_hust_interpreter.sh         (Linux or WSL)
```

## License

See `LICENSE`. Add-ons, plugins and libraries written in or for Hust are yours;
modifying Hust itself is not permitted.
