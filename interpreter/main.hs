module hust.interpreter.main

use std.io
use std.fs
use hust.interpreter.evaluator

const VERSION = "0.8.7"

fn main(args: list<string>) -> int
    if args.length == 0
        return repl()
    end

    if args[0] == "--version" or args[0] == "-v"
        print("Hust Interpreter {VERSION}")
        return 0
    end

    if args[0] == "--help" or args[0] == "-h"
        print("Usage: HustInterpreter.exe <file.hs>")
        print("       HustInterpreter.exe            (REPL)")
        return 0
    end

    path = args[0]
    source = fs.read_text(path)?
    print("[HustInterpreter] running {path}")

    vm = Evaluator.new()
    vm.run_source(source)?
    return 0
end

fn repl() -> int
    print("Hust Interpreter {VERSION}")
    print("Native bootstrap REPL - no Python/Rust/.NET runtime. Type help or exit.")

    vm = Evaluator.new()
    while true
        line = io.read_line("hust> ")
        if line == none
            break
        end
        if line == "exit" or line == "quit"
            break
        end
        vm.run_line(line?)?
    end
    return 0
end
