module compiler.ownership

# Hust keeps Rust-like ownership semantics but infers ordinary borrow regions.
# The compiler should reject unsafe aliasing without requiring users to write
# lifetime parameters in normal source code.
enum ValueState
    Available
    Moved
    SharedBorrowed
    MutBorrowed
end

struct BorrowRegion
    value_id: int
    mutable: bool
    start_point: int
    last_use_point: int
    escapes_scope: bool
end

class OwnershipAnalyzer
    fn analyze(module: TypedModule) -> result<SafeModule, OwnershipError>
        cfg = build_control_flow(module)
        liveness = compute_liveness(cfg)
        escapes = compute_escape_sets(cfg)
        borrows = infer_borrow_regions(cfg, liveness, escapes)?
        validate_moves(cfg, liveness)?
        validate_aliases(cfg, borrows)?
        validate_borrow_escapes(cfg, borrows)?
        validate_thread_transfers(cfg)?
        return lower_ownership_annotations(module, borrows)
    end

    fn infer_borrow_regions(cfg: ControlFlowGraph, live: Liveness, escapes: EscapeSets) -> result<list<BorrowRegion>, OwnershipError>
        regions = list<BorrowRegion>()
        for use in cfg.value_uses()
            if use.kind == Borrow or use.kind == MutBorrow
                regions.push(BorrowRegion(
                    value_id = use.value_id,
                    mutable = use.kind == MutBorrow,
                    start_point = use.point,
                    last_use_point = live.last_use(use.borrow_id),
                    escapes_scope = escapes.contains(use.borrow_id)
                ))
            end
        end
        return ok(regions)
    end

    fn validate_aliases(cfg: ControlFlowGraph, borrows: ref list<BorrowRegion>) -> result<void, OwnershipError>
        for a in borrows
            for b in borrows
                if a.value_id != b.value_id or a.start_point >= b.last_use_point or b.start_point >= a.last_use_point
                    continue
                end
                if a.mutable or b.mutable
                    return error(OwnershipError.conflicting_borrow(a, b))
                end
            end
        end
        return ok()
    end
end
