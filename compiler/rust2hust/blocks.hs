module hust.compiler.rust2hust.blocks

use hust.compiler.rust2hust.emitter

enum BraceKind
    Block
    Inline
end

class BlockStack
    kinds: list<BraceKind> = list[]

    fn push(kind: BraceKind)
        kinds.push(kind)
    end

    fn pop() -> optional<BraceKind>
        return kinds.pop()
    end

    fn top() -> optional<BraceKind>
        if kinds.length == 0
            return none
        end
        return some(kinds[kinds.length - 1])
    end
end

struct ScanState
    header: bool
    declaration: bool
    use_statement: bool
    previous_is_operand: bool
end

fn classify(state: ScanState, emit: ref Emitter) -> BraceKind
    if state.use_statement
        return BraceKind.Inline
    end
    if state.header
        return BraceKind.Block
    end
    if state.declaration
        return BraceKind.Block
    end
    last = emit.last()
    if last == some(')')
        return BraceKind.Block
    end
    if last == some('|')
        return BraceKind.Inline
    end
    if last == some('>') and emit.line.ends_with("=>")
        return BraceKind.Block
    end
    if state.previous_is_operand
        return BraceKind.Inline
    end
    return BraceKind.Block
end

fn rewrite_header(header: string) -> string
    if not header.starts_with("impl ")
        return header
    end
    body = header.slice(5, header.length).trim()
    marker = body.find(" for ")
    if marker == none
        return "class " + body
    end
    trait_name = body.slice(0, marker?).trim()
    type_name = body.slice(marker? + 5, body.length).trim()
    return "class " + type_name + " implements " + trait_name
end
