## Context

Interactive visualization needs three things a plain aggregate query
doesn't give you: (1) selecting a mark and getting back the rows behind it,
(2) computing a second statistic over that same set without a rescan, and
(3) moving a selection from one view to another that shares the same
source. All three require keeping a reference from an output row to its
source rows — provenance — through every pipeline step, not just at
`groupby`.

Two existing prior-art approaches solve adjacent problems differently and
neither is what's needed here. Mosaic (Heer et al., UW Interactive Data
Lab) coordinates chart selections against DuckDB via query rewriting and
precomputed data cubes — fast at scale, but selections are predicate-based,
so they can't survive a derived key or a join the way an explicit row-id
based selection can. crossfilter.js solves incremental maintenance for
in-browser data well, without a general provenance model — it hardcodes the
group-by-dimension case. poco's opportunity is the one neither occupies: an
explicit, composable, algebraically-justified provenance layer, where
"this selection means the same thing in every linked view" is a consequence
of provenance composing as spans (per Green/Karvounarakis/Tannen's
provenance semirings) rather than a property some implementation happens to
preserve.

## Goals / Non-Goals

Goals:
- Every output row of a pipeline step SHALL be traceable back to the
  source rows that produced it, without re-executing the pipeline
- A fiber (the set of source rows behind one output row) SHALL be a plain
  iterable of rows, so any existing reducer works on it with no new
  protocol
- Provenance SHALL compose the same way `SchemaTransform` already does:
  computed from the plan, without touching data, and combined automatically
  by `|`
- This SHALL be strictly additive to `add-core-architecture` — nothing here
  changes behavior for a pipeline that never asks for provenance

Non-Goals:
- A rendering or charting integration — this proposal defines the data-side
  protocol only
- Incremental maintenance for every reducer — `unstep` is optional per
  reducer; reducers without it recompute fully on a shrinking selection
- Solving provenance through non-deterministic operations. `distinct(ttl=...)`
  (from `add-advanced-data-integrity`) is explicitly excluded — its own spec
  already states it is non-deterministic across re-execution, which makes
  a stable provenance mapping meaningless for that step
- Query optimization or predicate pushdown for provenance-tracked pipelines

## Related Work

Tray.jl (a balanced n-ary aggregation-tree / OLAP-rollup library, same
author) independently formalizes a piece of this problem more completely
than the original draft of this proposal did: its multidimensional-rollups
capability registers multiple independent groupings ("axes") over the same
immutable leaf set, each maintaining a leaf-ID membership map **and its
reverse**, and combines cuts from different axes by exact row-id
intersection with an explicit requirement never to materialize a
cross-product of the axes' key spaces. That is precisely the N-view
cross-filtering case this proposal's original `pull_back`/`push_forward`
requirements only stated for two views. Three of the requirements added
below (`Fibration`'s reverse map, multi-`Fibration` intersection, and
`Selection` set algebra) are this proposal adopting that formalization at
the API level. Tray.jl's actual tree-structured storage and its
O(log n) incremental-maintenance strategy (which, unlike this proposal's
`unstep`, does not require the reducer to be invertible — a plain monoid
suffices, so it also covers `min`/`max`) are **not** adopted here; that
would mean depending on Tray.jl's Julia runtime or reimplementing a
segment tree in Python, both out of scope for this change. It is noted in
Open Questions below as a candidate for a future `Backend` (see
`add-backend-adapter-protocol`), not committed to here.

## Decisions

- **Decision: `RowId` lives alongside rows, not inside them.** A
  provenance-tracked `DataFrame` carries a parallel `list[RowId]` (or
  equivalent index), not a reserved key injected into the row-model dict.
  - Alternatives considered: a reserved `__rowid__` key inside every row
    dict — rejected, because `row-model/spec.md` defines the row contract
    as exactly the user's declared columns, and injecting a reserved key
    would leak into `to_dict()`, `to_rows()`, schema inference, and every
    place that currently assumes "the row is exactly the schema." Keeping
    `RowId` external means `row-model/spec.md` needs no change at all.
- **Decision: provenance is a span (`output ← R → input`), not a bare
  function.** This covers the general case (an output row can trace to zero
  source rows for an unmatched outer join, one row for `where`/`select`, or
  many rows for `groupby`) with a single representation, and composes by
  pullback the same way the underlying category-theoretic framing already
  used for `SchemaTransform` composes.
  - Alternatives considered: a simple `output_id -> list[input_id]` function
    per step — rejected as a special case of the span that doesn't compose
    as cleanly through joins, where provenance is naturally a pair
    (left_id, right_id), not a single id.
- **Decision: fiber retention is unconditional; there is no `keep_fibers`
  flag.** Grouping produces a fibration; collapsing is a separate reduction
  applied to it. poco never discards the fibration to keep only the
  collapse: a bare `po.groupby(*keys)` returns the retained fibration as a
  first-class `Fibers` value, and an aggregating `po.groupby(*keys,
  **aggs)` collapses but still exposes its `Fibration` as `.fibers`, so
  every aggregate row stays traceable. This is the exact "which rows are
  behind this bar" capability this proposal exists to provide, available
  without remembering a flag.
  - Alternatives considered: an explicit `keep_fibers=True` opt-in —
    rejected. Its only argument (preserving the memory profile of existing
    pipelines) is moot: no code is deployed, the spec exists only on paper.
    Worse, a flag that gates provenance makes cross-filtering a footgun —
    forgetting the flag silently breaks every downstream `Selection` and
    `pull_back`. A future memory knob, if ever needed, SHALL be a global or
    per-backend setting, never a per-call flag.
- **Decision: `unstep` is optional, and its absence is not an error.**
  Total, invertible reducers (`sum`, `count`) implement it and get
  O(selection-size-delta) updates. Reducers like `min`/`max`/distinct-count
  are semigroup-only in the presence of removal and cannot implement it
  correctly (removing the current max doesn't tell you the new max) — they
  fall back to a full recompute over the fiber, which stays correct, just
  not incremental. This mirrors the same total/partial distinction
  `reducer/spec.md` already draws for empty-input behavior.

- **Decision: `Fibration` stores its reverse map (`RowId → key`) alongside
  the forward map (`key → RowId set`), computed once when the `Fibration`
  is built, not on demand.** Without it, answering "which group is this
  row in" requires scanning every fiber, which defeats the purpose of
  having retained fibers at all for row-level queries.
  - Alternatives considered: compute the reverse map lazily on first
    lookup and cache it — rejected as unnecessary complexity for this
    proposal's stated scope (small exploratory data, `O(n)` memory already
    accepted); building it eagerly alongside the forward map is a single
    pass over the same data already being grouped.
- **Decision: combining cuts from multiple independent `Fibration`s is
  row-id set intersection, not a join or cross-product of key spaces.**
  This keeps each bare `groupby(*keys)` call fully independent —
  built, queried, and recomputed on its own — while still letting a caller
  ask "rows in cut A and cut B" cheaply. It also means the number of
  `Fibration`s registered over one source doesn't multiply memory beyond
  each one's own `O(n)` cost; there is no combinatorial structure to store.
  - Alternatives considered: a materialized `groupby(dept, city)`-style
    joint fibration whenever two axes are queried together — rejected,
    since it forces a specific combination to be anticipated in advance
    and doesn't scale past a couple of axes queried together (the exact
    problem the "REQ-39"-style formulation in Tray.jl's
    multidimensional-rollups spec explicitly avoids).
- **Decision: `Selection` carries a `revision`, assigned at interaction
  time, and consumers are specified to discard out-of-order completions.**
  Interactive brushing/panning issues selection recomputation faster than
  it can be guaranteed to complete in order. Without a revision, a slow
  computation for an earlier drag position finishing after a faster one
  for a later position would visibly flicker the display backward.
  - Alternatives considered: debouncing or cancellation at the call site
    (only ever have one in-flight computation) — rejected as a UI-layer
    concern outside this proposal's scope (no rendering layer, per
    Non-Goals); a revision number is the minimal data-side primitive that
    lets *any* consumer, regardless of how it schedules work, implement
    the correct "latest wins" behavior itself.

## Risks / Trade-offs

- Retained fibers cost memory proportional to the source data, not the
  aggregate output. This is the right trade for poco's stated scope (small
  exploratory/teaching datasets) and the wrong one for large data — this
  proposal does not claim to scale past that scope. The retention cost is
  O(n) row-id sets, incurred only when a `groupby` or `join` materializes;
  the other factories' `ProvenanceTransform`s are metadata-only rules and
  cost nothing.
- A `Selection` computed against one provenance-tracked `DataFrame` is only
  meaningful against DataFrames sharing the same source lineage.
  `push_forward`/`pull_back` SHALL raise `ValueError` when given a
  `Selection` whose source doesn't match, rather than silently returning an
  empty or wrong result.

## Migration Plan

No running code exists yet. Pipelines using only `where`, `select`,
`derive`, `sort_by`, and `distinct` see no observable change from
`add-core-architecture` as currently specified; `groupby` results change
shape as specified above (bare form returns `Fibers`; aggregating form
exposes `.fibers`), which is safe because no implementation exists to
depend on the old shape.

## Open Questions

- Should `NullPolicy.PROPAGATE` (from `add-backend-adapter-protocol`, if
  accepted) become the recommended default specifically for provenance-
  tracked pipelines, since an empty selection reaching a partial reducer is
  an expected, not exceptional, state in interactive use? Left as a
  recommendation in `proposal.md` rather than a hard requirement here, since
  it would create a hard dependency on a separate, not-yet-accepted
  proposal.
- Should reducers that are monoid-but-not-group (`min`, `max`,
  distinct-count) get an incremental-maintenance path under a shrinking
  selection, beyond this proposal's `unstep`-only mechanism, which
  structurally cannot cover them (there is no inverse for "un-take-the-
  max")? A tree-structured index (the strategy Tray.jl's aggregation-tree
  capability uses: recompute only the O(log n) path from a changed leaf to
  the root, which works for any monoid payload, not just invertible ones)
  would close this gap, but that means a genuinely different execution
  strategy — not a Python-level accumulator trick — and is deferred to a
  future `Backend` proposal (see `add-backend-adapter-protocol`) rather
  than attempted here. For this proposal, `min`/`max`/distinct-count on a
  changing selection remain a correct full recompute, just not an
  incremental one.
- Should provenance track *weighted* contribution (how much of an
  aggregate a given source row is responsible for) rather than only *set
  membership* (which source rows contributed at all)? This would let a
  waterfall/contribution chart attribute a joint effect proportionally
  across contributing rows, the way Tray.jl's `AttributionPayload`
  (bucket-sum reconciliation, residual-gap assignment, declared allocation
  conventions) does — effectively a provenance-semiring instance valued in
  weighted contributions rather than plain row-id sets. Deferred: it's a
  materially bigger extension (a different kind of provenance value, not
  just a different composition rule) and no requirement in this proposal
  depends on it.
