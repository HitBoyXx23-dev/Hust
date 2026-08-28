module compiler.lexer

enum TokenKind
    identifier, number, string_lit, newline, symbol, keyword, eof
end

struct Token
    kind: TokenKind
    text: string
    line: int
    column: int
end

class Lexer
    source: string
    pos: int = 0
    line: int = 1
    column: int = 1

    fn new(source: string) -> Lexer
        return Lexer(source = source)
    end

    fn scan() -> result<list<Token>, LexError>
        let out = list<Token>()
        # bootstrap implementation: whitespace/comments, identifiers,
        # UTF-8 strings with escapes, decimal/hex/binary numbers, operators.
        while pos < source.length
            scan_one(out)?
        end
        out.push(Token(eof, "", line, column))
        return ok(out)
    end
end
