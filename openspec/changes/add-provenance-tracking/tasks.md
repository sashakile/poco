## 1. RowId and provenance primitives
- [ ] 1.1 Define `RowId` (opaque, stable per source row) held alongside,
      not inside, the row-model dict
- [ ] 1.2 Define the `ProvenanceTransform` sealed hierarchy (`Bijection`,
      `Injection`, `Fibration`, `Span`)
- [ ] 1.3 Add the `PipelineStep` provenance component and its composition
      rule under `|`
- [ ] 1.4 Add an exhaustiveness test for `ProvenanceTransform`, mirroring
      the existing `SchemaTransform` exhaustiveness test

## 2. Fiber retention
- [ ] 2.1 Implement bare `po.groupby(*keys)` → `Fibers` (materializes the
      source plan, retains the fibration, terminal for `|`)
- [ ] 2.2 Implement `.aggregate(**named_reducers)` on `Fibers`, equivalent
      to piping the same aggregations into `po.groupby` with no re-execution
      of the source pipeline; expose the retained `Fibration` as `.fibers`
      on collapsed groupby results
- [ ] 2.3 Implement `.stats(key_or_selection, **named_reducers) -> dict`
      (one fiber, or the fibers touched by a `Selection`), without
      re-scanning the source

## 3. Selection algebra
- [ ] 3.1 Implement `Selection` (a set of `RowId`s plus a reference to its
      source `DataFrame`) and `df.select_rows(pred)` as its direct
      construction path
- [ ] 3.2 Implement `pull_back(selection) -> Selection` (output → source ids)
- [ ] 3.3 Implement `push_forward(selection, target) -> Selection` (source
      ids → output rows in `target` that touch them)
- [ ] 3.4 Implement `restrict(selection) -> DataFrame`
- [ ] 3.5 Raise `ValueError` when a `Selection` is used against a
      DataFrame that doesn't share its source lineage
- [ ] 3.6 Implement `Selection.union`/`.intersect`/`.difference`, each
      raising `ValueError` on mismatched source lineage
- [ ] 3.7 Add a `revision` field to `Selection`, assigned at interaction
      capture time; document the "discard non-increasing revisions"
      contract for consumers (no scheduling/cancellation logic is
      implemented in poco itself — this is a data contract, not a runtime)

## 3a. Multi-Fibration composition
- [ ] 3a.1 Add the reverse map (`RowId → key`) to `Fibration`, built
      eagerly alongside the forward map
- [ ] 3a.2 Implement `fiber_key_of(row_id)` as a direct reverse-map lookup
- [ ] 3a.3 Confirm `Selection.intersect` over fibration cuts composes via
      row-id set intersection, with no materialized cross-product structure
      and no structure indexed by the full key-combination space
- [ ] 3a.4 Confirm independently-built `Fibration`s over the same source
      recompute independently (changing one does not invalidate another)

## 4. Incremental reducers
- [ ] 4.1 Add the optional `unstep(acc, item)` phase to the reducer
      protocol
- [ ] 4.2 Implement `unstep` for `sum`, `count`, and `mean`
- [ ] 4.3 Confirm reducers without `unstep` (`min`, `max`, distinct-count)
      correctly fall back to full recompute on selection change

## 5. Exclusions
- [ ] 5.1 Confirm `distinct(ttl=...)` (from `add-advanced-data-integrity`)
      is rejected or documented as incompatible with provenance tracking,
      given its own non-determinism guarantee

## 6. Validation
- [ ] 6.1 Run `openspec validate add-provenance-tracking --strict`
- [ ] 6.2 Confirm pipelines using only `where`/`select`/`derive`/
      `sort_by`/`distinct` are behaviorally unchanged from
      `add-core-architecture` (no per-row provenance storage)
