module compiler.pe
class PeWriter
    fn emit_x64(module: MirModule) -> result<bytes, LinkError>
        # DOS header, PE32+ optional header, sections, imports,
        # relocations, symbols and x86-64 machine code.
        return pe64_from_mir(module)
    end
end
