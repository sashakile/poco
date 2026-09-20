# Change: Add provenance tracking for interactive, selection-preserving aggregation

## Why

`po.groupby(...)` currently collapses each group straight to an aggregate
row and discards which source rows produced it. That is correct for a
one-shot report and actively wrong for interactive visualization: once a bar
in a chart exists, there is no way back to "which rows are behind this bar,"
no way to compute a second statistic over the same group without re-running
the whole pipeline, and no way to define cross-filtering (click a mark in
one chart, highlight the corresponding rows in another) without
reconstructing a predicate — which breaks the moment the group key is
derived rather than a plain column, or the pipeline contains a join.

poco's own algebra already names the piece that's missing. Σ (dependent sum,
already cited in `project.md`'s Δ/Σ/Π framing) is not "one scalar per
group" — it is the indexed family of fibers (the groups themselves), and an
aggregate is a further reduction applied to each fiber afterward. The
current `groupby` implementation performs both steps at once and keeps only
the second. This proposal adds the missing piece — retained fibers and a
composable provenance map from every output row back to the source rows
that produced it — as a third component of `PipelineStep`, alongside the
existing `DataOp` and `SchemaTransform`.

The formal basis is standard database theory, not a new invention:
provenance semirings (Green, Karvounarakis & Tannen, "Provenance
Semirings," PODS 2007) model exactly this — annotating each output tuple
with the set (or polynomial) of source tuples that produced it, with
well-defined composition through selection, projection, and join.

## What Changes

- **ADD `provenance` capability**: a `ProvenanceTransform` sealed hierarchy
  (`Bijection`, `Injection`, `Fibration`, `Span` for joins) computed without
  touching row data, mirroring how `SchemaTransform` is computed; a stable
  `RowId` held alongside (not inside) the row-model dict; and a `Selection`
  type supporting `pull_back` (output rows → source row ids), `push_forward`
  (source row ids → output rows they touch), and `restrict` (selection →
  sub-DataFrame).
- **MODIFY `pipeline`**: `PipelineStep` carries a third component, the
  `ProvenanceTransform`, composed automatically alongside `DataOp` and
  `SchemaTransform` when steps are piped together via `|`.
- **MODIFY `relational`**: `po.groupby(*keys)` with no aggregation kwargs
  returns the retained fibration as a first-class `Fibers` value (terminal
  for `|`), and `po.groupby(*keys, **aggs)` collapses as before — except
  the `Fibration` is now always retained and exposed on the collapsed
  result as `.fibers`, so every aggregate row is traceable to the source
  rows that produced it. There is no `keep_fibers` flag: retention is
  unconditional because the fibration *is* the provenance.
- **MODIFY `reducer`**: adds an optional fourth phase, `unstep(acc, item)`,
  for reducers whose accumulator supports item removal (e.g. `sum`, `count`,
  `mean` as `(sum, count)`). Reducers that don't implement it fall back to a
  full recompute over the fiber when a selection shrinks. This is what makes
  changing selections in a linked view cheap for the common aggregates
  without requiring it for every reducer.
- **ADD to `provenance`** (informed by a comparison against Tray.jl, an
  unrelated OLAP-rollup library by the same author — see `design.md`'s
  "Related Work" for what was and wasn't adopted): a `Fibration` maintains
  its reverse map (row → group key), not just the forward one; `Selection`
  gains `union`/`intersect`/`difference`; multiple independent `Fibration`s
  built over the same source compose by row-id intersection rather than a
  materialized cross-product, generalizing two-view cross-filtering to any
  number of linked views; and `Selection` carries a `revision` so consumers
  can discard out-of-order completions during rapid interaction (brushing,
  panning) without flickering back to a stale state.

## Impact

- Affected specs: new `provenance` capability (ADDED); `pipeline`,
  `relational`, `reducer` (all in `add-core-architecture`, MODIFIED)
- Affected code: none yet (no implementation exists)
- Relationship to other pending proposals: this proposal SHALL be applied
  AFTER `add-backend-adapter-protocol` and builds on its `LogicalOp`
  reification (a provenance span attaches naturally to a `LogicalOp` node).
  Both proposals modify the same `pipeline` requirement ("PipelineStep
  SHALL only be constructed through validated factories"); this proposal's
  delta is written against the post-backend text of that requirement and
  reconciles the two by combining the `LogicalOp`-carrying `DataOp` with
  the `ProvenanceTransform` third component, so applying it after the
  backend change loses nothing. Also references `expression/spec.md`'s null
  strictness: an empty selection is the normal resting state of a
  cross-filtered view, so pipelines built for interactive use are expected
  to prefer total reducers (`count`, `sum`) over partial ones (`mean`) for
  values shown before a selection is made, or explicitly handle the
  `ValueError` a partial reducer raises on an empty fiber.
- Non-goals: no rendering layer, no charting library integration, no
  incremental-maintenance implementation beyond the optional `unstep` hook
  (full recompute remains correct, just not optimal, for reducers that don't
  implement it); no dependency on Tray.jl or any tree-structured backend —
  the multi-`Fibration` and revision-stamped requirements added here are
  specified so they can be implemented in plain Python (dicts and sets)
  today, and so that a future tree-backed `Backend` could accelerate them
  later without changing this proposal's public API
