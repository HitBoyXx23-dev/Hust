# rust2hust - converting Rust source to Hust source

`HustInterpreter.exe` carries a native Rust-to-Hust source converter. It reads `.rs` files and
writes `.hs` files. It is a source translator: it does not type-check, borrow-check, resolve
traits, expand real macros or compile anything.

## Usage

```
HustInterpreter.exe --convert-rust src\main.rs out\main.hs
HustInterpreter.exe --convert-rust-dir C:\code\my_crate C:\code\my_crate_hust
```

Directory mode walks subdirectories, mirrors the tree, converts every `.rs` file to `.hs` and
skips everything else. It prints how many files converted and how many failed.

## What it translates

| Rust | Hust |
| --- | --- |
| `{ ... }` block | `end` block, re-indented |
| `;` statement terminator | line break |
| `fn f(&self)` | `fn f(ref self)` |
| `&T` / `&mut T` | `ref T` / `mut ref T` |
| `let x` / `let mut x` | `x` / `mut x` |
| `impl Trait for Type` | `class Type implements Trait` |
| `impl Type` | `class Type` |
| `trait T` | `interface T` |
| `mod m` | `module m` |
| `use a::b::{c, d};` | `use a.b.c` and `use a.b.d` |
| `path::to::Item` | `path.to.Item` |
| `Vec<T>` / `VecDeque<T>` | `list<T>` |
| `String` / `&str` | `string` |
| `Option<T>` / `Result<T, E>` | `optional<T>` / `result<T, E>` |
| `HashMap` / `BTreeMap` | `map` |
| `HashSet` / `BTreeSet` | `set` |
| `Some/None/Ok/Err` | `some/none/ok/err` |
| `Arc<T>` / `Rc<T>` | `shared T` |
| `Weak<T>` | `weak T` |
| `Box<T>`, `RefCell<T>`, `Cell<T>`, `Mutex<T>`, `RwLock<T>`, `Cow<T>`, `Pin<T>` | inner type, wrapper erased |
| `.unwrap()` / `.expect("...")` | `?` |
| `expr.await` | `await expr` |
| `loop` | `while true` |
| `&&` / `\|\|` / `!x` | `and` / `or` / `not x` |
| `if let Some(x) = e` / `if let Ok(x) = e` | `if x = e` |
| `println!("{} {}", a, b)` | `print("{a} {b}")` |
| `format!("{}", a)` | `"{a}"` |
| `write!(f, "{}", a)` | `f.write("{a}")` |
| `panic!("...")` | `panic("...")` |
| `todo!()` / `unimplemented!()` | `panic("not implemented")` |
| `vec![...]` | `list[...]` |
| `#[derive(Debug)]` | `@derive(Debug)` |
| `-> ()` and `Result<(), E>` | `-> void` and `result<void, E>` |
| `0usize`, `1_000u32` | `0`, `1000` |
| `//` and `/* */` comments | removed |
| `'a` lifetimes, `where` clauses, `dyn`, `pub`, `move` | removed |

## What it does not do

- It does not verify that the result compiles. The Hust compiler is not self-hosting yet.
- Closures (`|x| ...`) are kept in Rust form; Hust closure syntax is not settled.
- Macros outside the list above lose only their `!` and become ordinary calls.
- `if let` with a non-optional pattern keeps the Rust pattern, which is not valid Hust.
- Turbofish `::<T>` becomes `<T>` and is not re-checked.
- Generic bounds, `impl Trait` arguments and associated types are copied through untouched.
- Struct literals stay in brace form because Hust keeps braces for value construction.
- Attribute semantics are not mapped; `@derive(...)` is a syntactic placeholder.

Every run ends with review counters for exactly these cases. Non-zero counters mean the output
needs reading, not that the conversion failed.

## Validation performed for 0.8.14

| Corpus | `.rs` files | converted | failed |
| --- | --- | --- | --- |
| Reference tree A (AGPL-3.0-or-later) | 1488 | 1488 | 0 |
| Reference tree B (GPL-3.0) | 2546 | 2546 | 0 |

Neither tree is redistributed in this package. Converted output of a copyleft-licensed project
stays under that project's license; converting a file does not change its license.
