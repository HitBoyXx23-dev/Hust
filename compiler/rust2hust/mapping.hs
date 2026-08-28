module hust.compiler.rust2hust.mapping

enum MapAction
    Rename
    EraseGeneric
    RenameAndErase
end

struct TypeMapping
    rust: string
    hust: string
    action: MapAction
end

const TYPE_MAPPINGS = list[
    TypeMapping("Vec", "list", MapAction.Rename),
    TypeMapping("VecDeque", "list", MapAction.Rename),
    TypeMapping("String", "string", MapAction.Rename),
    TypeMapping("str", "string", MapAction.Rename),
    TypeMapping("Option", "optional", MapAction.Rename),
    TypeMapping("Result", "result", MapAction.Rename),
    TypeMapping("HashMap", "map", MapAction.Rename),
    TypeMapping("BTreeMap", "map", MapAction.Rename),
    TypeMapping("HashSet", "set", MapAction.Rename),
    TypeMapping("BTreeSet", "set", MapAction.Rename),
    TypeMapping("Some", "some", MapAction.Rename),
    TypeMapping("None", "none", MapAction.Rename),
    TypeMapping("Ok", "ok", MapAction.Rename),
    TypeMapping("Err", "err", MapAction.Rename),
    TypeMapping("Box", "", MapAction.EraseGeneric),
    TypeMapping("RefCell", "", MapAction.EraseGeneric),
    TypeMapping("Cell", "", MapAction.EraseGeneric),
    TypeMapping("Mutex", "", MapAction.EraseGeneric),
    TypeMapping("RwLock", "", MapAction.EraseGeneric),
    TypeMapping("Cow", "", MapAction.EraseGeneric),
    TypeMapping("Pin", "", MapAction.EraseGeneric),
    TypeMapping("Arc", "shared ", MapAction.RenameAndErase),
    TypeMapping("Rc", "shared ", MapAction.RenameAndErase),
    TypeMapping("Weak", "weak ", MapAction.RenameAndErase)
]

const NUMERIC_SUFFIXES = list[
    "usize", "isize", "u8", "u16", "u32", "u64",
    "i8", "i16", "i32", "i64", "f32", "f64"
]

fn lookup(name: string) -> optional<TypeMapping>
    for entry in TYPE_MAPPINGS
        if entry.rust == name
            return some(entry)
        end
    end
    return none
end

fn strip_numeric_suffix(literal: string) -> string
    for suffix in NUMERIC_SUFFIXES
        if literal.ends_with(suffix) and literal.length > suffix.length
            return literal.slice(0, literal.length - suffix.length)
        end
    end
    return literal
end
