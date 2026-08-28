module compiler.parser
use compiler.lexer

class Parser
    tokens: list<Token>
    current: int = 0

    fn parse_module() -> result<Module, ParseError>
        module = Module()
        while not at_end()
            module.items.push(parse_item()?)
        end
        return ok(module)
    end
end
