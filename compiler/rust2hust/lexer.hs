module hust.compiler.rust2hust.lexer

enum TokenKind
    Identifier
    Number
    Text
    Character
    Lifetime
    Punctuation
    Comment
    Attribute
    EndOfFile
end

struct Token
    kind: TokenKind
    text: string
    start: int
    length: int
end

class Lexer
    source: string
    position: int = 0

    fn at_end() -> bool
        return position >= source.length
    end

    fn peek(offset: int) -> optional<char>
        index = position + offset
        if index >= source.length
            return none
        end
        return some(source[index])
    end

    fn is_identifier_char(value: char) -> bool
        return value.is_alphanumeric() or value == '_'
    end

    fn next() -> Token
        skip_whitespace()
        if at_end()
            return Token(TokenKind.EndOfFile, "", position, 0)
        end
        current = source[position]
        if current == '/' and peek(1) == some('/')
            return line_comment()
        end
        if current == '/' and peek(1) == some('*')
            return block_comment()
        end
        if current == '"'
            return text_literal()
        end
        if current == '\''
            return quote_literal()
        end
        if current == '#'
            return attribute()
        end
        if is_identifier_char(current) and not current.is_digit()
            return identifier()
        end
        if current.is_digit()
            return number()
        end
        return punctuation()
    end

    fn skip_whitespace()
        while not at_end() and source[position].is_whitespace()
            position = position + 1
        end
    end

    fn identifier() -> Token
        start = position
        while not at_end() and is_identifier_char(source[position])
            position = position + 1
        end
        return Token(TokenKind.Identifier, source.slice(start, position), start, position - start)
    end

    fn number() -> Token
        start = position
        while not at_end() and (is_identifier_char(source[position]) or source[position] == '.')
            position = position + 1
        end
        return Token(TokenKind.Number, source.slice(start, position), start, position - start)
    end

    fn text_literal() -> Token
        start = position
        position = position + 1
        while not at_end()
            if source[position] == '\\'
                position = position + 2
                continue
            end
            if source[position] == '"'
                position = position + 1
                break
            end
            position = position + 1
        end
        return Token(TokenKind.Text, source.slice(start, position), start, position - start)
    end

    fn quote_literal() -> Token
        start = position
        if peek(1) == some('\\') or peek(2) == some('\'')
            position = position + 1
            while not at_end() and source[position] != '\''
                position = position + 1
            end
            position = position + 1
            return Token(TokenKind.Character, source.slice(start, position), start, position - start)
        end
        position = position + 1
        while not at_end() and is_identifier_char(source[position])
            position = position + 1
        end
        return Token(TokenKind.Lifetime, source.slice(start, position), start, position - start)
    end

    fn line_comment() -> Token
        start = position
        while not at_end() and source[position] != '\n'
            position = position + 1
        end
        return Token(TokenKind.Comment, source.slice(start, position), start, position - start)
    end

    fn block_comment() -> Token
        start = position
        depth = 0
        while not at_end()
            if source[position] == '/' and peek(1) == some('*')
                depth = depth + 1
                position = position + 2
                continue
            end
            if source[position] == '*' and peek(1) == some('/')
                depth = depth - 1
                position = position + 2
                if depth == 0
                    break
                end
                continue
            end
            position = position + 1
        end
        return Token(TokenKind.Comment, source.slice(start, position), start, position - start)
    end

    fn attribute() -> Token
        start = position
        while not at_end() and source[position] != ']'
            position = position + 1
        end
        position = position + 1
        return Token(TokenKind.Attribute, source.slice(start, position), start, position - start)
    end

    fn punctuation() -> Token
        start = position
        position = position + 1
        return Token(TokenKind.Punctuation, source.slice(start, position), start, 1)
    end
end
