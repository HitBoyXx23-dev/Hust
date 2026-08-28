module hust.interpreter.evaluator

# Bootstrap evaluator currently implemented by Hust's native backend.
# Supported milestone syntax:
#   let x = 5
#   x = x + 2
#   let name = "Hust"
#   print(x)
#   print(name)
#   print("hello")
# Arithmetic: + - * /

class Value
    is_number: bool
    number: i64
    text: string
end

class Evaluator
    values: map<string, Value>

    static fn new() -> Evaluator
        return Evaluator(values: {})
    end

    fn run_source(source: string) -> result<void, string>
        for line in source.lines()
            try run_line(line)
        end
        return ok()
    end

    fn run_line(source_line: string) -> result<void, string>
        line = source_line.trim()
        if line == "" or line.starts_with("#")
            return ok()
        end

        if line == "help"
            print("Hust subset: let x = 5 | x = 7 | print(x) | print(\"text\") | + - * /")
            return ok()
        end

        if line.starts_with("print(") and line.ends_with(")")
            expr = line.slice(6, line.length - 1)
            print_value(expr)
            return ok()
        end

        if line.starts_with("print ")
            print_value(line.slice(6))
            return ok()
        end

        statement = line
        if statement.starts_with("let ") or statement.starts_with("var ")
            statement = statement.slice(4)
        end

        equals = statement.index_of("=")
        if equals != none
            name = statement.slice(0, equals?).trim()
            expr = statement.slice(equals? + 1).trim()
            values[name] = evaluate(expr)?
            return ok()
        end

        return error("unsupported statement")
    end

    fn print_value(expr: string) -> result<void, string>
        value = evaluate(expr)?
        if value.is_number
            print(value.number)
        else
            print(value.text)
        end
        return ok()
    end

    fn evaluate(expr: string) -> result<Value, string>
        # Native milestone evaluator performs string literal, variable and
        # left-to-right integer arithmetic evaluation. The full parser/VM will
        # replace this bootstrap evaluator as the Hust compiler self-hosts.
        return native.bootstrap_eval(expr, values)
    end
end
