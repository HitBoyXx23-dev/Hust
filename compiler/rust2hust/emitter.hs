module hust.compiler.rust2hust.emitter

class Emitter
    line: string = ""
    output: string = ""
    indent: int = 0
    rhs_start: int = 0

    fn push(text: string)
        line = line + text
    end

    fn last() -> optional<char>
        if line.length == 0
            return none
        end
        return some(line[line.length - 1])
    end

    fn drop_last()
        if line.length > 0
            line = line.slice(0, line.length - 1)
        end
    end

    fn space()
        if line.length == 0
            return
        end
        if last()? == ' '
            return
        end
        push(" ")
    end

    fn mark_rhs()
        rhs_start = line.length
    end

    fn insert_await()
        start = rhs_start
        while start < line.length and line[start] == ' '
            start = start + 1
        end
        line = line.slice(0, start) + "await " + line.slice(start, line.length)
    end

    fn flush()
        trimmed = line.trim_end()
        if trimmed.length == 0
            line = ""
            rhs_start = 0
            return
        end
        output = output + " ".repeat(indent * 4) + trimmed + "\n"
        line = ""
        rhs_start = 0
    end

    fn open_block()
        flush()
        indent = indent + 1
    end

    fn close_block()
        flush()
        if indent > 0
            indent = indent - 1
        end
    end
end
