use io
use fs
use compiler.lexer
use compiler.parser
use compiler.types
use compiler.ownership
use compiler.lower
use compiler.pe

fn compile_file(path: string) -> result<string, CompileError>
    source = fs.read_text(path)?
    tokens = Lexer(source).scan()?
    ast = Parser(tokens).parse_module()?
    typed = TypeChecker().check(ast)?
    safe = OwnershipAnalyzer().analyze(typed)?
    mir = Lowerer().lower(safe)
    optimized = optimize(mir)
    image = PeWriter().emit_x64(optimized)?
    out = path.replace_extension(".exe")
    fs.write_bytes(out, image)?
    return ok(out)
end

fn main(args: list<string>) -> int
    if args.length < 2
        print("internal compiler service: expected <file.hs>")
        return 2
    end
    out = compile_file(args[1])?
    print("built {out}")
    return 0
end
