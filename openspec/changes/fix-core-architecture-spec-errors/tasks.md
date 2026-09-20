## 1. Expression spec correction
- [ ] 1.1 Fix the arithmetic operator table header typo (`//` → `/`) in
      `expression/spec.md`
- [ ] 1.2 Confirm no other reference to `//`/floor division exists anywhere
      in `add-core-architecture` or `add-advanced-data-integrity`

## 2. Exception taxonomy
- [ ] 2.1 Add `InvalidExprUsageError(PocoError, TypeError)` to the public
      exception taxonomy in `errors/spec.md`
- [ ] 2.2 Update `expression/spec.md`'s boolean-context requirement to raise
      `InvalidExprUsageError`
- [ ] 2.3 Update `expression/spec.md`'s unhashable-Expr requirements
      (`__eq__`/`__hash__` requirement and the dedicated "Unhashable Expr
      error includes guidance" requirement) to raise
      `InvalidExprUsageError` via an explicit `__hash__` method rather than
      `__hash__ = None`
- [ ] 2.4 Verify scenario wording still matches (message text unchanged,
      only the exception type/class changes)

## 3. Dataframe traceability ID collision
- [ ] 3.1 Renumber the second `[HUM-008 / FAIL-007]` requirement
      ("Pipeline steps validate Expr types at construction") to
      `[HUM-009 / FAIL-008]`
- [ ] 3.2 Grep the full spec tree to confirm `HUM-009` and `FAIL-008` are
      not already in use elsewhere (confirmed clear as of this proposal)

## 4. Cross-proposal consistency: distinct() return type
- [ ] 4.1 Correct `add-advanced-data-integrity`'s `transducer/spec.md` delta
      so `po.distinct(*exprs, ttl=None, max_seen=None)` is described as
      returning a `PipelineStep` whose data component is a stateful
      transducer, matching `pipeline/spec.md`
- [ ] 4.2 Re-read both proposals' `distinct`-related scenarios end to end to
      confirm no other file assumes the bare-transducer return type

## 5. Validation
- [ ] 5.1 Run `openspec validate fix-core-architecture-spec-errors --strict`
- [ ] 5.2 Re-run `openspec validate add-core-architecture --strict` and
      `openspec validate add-advanced-data-integrity --strict` to confirm
      this change doesn't newly break either pending proposal
