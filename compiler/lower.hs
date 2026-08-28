module compiler.lower
class Lowerer
    fn lower(module: SafeModule) -> MirModule
        return lower_to_mir(module)
    end
end
