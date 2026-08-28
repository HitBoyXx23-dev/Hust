module compiler.types

class TypeChecker
    fn check(module: Module) -> result<TypedModule, TypeError>
        scopes = ScopeTree.new(module)
        constraints = TypeConstraints()
        collect_declarations(module, scopes, constraints)?
        infer_expressions(module, scopes, constraints)?
        solve_generic_constraints(constraints)?
        validate_result_propagation(module, constraints)?
        validate_match_exhaustiveness(module, constraints)?
        validate_interface_conformance(module, constraints)?
        return annotate_types(module, constraints)
    end
end
