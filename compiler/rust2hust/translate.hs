module hust.compiler.rust2hust.translate

use hust.compiler.rust2hust.emitter
use hust.compiler.rust2hust.lexer
use hust.compiler.rust2hust.blocks
use hust.compiler.rust2hust.macros
use hust.compiler.rust2hust.mapping

const KEYWORD_BLOCK_HEADERS = list["if", "while", "for", "match", "loop"]
const KEYWORD_DECLARATIONS = list["fn", "struct", "enum", "union", "impl", "trait", "mod", "unsafe"]
const KEYWORD_DROPPED = list["pub", "dyn", "move", "ref", "let"]

fn translate(scanner: mut ref Lexer, emit: mut ref Emitter, stack: mut ref BlockStack, state: mut ref ScanState, counters: mut ref ReviewCounters)
    while true
        token = scanner.next()
        match token.kind
            TokenKind.EndOfFile => break
            TokenKind.Comment => continue
            TokenKind.Lifetime =>
                counters.lifetimes = counters.lifetimes + 1
            TokenKind.Attribute =>
                emit.flush()
                emit.push("@" + token.text.trim_start("#[").trim_end("]"))
                emit.flush()
            TokenKind.Text =>
                emit.push(token.text)
                state.previous_is_operand = true
            TokenKind.Character =>
                emit.push(token.text)
                state.previous_is_operand = true
            TokenKind.Number =>
                emit.push(strip_numeric_suffix(token.text))
                state.previous_is_operand = true
            TokenKind.Identifier => identifier(token, scanner, emit, stack, state, counters)
            TokenKind.Punctuation => punctuation(token, scanner, emit, stack, state, counters)
        end
    end
end

fn identifier(token: Token, scanner: mut ref Lexer, emit: mut ref Emitter, stack: mut ref BlockStack, state: mut ref ScanState, counters: mut ref ReviewCounters)
    if token.text == "where"
        counters.where_clauses = counters.where_clauses + 1
        scanner.skip_until_block()
        return
    end
    if KEYWORD_DROPPED.contains(token.text)
        if token.text == "let"
            return
        end
        if token.text == "ref"
            emit.push("ref ")
        end
        return
    end
    if token.text == "loop"
        emit.push("while true")
        state.header = true
        return
    end
    if token.text == "trait"
        emit.push("interface ")
        state.declaration = true
        return
    end
    if token.text == "mod"
        emit.push("module ")
        state.declaration = true
        return
    end
    if KEYWORD_DECLARATIONS.contains(token.text)
        emit.push(token.text + " ")
        state.declaration = true
        if token.text == "unsafe"
            counters.unsafe_blocks = counters.unsafe_blocks + 1
        end
        return
    end
    if KEYWORD_BLOCK_HEADERS.contains(token.text)
        emit.push(token.text + " ")
        state.header = true
        if scanner.consume_word("let")
            counters.pattern_conditions = counters.pattern_conditions + 1
            scanner.unwrap_optional_pattern()
        end
        return
    end
    if token.text == "use"
        emit.push("use ")
        state.use_statement = true
        return
    end
    if token.text == "await" and emit.last() == some('.')
        emit.drop_last()
        emit.insert_await()
        state.previous_is_operand = true
        return
    end
    if (token.text == "unwrap" or token.text == "expect") and emit.last() == some('.')
        emit.drop_last()
        scanner.skip_call_arguments()
        emit.push("?")
        state.previous_is_operand = true
        return
    end
    if scanner.at_macro()
        form = classify(token.text)
        if form == MacroForm.Unmapped
            counters.unmapped_macros = counters.unmapped_macros + 1
        end
        emit(form, scanner.capture_macro_arguments(), mut ref emit)
        state.previous_is_operand = true
        return
    end
    entry = lookup(token.text)
    if entry == none
        emit.push(token.text)
        state.previous_is_operand = true
        return
    end
    emit.push(entry?.hust)
    if entry?.action != MapAction.Rename
        scanner.erase_generic_arguments()
    end
    state.previous_is_operand = true
end

fn punctuation(token: Token, scanner: mut ref Lexer, emit: mut ref Emitter, stack: mut ref BlockStack, state: mut ref ScanState, counters: mut ref ReviewCounters)
    match token.text
        "{" =>
            kind = classify(state, ref emit)
            stack.push(kind)
            if kind == BraceKind.Block
                emit.line = rewrite_header(emit.line)
                emit.open_block()
                state.declaration = false
                state.header = false
            else
                emit.push(" { ")
            end
        "}" =>
            kind = stack.pop()
            if kind == some(BraceKind.Block)
                emit.close_block()
                if scanner.consume_word("else")
                    emit.push("else ")
                else
                    emit.push("end")
                    emit.flush()
                end
            else
                emit.push(" }")
                state.previous_is_operand = true
            end
        ";" =>
            emit.expand_use_statement(state.use_statement)
            emit.flush()
            state.use_statement = false
            state.declaration = false
            state.header = false
        "," =>
            if scanner.inside_group() or stack.top() != some(BraceKind.Block)
                emit.push(", ")
            else
                emit.flush()
            end
        "&" =>
            if state.previous_is_operand
                emit.push("&")
            else
                if scanner.consume_word("mut")
                    emit.push("mut ref ")
                else
                    emit.push("ref ")
                end
            end
        "|" =>
            counters.closures = counters.closures + 1
            emit.push("|")
        _ => emit.push(scanner.punctuation_text(token, state))
    end
end
