# Hust Language Direction — Rust-like systems programming with less ceremony

Hust is a native systems-programming language inspired by Rust. The design target is to preserve the parts that make Rust useful for low-level software—memory safety, ownership, deterministic cleanup, native binaries, zero-cost abstractions, explicit unsafe boundaries, generics, concurrency, and strong error handling—while removing syntax that normal application code should not have to manage manually.

This document separates the **language contract** from the current bootstrap implementation. The syntax and semantics below are the target contract. The v0.8.1 compiler/runtime is still being brought up and does not yet implement every item here.

## Core style

Hust uses `.hs` source files and `end` blocks instead of mandatory braces.

```hs
fn main()
    name = "Hust"
    print("Hello from {name}")
end
```

Type annotations are optional when inference is unambiguous.

```hs
count = 10
name = "server"
port: u16 = 25565
```

## Ownership without routine lifetime syntax

Hust keeps ownership and borrowing as semantic rules but makes the compiler infer the common cases.

```hs
fn consume(buffer: Buffer)
    use(buffer)
end

fn inspect(buffer: ref Buffer)
    print(buffer.len)
end

fn edit(buffer: mut ref Buffer)
    buffer.clear()
end
```

Rules:

- Passing an owned non-copy value may move it.
- `ref T` is a shared borrow.
- `mut ref T` is an exclusive mutable borrow.
- The compiler performs escape analysis and borrow-region inference.
- Normal Hust source has no explicit lifetime parameter syntax.
- A borrow cannot outlive its owner.
- A mutable borrow cannot alias another active borrow that conflicts with it.
- Copy-like scalar values are copied instead of moved.

When inference cannot prove safety, Hust should produce an error that names the conflicting value and source locations rather than asking the programmer to write lifetime algebra.

## Shared ownership only when requested

```hs
cache = shared Cache()
worker = cache.clone()
weak_cache = weak cache
```

`shared T` is reference-counted shared ownership. `weak T` does not keep the object alive. Ordinary values are not silently reference counted.

## Explicit unsafe boundary

```hs
unsafe
    ptr.write_u32(0x12345678)
end
```

Unsafe operations must remain inside an explicit `unsafe` block or unsafe function. Safe code cannot dereference arbitrary pointers, violate aliasing rules, or call unsafe native interfaces without crossing that boundary.

## Results, optionals, and `?`

```hs
fn load_config(path: string) -> result<Config, IoError>
    text = fs.read_text(path)?
    return Config.parse(text)
end

fn find_player(name: string) -> optional<Player>
    return players.find(name)
end
```

Hust uses typed `result<T, E>` and `optional<T>`. `?` propagates an error or absence through a compatible return type.

## Pattern matching

```hs
match packet
    Login(name) => accept(name)
    Chat(text) => broadcast(text)
    Disconnect => close()
end
```

Enums are tagged unions and matching should be exhaustiveness-checked.

## Structs, classes, interfaces, generics

```hs
interface Writer
    fn write(data: ref bytes) -> result<int, IoError>
end

struct Packet<T>
    id: u16
    payload: T
end

class TcpWriter implements Writer
    socket: Socket

    fn write(data: ref bytes) -> result<int, IoError>
        return socket.send(data)
    end
end
```

Generics are statically specialized where practical. Dynamic dispatch is explicit through interface values rather than silently used everywhere.

## Concurrency

```hs
async fn serve(listener: TcpListener)
    while true
        socket = await listener.accept()
        task handle_client(socket)
    end
end
```

Target primitives include:

- `async` / `await`
- tasks and futures
- OS threads
- worker pools
- channels
- locks and condition variables
- atomics
- Windows IOCP backend

The ownership checker should prevent common cross-thread lifetime mistakes and require values crossing thread boundaries to satisfy the appropriate thread-safety contracts.

## Collections

The standard library target includes native arrays, lists, maps, sets, strings, byte buffers, and iterators without requiring an external language runtime.

## Native target

The Windows x64 target is:

```text
.hs source
  -> lexer/parser/type checker
  -> ownership + escape analysis
  -> MIR
  -> native x86-64 lowering
  -> Hust internal assembler / PE writer
  -> standalone .exe
```

HAsm (`.asm`) is an internal low-level bootstrap/backend language, not a public fifth command-line tool.

## What “simpler than Rust” means in Hust

Hust specifically aims to reduce:

- explicit lifetime annotations in ordinary code
- borrow-checker syntax exposed to users
- mandatory braces and punctuation
- boilerplate around common error propagation
- ceremony around simple async/task code
- separate helper binaries in the public toolchain

It does **not** mean removing ownership, race prevention, error typing, unsafe boundaries, or native control. Those are retained because they are part of the reason to use a Rust-like systems language.

## v0.8.1 implementation truth

Currently implemented/bootstrapped pieces include the native Windows executables, a native interpreter subset, compiler pipeline source layout, internal HAsm backend, Windows PE generation path, standard-library source modules, and HustMC as the first large Hust project.

The full self-hosting compiler, complete ownership checker, complete generics, complete async runtime, and complete standard library are still in progress. The package does not claim those are finished merely because their `.hs` APIs exist.
