module hust.compiler.rust2hust.macros

use hust.compiler.rust2hust.emitter

enum MacroForm
    Print
    Format
    Panic
    Write
    ListLiteral
    NotImplemented
    Unmapped
end

fn classify(name: string) -> MacroForm
    if name == "println" or name == "print" or name == "eprintln" or name == "eprint"
        return MacroForm.Print
    end
    if name == "format"
        return MacroForm.Format
    end
    if name == "panic"
        return MacroForm.Panic
    end
    if name == "write" or name == "writeln"
        return MacroForm.Write
    end
    if name == "vec"
        return MacroForm.ListLiteral
    end
    if name == "todo" or name == "unimplemented"
        return MacroForm.NotImplemented
    end
    return MacroForm.Unmapped
end

fn convert_argument(argument: string) -> string
    return argument.replace("::", ".").trim_start("&")
end

fn interpolate(format_text: string, arguments: list<string>) -> string
    result = "\""
    next_argument = 0
    index = 0
    while index < format_text.length
        current = format_text[index]
        if current != '{'
            result = result + current
            index = index + 1
            continue
        end
        if index + 1 < format_text.length and format_text[index + 1] == '{'
            result = result + "{"
            index = index + 2
            continue
        end
        close = format_text.find_from("}", index)
        if close == none
            break
        end
        placeholder = format_text.slice(index + 1, close?)
        if placeholder.length == 0 or placeholder.starts_with(":")
            if next_argument < arguments.length
                result = result + "{" + convert_argument(arguments[next_argument]) + "}"
                next_argument = next_argument + 1
            end
        else
            name = placeholder.split(":")[0]
            result = result + "{" + name + "}"
        end
        index = close? + 1
    end
    return result + "\""
end

fn emit(form: MacroForm, arguments: list<string>, emit_target: mut ref Emitter)
    match form
        MacroForm.Print => emit_target.push("print(" + interpolate(arguments[0], arguments.slice(1, arguments.length)) + ")")
        MacroForm.Format => emit_target.push(interpolate(arguments[0], arguments.slice(1, arguments.length)))
        MacroForm.Panic => emit_target.push("panic(" + interpolate(arguments[0], arguments.slice(1, arguments.length)) + ")")
        MacroForm.Write => emit_target.push(arguments[0] + ".write(" + interpolate(arguments[1], arguments.slice(2, arguments.length)) + ")")
        MacroForm.ListLiteral => emit_target.push("list")
        MacroForm.NotImplemented => emit_target.push("panic(\"not implemented\")")
        MacroForm.Unmapped => emit_target.push(arguments[0])
    end
end
