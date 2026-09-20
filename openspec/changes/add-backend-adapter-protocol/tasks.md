## 1. LogicalOp reification
- [ ] 1.1 Define the sealed `LogicalOp` hierarchy (`Filter`, `Project`,
      `Extend`, `Sort`, `Distinct`, `GroupBy`, `Join`, `Identity`)
- [ ] 1.2 Update every pipeline factory (`where`, `select`, `derive`,
      `sort_by`, `distinct`, `groupby`, `join`) to attach the matching
      `LogicalOp` alongside its existing transducer lowering
- [ ] 1.3 Add the exhaustiveness test for `LogicalOp` (mirrors the existing
      `SchemaTransform` exhaustiveness test)
- [ ] 1.4 Update `explain()` to render the `LogicalOp` chain

## 2. Backend protocol
- [ ] 2.1 Define the `Backend` protocol (`plan`, `supports`, `null_policy`)
- [ ] 2.2 Define `NullPolicy` (`RAISE`, `PROPAGATE`)
- [ ] 2.3 Implement the pure-Python backend as `Backend` conformance
      (default, `NullPolicy.RAISE`, unaffected observable behavior)
- [ ] 2.4 Add `on_unsupported` construction parameter (`"raise"` default,
      `"fallback"` opt-in) and wire it to `UnsupportedOperationError`

## 3. Import/export boundary
- [ ] 3.1 Define the supported-dtype rejection policy for `from_pandas`
      and `from_polars`
- [ ] 3.2 Define the column-name policy (`SchemaError` on non-identifier
      names unless `column_map=` provided)
- [ ] 3.3 Implement `to_pandas`/`to_polars` export (pure-Python backend
      only, in this change)

## 4. DataFrame integration
- [ ] 4.1 Add `backend=` parameter to `DataFrame` construction
- [ ] 4.2 Expose `.backend` and `.null_policy` as inspectable properties
- [ ] 4.3 Update `explain()` output to include active backend and null
      policy

## 5. Validation
- [ ] 5.1 Run `openspec validate add-backend-adapter-protocol --strict`
- [ ] 5.2 Confirm pure-Python-only behavior is bit-for-bit unchanged from
      `add-core-architecture` when no `backend=` is specified
