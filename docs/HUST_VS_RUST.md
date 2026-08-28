# Hust compared to Rust

Written from the two servers in these packages, so the comparison is against code
that exists rather than against a wishlist.

## What Hust keeps

Rust's genuinely good ideas are the ones Hust does not change: ownership instead of
a garbage collector, `result` instead of exceptions, no null, immutable by default,
pattern matching, traits as the abstraction mechanism. Hust is a different surface
over the same model, not a different model.

## Where the syntax is simpler

**Blocks end with `end`, not braces.** No brace matching across a 200-line
function, no rustfmt argument about where `{` goes.

**No semicolons.** A line ends a statement.

**Borrowing reads as English.** `&mut Vec<String>` becomes `mut ref list<string>`.
The three concepts - mutable, borrowed, list of strings - are three words in the
order you would say them.

**Shared ownership has one name.** `Arc<Mutex<T>>`, the pattern every Rust server
reaches for and every Rust beginner trips over, is `shared T`. `Rc<RefCell<T>>` is
also `shared T`, because at the level you are thinking, they are the same idea.
`Weak<T>` is `weak T`.

**No lifetime annotations.** `fn longest<'a>(x: &'a str, y: &'a str) -> &'a str`
is `fn longest(x: ref string, y: ref string) -> ref string`.

**Interpolation is built in.** `format!("{} of {}", item.name, count)` is
`"{item.name} of {count}"`.

**Two container words, not eight.** `list`, `map`, `set`, `string`, `optional`,
`result`. No `Vec` versus `VecDeque` versus `&[T]` decision before you have written
the loop.

**`impl Trait for Type` becomes `class Type implements Trait`**, which is the
sentence you would say out loud.

## The honest side

Hust is not better than Rust today, and here is exactly why.

**The compiler is not self-hosting.** Every `.hs` file in these packages is
canonical source that does not yet execute. HustMC.exe is built from 14,000 lines
of x86-64 assembly. RustMC is built by rustc and runs. That is the whole gap, and
it is a big one.

**Rust's ecosystem is thirty thousand crates.** Hust has none. RustMC needed no
dependencies for a login server, but a real project reaches for tokio, serde and
half a dozen others on day one.

**Rust's borrow checker is proven.** Hust's ownership rules are specified but have
never rejected a real bug, because nothing has compiled yet.

**Rust has twenty years of tooling.** rust-analyzer, clippy, miri, cargo. Hust has
an interpreter subset, a Studio editor and a Rust-to-Hust converter.

**Where the simplification costs something.** Collapsing `Arc<Mutex<T>>` and
`Rc<RefCell<T>>` into `shared T` hides a real distinction: one is thread-safe and
one is not. Rust makes you say which; Hust makes the compiler decide. That is
easier to write and harder to reason about when it goes wrong. Dropping lifetime
annotations has the same shape: less to type, less control when inference guesses
differently than you meant.

## The fair claim

Hust is Rust's model with less ceremony. If it compiles what it specifies, it will
be genuinely faster to write and read for exactly the kind of code in HustMC:
protocol handlers, world state, plenty of shared mutable structures. It will not be
faster than Rust at runtime, it will not be safer, and it will not have an
ecosystem for years.

The claim worth making right now is narrow and true: **the same server logic is
shorter and reads more plainly in Hust than in Rust.** Everything past that has to
wait for the compiler.
