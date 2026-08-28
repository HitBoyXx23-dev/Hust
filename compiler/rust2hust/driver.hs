module hust.compiler.rust2hust.driver

use std.fs
use std.io
use hust.compiler.rust2hust.emitter
use hust.compiler.rust2hust.lexer
use hust.compiler.rust2hust.blocks
use hust.compiler.rust2hust.macros
use hust.compiler.rust2hust.mapping

struct ReviewCounters
    lifetimes: int
    where_clauses: int
    unmapped_macros: int
    pattern_conditions: int
    closures: int
    unsafe_blocks: int
end

fn convert_source(source: string, counters: mut ref ReviewCounters) -> string
    emit = Emitter()
    stack = BlockStack()
    scanner = Lexer(source)
    state = ScanState(false, false, false, false)
    translate(scanner, emit, stack, state, counters)
    emit.flush()
    return emit.output
end

fn convert_file(input_path: string, output_path: string) -> result<ReviewCounters, IoError>
    counters = ReviewCounters(0, 0, 0, 0, 0, 0)
    source = fs.read_text(input_path)?
    converted = convert_source(source, mut ref counters)
    fs.write_text(output_path, converted)?
    return ok(counters)
end

fn convert_tree(input_directory: string, output_directory: string) -> result<int, IoError>
    converted = 0
    fs.create_directory(output_directory)?
    for entry in fs.read_directory(input_directory)?
        source_path = fs.join(input_directory, entry.name)
        target_path = fs.join(output_directory, entry.name)
        if entry.is_directory
            converted = converted + convert_tree(source_path, target_path)?
            continue
        end
        if not entry.name.ends_with(".rs")
            continue
        end
        hust_path = fs.join(output_directory, entry.name.slice(0, entry.name.length - 3) + ".hs")
        convert_file(source_path, hust_path)?
        converted = converted + 1
    end
    return ok(converted)
end

fn report(counters: ref ReviewCounters)
    print("[rust2hust] review counters")
    print("  lifetimes dropped: {counters.lifetimes}")
    print("  where clauses dropped: {counters.where_clauses}")
    print("  unmapped macros: {counters.unmapped_macros}")
    print("  pattern conditions: {counters.pattern_conditions}")
    print("  closures kept verbatim: {counters.closures}")
    print("  unsafe blocks: {counters.unsafe_blocks}")
end
