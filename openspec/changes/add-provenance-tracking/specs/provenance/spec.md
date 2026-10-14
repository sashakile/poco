---
id: provenance
kind: intent
statement: "THE system SHALL retain stable row provenance via opaque RowIds, a sealed data-free ProvenanceTransform composing by pullback, Selection algebra with lineage checks, first-class Fibers, and monotonic revision stamping"
---

# Provenance tracking

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| prov.rowid_stable | invariant | Every row has a stable, opaque RowId held parallel to the row-model dict; the same source row receives the same RowId on every materialization | [[provenance]] |
| prov.nondeterministic_raise | invariant | A pipeline containing a wall-clock-dependent step raises `ValueError` naming that step when a provenance-materializing operation is executed | [[provenance]] |
| prov.rowid_not_exported | invariant | `to_dict`, `to_rows`, and schema inference expose exactly the schema's declared columns; RowIds are accessible only via provenance-aware APIs | [[provenance]] |
| prov.transform_sealed | invariant | ProvenanceTransform is a sealed, data-free hierarchy (Bijection, Injection, Fibration, Span) with the same exhaustiveness discipline as SchemaTransform | [[provenance]] |
| prov.fibration_reverse_map | invariant | A Fibration maintains forward and reverse maps so `fiber_key_of(row_id)` is a direct O(1) reverse lookup, never an iteration over fiber id sets | [[provenance]] |
| prov.transform_pullback | invariant | Composing two steps via `\|` composes their ProvenanceTransforms by pullback, for every variant combination, without re-evaluating predicates | [[provenance]] |
| prov.selection_ops | invariant | `pull_back`, `push_forward`, `restrict`, and `select_rows` follow the composed provenance in reverse or forward direction; mismatched source lineage raises `ValueError` | [[provenance]] |
| prov.fiber_stats_no_reexec | invariant | `Fibers.stats` reduces already-retained fibers with any reducer or aggregation factory without re-executing the source pipeline; partial reducers over empty intersections raise per reducer/spec.md | [[provenance]] |
| prov.fibers_surface | invariant | Fibers exposes `.keys` (first-appearance order), `fibers[key]` (KeyError on unknown key), `.aggregate`, `.stats`, and `.fiber_key_of`; an empty source yields empty Fibers | [[provenance]] |
| prov.fibers_terminal | invariant | Piping a Fibers value into any pipeline step raises `TypeError`; Fibers does not subclass DataFrame; bare groupby is terminal and materializes the source plan | [[provenance]] |
| prov.selection_algebra | invariant | Selection supports `union`, `intersect`, `difference` returning new Selections, raising `ValueError` when sources differ | [[provenance]] |
| prov.cuts_intersect | invariant | Cuts from independent Fibrations over the same source combine by row-id intersection, never by constructing a cross-product of key spaces; each Fibration recomputes independently | [[provenance]] |
| prov.revision_stamped | invariant | Every Selection carries a monotonic per-lineage revision; consumers discard updates whose revision is not strictly greater than the last applied | [[provenance]] |

## Model

### States

- `sourced`
- `transformed`
- `grouped`
- `selected`
- `revised`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_assign_ids | sourced | transformed | [[provenance.prov.rowid_stable]] |
| t_classify | transformed | transformed | [[provenance.prov.transform_sealed]] |
| t_group | transformed | grouped | [[provenance.prov.fibration_reverse_map]] |
| t_select | grouped | selected | [[provenance.prov.selection_ops]] |
| t_algebra | selected | selected | [[provenance.prov.selection_algebra]] |
| t_cut | selected | selected | [[provenance.prov.cuts_intersect]] |
| t_revise | selected | revised | [[provenance.prov.revision_stamped]] |
| t_reject_nondeterministic | transformed | sourced | [[provenance.prov.nondeterministic_raise]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.rowid_stable | unit | [[provenance.prov.rowid_stable]] | repeated materializations of the same source data | RowIds are identical across materializations |
| p.nondeterministic_raise | unit | [[provenance.prov.nondeterministic_raise]] | ttl-dependent pipelines plus provenance-materializing ops | `ValueError` names the offending step |
| p.rowid_not_exported | unit | [[provenance.prov.rowid_not_exported]] | exported structures of tracked DataFrames | output contains exactly the declared columns |
| p.transform_sealed | unit | [[provenance.prov.transform_sealed]] | every pipeline factory | each step's variant is correct (where→Injection, groupby→Fibration, join→Span) and matching is exhaustive |
| p.fibration_reverse_map | unit | [[provenance.prov.fibration_reverse_map]] | source RowIds of grouped frames | fiber_key_of returns via direct reverse lookup |
| p.transform_pullback | unit | [[provenance.prov.transform_pullback]] | compositions of steps of all variant combinations | fibers contain exactly the rows surviving both transforms; inspection is data-free |
| p.selection_ops | unit | [[provenance.prov.selection_ops]] | selections across shared and unrelated lineages | pull_back/push_forward/restrict/select_rows behave as specified; mismatches raise |
| p.fiber_stats_no_reexec | unit | [[provenance.prov.fiber_stats_no_reexec]] | fibers.stats calls over retained fibers | results come from retained fibers; the source pipeline is not re-executed |
| p.fibers_surface | unit | [[provenance.prov.fibers_surface]] | Fibers values including empty sources | keys order, getitem semantics, and empty-source behavior hold |
| p.fibers_terminal | unit | [[provenance.prov.fibers_terminal]] | attempts to pipe Fibers | `TypeError` is raised; Fibers is not a DataFrame |
| p.selection_algebra | unit | [[provenance.prov.selection_algebra]] | Selection pairs over shared and unrelated sources | set operations match set semantics; mismatches raise `ValueError` |
| p.cuts_intersect | unit | [[provenance.prov.cuts_intersect]] | cut pairs from independent Fibrations | intersection answers the query without any cross-product structure |
| p.revision_stamped | unit | [[provenance.prov.revision_stamped]] | out-of-order and in-order update sequences | consumers discard non-increasing revisions |

## Purpose

Give interactive views a stable, algebraically composable notion of row
identity so selections, groupings, and cross-filters can be combined and
reconciled without re-executing pipelines or silently regressing state.

## ADDED Requirements

### Requirement: RowId is a stable identity held alongside the row-model contract

Every row sourced from a `DataFrame` SHALL have a stable `RowId`, opaque to
user code, held in a structure parallel to the row-model dict (per
`row-model/spec.md`) rather than injected as a key inside it. `RowId`
assignment SHALL be stable across repeated materialization of the same
source data: the same source row SHALL receive the same `RowId` on every
materialization. This guarantee SHALL be scoped to pipelines whose every
step is deterministic per the determinism laws in `reducer/spec.md` and
`transducer/spec.md`: a pipeline containing a wall-clock-dependent step
(e.g. `distinct(ttl=...)`) SHALL raise `ValueError` — naming that step —
when a provenance-materializing operation (a bare `groupby` returning
`Fibers`, or any `Selection`-producing operation) is executed against it.

#### Scenario: RowId is stable across materializations

- **GIVEN** `df = po.DataFrame({"name": ["Ana", "Luis"]})`
- **WHEN** `df` is materialized twice (e.g. two calls to `list(df)`)
- **THEN** the `RowId` associated with the "Ana" row SHALL be identical
  both times

#### Scenario: Non-deterministic step raises on provenance materialization

- **GIVEN** `df` piped through `po.distinct(Person.id, ttl=60)` (per
  `add-advanced-data-integrity`'s transducer spec)
- **WHEN** `df | po.groupby(Person.dept)` is materialized
- **THEN** the system SHALL raise `ValueError` naming the `ttl`-dependent
  step as the reason provenance cannot be retained

### Requirement: RowId does not appear in exported structures

No export or inspection method SHALL expose `RowId` as part of the row
contract defined in `row-model/spec.md`: `to_dict()`, `to_rows()`, and
schema inference return exactly the schema's declared columns, and `RowId`s
are accessible only through the provenance-aware APIs specified in this
capability (`Selection`, `Fibers`, and their methods).

#### Scenario: RowId does not appear in exported structures

- **GIVEN** a provenance-tracked `DataFrame`
- **WHEN** `df.to_dict()` or `df.to_rows()` is called
- **THEN** the result SHALL contain exactly the schema's declared columns,
  with no `RowId` or reserved key present

### Requirement: ProvenanceTransform is a sealed, data-free hierarchy

`ProvenanceTransform` SHALL be a sealed type hierarchy computed from the
pipeline plan alone, without touching row data, mirroring how
`SchemaTransform` (`pipeline/spec.md`) is computed. Variants:
- `Bijection` — each output row corresponds to exactly one source row
  (`select`, `derive`, `sort_by`)
- `Injection` — each output row corresponds to exactly one source row, but
  not every source row appears in the output (`where`, `head`, `distinct`
  keeping one representative row per key)
- `Fibration` — each output row corresponds to a set of source rows
  (`groupby`, with or without aggregations). A `Fibration` SHALL
  maintain both the forward map (output key → set of source `RowId`s) and
  its reverse (source `RowId` → the output key whose fiber it belongs to),
  so that "which group is this row in" SHALL be a single reverse-map
  lookup (O(1) in the number of rows), never an iteration over the
  fibers' id sets.
- `Span` — each output row corresponds to a pair of source rows, one from
  each side, possibly with one side absent (`join`)

All code matching on `ProvenanceTransform` variants SHALL handle every
variant explicitly, with the same exhaustiveness discipline
`pipeline/spec.md` requires for `SchemaTransform` (explicit unreachable
default branch, `typing.assert_never()` under static type-checking, a
runtime exhaustiveness test for unsupported variants).

#### Scenario: where produces an Injection

- **WHEN** `po.where(Person.age > 25)` is applied
- **THEN** the resulting step's `ProvenanceTransform` SHALL be `Injection`

#### Scenario: groupby produces a Fibration

- **WHEN** `po.groupby(Person.dept)` — with or without aggregation kwargs —
  is applied
- **THEN** the resulting step's `ProvenanceTransform` SHALL be `Fibration`

#### Scenario: join produces a Span

- **WHEN** `po.join(other, on=Person.dept_id)` is applied
- **THEN** the resulting step's `ProvenanceTransform` SHALL be `Span`

#### Scenario: Fibration reverse lookup is direct

- **GIVEN** `fibers = df | po.groupby(Person.dept)`
- **WHEN** `fibers.fiber_key_of(row_id)` is called for a source row's `RowId`
- **THEN** the result SHALL be that row's `dept` value, returned by direct
  lookup against the `Fibration`'s reverse map, without iterating any
  fiber's contents

#### Scenario: New variant causes type error in unhandled match

- **WHEN** a new `ProvenanceTransform` variant is added
- **THEN** any code that matches on `ProvenanceTransform` variants without
  handling the new variant SHALL fail either in static analysis or in the
  runtime exhaustiveness test

### Requirement: ProvenanceTransform composes by pullback under `|`

The `ProvenanceTransform`s of two `PipelineStep`s composed via `|` SHALL
compose by pullback: the composed span's relation is the pullback of the
two constituent spans over their shared row set. This SHALL hold
regardless of which `ProvenanceTransform` variants are being composed
(e.g. `Injection` then `Fibration` composes to a `Fibration` whose fibers
are restricted to the rows that survived the `Injection`).

#### Scenario: Filter then groupby composes correctly

- **GIVEN** `step = po.where(Person.age > 25) | po.groupby(Person.dept)`
- **WHEN** `step` is applied to a `DataFrame`
- **THEN** each resulting fiber SHALL contain only source rows that both
  passed the `where` filter and share that `dept` value
- **AND** this SHALL hold without re-evaluating the `where` predicate a
  second time outside of normal execution

#### Scenario: Provenance is inspectable without materialization

- **GIVEN** `step = po.where(Person.age > 25) | po.select(Person.name)`
- **WHEN** `step`'s provenance is inspected before any `DataFrame` is piped
  through it
- **THEN** the composed `ProvenanceTransform` SHALL be `Injection`
- **AND** no row data SHALL be processed to determine this

### Requirement: Selection supports pull_back, push_forward, and restrict

A `Selection` SHALL represent a set of `RowId`s together with a reference to
the `DataFrame` (and its underlying source) it was computed against. The
system SHALL provide:
- `df.pull_back(selection) -> Selection` — given a selection of `df`'s
  output rows, returns the selection of source rows that produced them,
  by following the composed `ProvenanceTransform` in reverse
- `df.push_forward(selection, target) -> Selection` — given a selection of
  source rows, returns the selection of `target`'s output rows that trace
  back to any of them, where `target` shares the same source
- `df.restrict(selection) -> DataFrame` — returns the sub-DataFrame of `df`
  containing exactly the rows identified by `selection`
- `df.select_rows(pred) -> Selection` — a `Selection` of the rows of `df`
  for which the expression `pred` evaluates truthily; this is the direct
  construction path for `Selection`s

`pull_back` and `push_forward` SHALL raise `ValueError` when the given
`Selection` does not share source lineage with `df` or `target`.

#### Scenario: Selecting a group pulls back to its member rows

- **GIVEN** `grouped = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **AND** `sel_out` is a `Selection` of `grouped`'s output rows containing
  the single output row whose key is `"engineering"`
- **WHEN** `grouped.pull_back(sel_out)` is called
- **THEN** the result SHALL be a `Selection` of every source row whose
  `dept` was `"engineering"`, recovered from the retained `Fibration`
  without re-evaluating any predicate

#### Scenario: Cross-filtering between two views of the same source

- **GIVEN** `chart_a` and `chart_b` are both derived from the same source
  `DataFrame` via different pipelines
- **WHEN** a selection is made on `chart_a` and pulled back to source rows,
  then pushed forward into `chart_b`
- **THEN** `chart_b`'s resulting `Selection` SHALL contain exactly the rows
  of `chart_b` whose provenance includes at least one of the selected
  source rows

#### Scenario: restrict returns a filtered sub-DataFrame

- **GIVEN** a `Selection` of two source `RowId`s
- **WHEN** `df.restrict(selection)` is called
- **THEN** the result SHALL be a `DataFrame` containing exactly those two
  rows, with the same schema as `df`

#### Scenario: select_rows constructs a Selection directly

- **WHEN** `sel = df.select_rows(Person.age > 30)`
- **THEN** `sel` SHALL be a `Selection` of exactly the rows of `df` whose
  `age` is greater than `30`
- **AND** constructing it SHALL materialize `df`'s plan if `df` was
  uncollected

#### Scenario: restrict with an empty Selection yields an empty DataFrame

- **GIVEN** `sel = df.select_rows(Person.age > 200)` on data where no row
  qualifies
- **WHEN** `df.restrict(sel)` is called
- **THEN** the result SHALL be a `DataFrame` with `df`'s schema and zero
  rows

#### Scenario: Selection from an unrelated source raises

- **GIVEN** `df1` and `df2` are constructed from unrelated data with no
  shared lineage
- **WHEN** `df1.pull_back(selection_from_df2)` is called
- **THEN** the system SHALL raise `ValueError` indicating the selection's
  source does not match `df1`'s source

### Requirement: Sub-statistics reuse the existing reducer protocol over a fiber

Each fiber's rows SHALL be obtainable without re-executing the pipeline
that produced the fibration: for a `Fibers` value `fibers` over source
`df`, `df.restrict(fibers[key])` SHALL be the `DataFrame` of exactly that
fiber's rows.

`Fibers.stats(key_or_selection, **named_reducers)` SHALL reduce one fiber —
or the fibers touched by a `Selection` — using any reducer defined per
`reducer/spec.md` or column-bound aggregation factory per
`aggregation/spec.md`, over the already-retained fibers, and SHALL return a
`dict[str, object]` of the completed results. This SHALL NOT re-execute the
source `DataFrame`'s pipeline. It is distinct from
`Fibers.aggregate(**named_reducers)` (per `relational/spec.md`), which
reduces every fiber and returns the collapsed `DataFrame`.

#### Scenario: Computing an additional statistic without re-scanning

- **GIVEN** `fibers = df | po.groupby(Person.dept)` and
  `fibers.aggregate(total=po.sum_of(Person.salary))` was already computed
- **WHEN** `fibers.stats("engineering", top=po.max_of(Person.salary),
  n=po.count_of())` is called
- **THEN** `top` and `n` SHALL be computed by reducing over the
  already-retained `"engineering"` fiber
- **AND** the result SHALL be a `dict` with keys `top` and `n`
- **AND** the source `DataFrame`'s pipeline SHALL NOT be re-executed

#### Scenario: Stats over a selection reduces each touched fiber

- **GIVEN** `fibers = df | po.groupby(Person.dept)` and `sel` is a
  `Selection` of source rows spanning the `"engineering"` and `"design"`
  fibers
- **WHEN** `fibers.stats(sel, n=po.count_of())` is called
- **THEN** `n` SHALL be computed once per touched fiber, over that fiber's
  intersection with the selection

#### Scenario: Empty fiber with a partial reducer

- **GIVEN** `sel` is a `Selection` whose intersection with the
  `"design"` fiber is empty (e.g. after cross-filtering removes all rows
  for `"design"`)
- **WHEN** `fibers.stats(sel, avg=po.mean_of(Person.salary))` is called
- **THEN** `ValueError` SHALL be raised, per `reducer/spec.md`'s existing
  empty-input behavior for partial reducers — this requirement does not
  change reducer semantics, only where the fiber comes from

### Requirement: Fibers is the first-class fibration object

`Fibers` SHALL be the public value produced by `po.groupby` with no
aggregation kwarg arguments (per `relational/spec.md`'s "Groupby as
relational pipeline step"), wrapping the retained `Fibration` over its
source `DataFrame`. A `Fibers` value SHALL expose:
- `.keys` — the distinct group keys, in first-appearance order
- `fibers[key]` — the `Selection` of source rows whose group key equals
  `key`
- `.aggregate(**named_reducers)` — the collapsed `DataFrame`, per
  `relational/spec.md`'s aggregation-equivalence requirement
- `.stats(key_or_selection, **named_reducers)` — sub-statistics over one
  fiber or the fibers touched by a `Selection`, per the "Sub-statistics
  reuse the existing reducer protocol over a fiber" requirement
- `.fiber_key_of(row_id)` — the group key of a source row, by direct
  reverse-map lookup

Illustrative public signatures (the bullets above are normative):

```python
class Fibers:
    keys: list                                   # first-appearance order
    def __getitem__(self, key) -> Selection: ...
    def aggregate(self, **named_reducers) -> DataFrame: ...
    def stats(self, key_or_selection, **named_reducers) -> dict: ...
    def fiber_key_of(self, row_id) -> object: ...
```

`Fibers` SHALL be terminal for `|`: piping a `Fibers` value into any
pipeline step SHALL raise `TypeError`. `Fibers` SHALL NOT subclass
`DataFrame`. Piping a bare `po.groupby` into a `DataFrame` SHALL materialize
the source plan — it is a terminal operation, like `to_dict`.

#### Scenario: Indexing a Fibers value yields a source-row Selection

- **GIVEN** `fibers = df | po.groupby(Person.dept)`
- **WHEN** `fibers["engineering"]` is taken
- **THEN** the result SHALL be a `Selection` of exactly the source rows
  whose `dept` equals `"engineering"`

#### Scenario: Fibers is terminal for |

- **GIVEN** `fibers = df | po.groupby(Person.dept)`
- **WHEN** `fibers | po.where(Person.age > 25)` is written
- **THEN** the system SHALL raise `TypeError`

#### Scenario: Keys are ordered by first appearance

- **GIVEN** a `df` whose `dept` values first appear in the order
  `"eng", "design", "eng"`
- **WHEN** `fibers.keys` is read from `df | po.groupby(Person.dept)`
- **THEN** the result SHALL be `["eng", "design"]`

#### Scenario: Unknown key raises KeyError

- **GIVEN** `fibers = df | po.groupby(Person.dept)` where no row has
  `dept == "sales"`
- **WHEN** `fibers["sales"]` is taken
- **THEN** the system SHALL raise `KeyError`

#### Scenario: Empty source yields empty Fibers

- **GIVEN** a `df` with zero rows
- **WHEN** `fibers = df | po.groupby(Person.dept)` is materialized
- **THEN** `fibers.keys` SHALL be `[]`
- **AND** `fibers.aggregate(n=po.count_of())` SHALL be an empty `DataFrame`
  containing only the `dept` column

### Requirement: Selection supports set algebra

`Selection` SHALL support `union`, `intersect`, and `difference` against
another `Selection`, each returning a new `Selection`. These operations
SHALL raise `ValueError` when the two selections do not share the same
underlying source, per the "Selection from an unrelated source raises"
scenario above. This is what allows combining brushes from more than one
linked view (e.g. "rows selected in chart A AND rows selected in chart B")
without either chart needing to know about the other's pipeline.

#### Scenario: Intersecting two brushes over the same source

- **GIVEN** `sel_a` (from a brush on `chart_a`) and `sel_b` (from a brush on
  `chart_b`), both pulled back to the same source `df`
- **WHEN** `sel_a.intersect(sel_b)` is called
- **THEN** the result SHALL be a `Selection` containing exactly the source
  `RowId`s present in both `sel_a` and `sel_b`

#### Scenario: Set algebra across unrelated sources raises

- **GIVEN** `sel_a` from `df1` and `sel_c` from unrelated `df2`
- **WHEN** `sel_a.union(sel_c)` is called
- **THEN** the system SHALL raise `ValueError`, per the existing
  cross-source rule

### Requirement: Fibration cuts combine by row-id intersection, never by cross-product

Cuts combined across multiple independent `Fibration`s SHALL be answered by
`Selection.intersect` on the cuts (each cut being a `Selection` over the
same source), which SHALL intersect the row-id sets for the requested keys,
never by constructing a cross-product, when the `Fibration`s are built over
the same source `DataFrame`. For example,
when a source feeds one `groupby(Person.dept)` and a
separate `groupby(Person.city)`, the query "rows where
dept is X and city is Y" SHALL be answered by
`by_dept[X].intersect(by_city[Y])`. The system SHALL NOT construct or require a
materialized join or cross-product of the two `Fibration`s' full key
spaces; each `Fibration` SHALL remain independently queryable and
independently recomputable if its own pipeline changes, without affecting
the other.

This generalizes the two-view `pull_back`/`push_forward` case (see
"Selection supports pull_back, push_forward, and restrict") to combining
cuts from any number of independently-built `Fibration`s over the same
source.

#### Scenario: Combine a dept cut and a city cut without a cross-product

- **GIVEN** `by_dept = df | po.groupby(Person.dept)` and
  `by_city = df | po.groupby(Person.city)`, both over the
  same `df`
- **WHEN** `by_dept["engineering"].intersect(by_city["nyc"])` is
  called
- **THEN** the result SHALL be a `Selection` of exactly the source rows
  where `dept == "engineering"` and `city == "nyc"`
- **AND** no structure indexed by the full `(dept, city)` combination space
  SHALL be built to answer it

#### Scenario: Independent Fibrations recompute independently

- **GIVEN** `by_dept` and `by_city` as above
- **WHEN** `by_city`'s source pipeline changes (e.g. a new `where` filter is
  added before the `groupby`) and `by_city` is recomputed
- **THEN** `by_dept`'s previously computed `Fibration` SHALL be unaffected
  and SHALL NOT require recomputation

### Requirement: Selection updates are revision-stamped so consumers can discard superseded results

Every `Selection` SHALL carry a `revision: int`. The system SHALL maintain
one monotonic revision counter per source lineage: every `Selection`-
producing operation (`df.select_rows(...)`, `fibers[key]`,
`df.pull_back(...)`, `df.push_forward(...)`, and `union`/`intersect`/
`difference`) SHALL assign the counter's next value to its result at
creation time. A consumer applying a sequence of `Selection` updates (e.g. a
linked chart re-rendering on each cross-filter event) SHALL discard any
incoming update whose `revision` is not strictly greater than the last
revision it applied, even if that update's computation happened to finish
after a later one's.

This exists because interactive selection is not requested at a rate that
guarantees in-order completion: `pull_back`/`push_forward`/`.stats(...)`
calls triggered in quick succession (e.g. during a drag) may finish out of
order, and a naive "apply whatever arrives" consumer would flicker between
a newer and an older selection state.

#### Scenario: Out-of-order completion does not regress the displayed selection

- **GIVEN** a user drags a brush, triggering selection computations at
  revisions `1`, `2`, and `3` in that order
- **WHEN** the computation for revision `2` finishes after the computation
  for revision `3` has already been applied
- **THEN** the consumer SHALL discard the revision-`2` result and SHALL
  continue displaying the revision-`3` result

#### Scenario: In-order completion applies normally

- **GIVEN** selection computations complete in the same order they were
  requested
- **WHEN** each result arrives
- **THEN** each SHALL be applied, since each carries a strictly greater
  revision than the last applied one

#### Scenario: Derived selections carry a fresh revision

- **GIVEN** `sel_a` carrying revision `7`
- **WHEN** `sel_a.intersect(sel_b)` is computed
- **THEN** the result SHALL carry a revision strictly greater than every
  revision previously issued for the source lineage

## Requirements

### Requirement: RowId is a stable identity held alongside the row-model contract

Every row sourced from a `DataFrame` SHALL have a stable `RowId`, opaque to
user code, held in a structure parallel to the row-model dict (per
`row-model/spec.md`) rather than injected as a key inside it. `RowId`
assignment SHALL be stable across repeated materialization of the same
source data: the same source row SHALL receive the same `RowId` on every
materialization. This guarantee SHALL be scoped to pipelines whose every
step is deterministic per the determinism laws in `reducer/spec.md` and
`transducer/spec.md`: a pipeline containing a wall-clock-dependent step
(e.g. `distinct(ttl=...)`) SHALL raise `ValueError` — naming that step —
when a provenance-materializing operation (a bare `groupby` returning
`Fibers`, or any `Selection`-producing operation) is executed against it.

#### Scenario: RowId is stable across materializations

- **GIVEN** `df = po.DataFrame({"name": ["Ana", "Luis"]})`
- **WHEN** `df` is materialized twice (e.g. two calls to `list(df)`)
- **THEN** the `RowId` associated with the "Ana" row SHALL be identical
  both times

#### Scenario: Non-deterministic step raises on provenance materialization

- **GIVEN** `df` piped through `po.distinct(Person.id, ttl=60)` (per
  `add-advanced-data-integrity`'s transducer spec)
- **WHEN** `df | po.groupby(Person.dept)` is materialized
- **THEN** the system SHALL raise `ValueError` naming the `ttl`-dependent
  step as the reason provenance cannot be retained

### Requirement: RowId does not appear in exported structures

No export or inspection method SHALL expose `RowId` as part of the row
contract defined in `row-model/spec.md`: `to_dict()`, `to_rows()`, and
schema inference return exactly the schema's declared columns, and `RowId`s
are accessible only through the provenance-aware APIs specified in this
capability (`Selection`, `Fibers`, and their methods).

#### Scenario: RowId does not appear in exported structures

- **GIVEN** a provenance-tracked `DataFrame`
- **WHEN** `df.to_dict()` or `df.to_rows()` is called
- **THEN** the result SHALL contain exactly the schema's declared columns,
  with no `RowId` or reserved key present

### Requirement: ProvenanceTransform is a sealed, data-free hierarchy

`ProvenanceTransform` SHALL be a sealed type hierarchy computed from the
pipeline plan alone, without touching row data, mirroring how
`SchemaTransform` (`pipeline/spec.md`) is computed. Variants:
- `Bijection` — each output row corresponds to exactly one source row
  (`select`, `derive`, `sort_by`)
- `Injection` — each output row corresponds to exactly one source row, but
  not every source row appears in the output (`where`, `head`, `distinct`
  keeping one representative row per key)
- `Fibration` — each output row corresponds to a set of source rows
  (`groupby`, with or without aggregations). A `Fibration` SHALL
  maintain both the forward map (output key → set of source `RowId`s) and
  its reverse (source `RowId` → the output key whose fiber it belongs to),
  so that "which group is this row in" SHALL be a single reverse-map
  lookup (O(1) in the number of rows), never an iteration over the
  fibers' id sets.
- `Span` — each output row corresponds to a pair of source rows, one from
  each side, possibly with one side absent (`join`)

All code matching on `ProvenanceTransform` variants SHALL handle every
variant explicitly, with the same exhaustiveness discipline
`pipeline/spec.md` requires for `SchemaTransform` (explicit unreachable
default branch, `typing.assert_never()` under static type-checking, a
runtime exhaustiveness test for unsupported variants).

#### Scenario: where produces an Injection

- **WHEN** `po.where(Person.age > 25)` is applied
- **THEN** the resulting step's `ProvenanceTransform` SHALL be `Injection`

#### Scenario: groupby produces a Fibration

- **WHEN** `po.groupby(Person.dept)` — with or without aggregation kwargs —
  is applied
- **THEN** the resulting step's `ProvenanceTransform` SHALL be `Fibration`

#### Scenario: join produces a Span

- **WHEN** `po.join(other, on=Person.dept_id)` is applied
- **THEN** the resulting step's `ProvenanceTransform` SHALL be `Span`

#### Scenario: Fibration reverse lookup is direct

- **GIVEN** `fibers = df | po.groupby(Person.dept)`
- **WHEN** `fibers.fiber_key_of(row_id)` is called for a source row's `RowId`
- **THEN** the result SHALL be that row's `dept` value, returned by direct
  lookup against the `Fibration`'s reverse map, without iterating any
  fiber's contents

#### Scenario: New variant causes type error in unhandled match

- **WHEN** a new `ProvenanceTransform` variant is added
- **THEN** any code that matches on `ProvenanceTransform` variants without
  handling the new variant SHALL fail either in static analysis or in the
  runtime exhaustiveness test

### Requirement: ProvenanceTransform composes by pullback under `|`

The `ProvenanceTransform`s of two `PipelineStep`s composed via `|` SHALL
compose by pullback: the composed span's relation is the pullback of the
two constituent spans over their shared row set. This SHALL hold
regardless of which `ProvenanceTransform` variants are being composed
(e.g. `Injection` then `Fibration` composes to a `Fibration` whose fibers
are restricted to the rows that survived the `Injection`).

#### Scenario: Filter then groupby composes correctly

- **GIVEN** `step = po.where(Person.age > 25) | po.groupby(Person.dept)`
- **WHEN** `step` is applied to a `DataFrame`
- **THEN** each resulting fiber SHALL contain only source rows that both
  passed the `where` filter and share that `dept` value
- **AND** this SHALL hold without re-evaluating the `where` predicate a
  second time outside of normal execution

#### Scenario: Provenance is inspectable without materialization

- **GIVEN** `step = po.where(Person.age > 25) | po.select(Person.name)`
- **WHEN** `step`'s provenance is inspected before any `DataFrame` is piped
  through it
- **THEN** the composed `ProvenanceTransform` SHALL be `Injection`
- **AND** no row data SHALL be processed to determine this

### Requirement: Selection supports pull_back, push_forward, and restrict

A `Selection` SHALL represent a set of `RowId`s together with a reference to
the `DataFrame` (and its underlying source) it was computed against. The
system SHALL provide:
- `df.pull_back(selection) -> Selection` — given a selection of `df`'s
  output rows, returns the selection of source rows that produced them,
  by following the composed `ProvenanceTransform` in reverse
- `df.push_forward(selection, target) -> Selection` — given a selection of
  source rows, returns the selection of `target`'s output rows that trace
  back to any of them, where `target` shares the same source
- `df.restrict(selection) -> DataFrame` — returns the sub-DataFrame of `df`
  containing exactly the rows identified by `selection`
- `df.select_rows(pred) -> Selection` — a `Selection` of the rows of `df`
  for which the expression `pred` evaluates truthily; this is the direct
  construction path for `Selection`s

`pull_back` and `push_forward` SHALL raise `ValueError` when the given
`Selection` does not share source lineage with `df` or `target`.

#### Scenario: Selecting a group pulls back to its member rows

- **GIVEN** `grouped = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **AND** `sel_out` is a `Selection` of `grouped`'s output rows containing
  the single output row whose key is `"engineering"`
- **WHEN** `grouped.pull_back(sel_out)` is called
- **THEN** the result SHALL be a `Selection` of every source row whose
  `dept` was `"engineering"`, recovered from the retained `Fibration`
  without re-evaluating any predicate

#### Scenario: Cross-filtering between two views of the same source

- **GIVEN** `chart_a` and `chart_b` are both derived from the same source
  `DataFrame` via different pipelines
- **WHEN** a selection is made on `chart_a` and pulled back to source rows,
  then pushed forward into `chart_b`
- **THEN** `chart_b`'s resulting `Selection` SHALL contain exactly the rows
  of `chart_b` whose provenance includes at least one of the selected
  source rows

#### Scenario: restrict returns a filtered sub-DataFrame

- **GIVEN** a `Selection` of two source `RowId`s
- **WHEN** `df.restrict(selection)` is called
- **THEN** the result SHALL be a `DataFrame` containing exactly those two
  rows, with the same schema as `df`

#### Scenario: select_rows constructs a Selection directly

- **WHEN** `sel = df.select_rows(Person.age > 30)`
- **THEN** `sel` SHALL be a `Selection` of exactly the rows of `df` whose
  `age` is greater than `30`
- **AND** constructing it SHALL materialize `df`'s plan if `df` was
  uncollected

#### Scenario: restrict with an empty Selection yields an empty DataFrame

- **GIVEN** `sel = df.select_rows(Person.age > 200)` on data where no row
  qualifies
- **WHEN** `df.restrict(sel)` is called
- **THEN** the result SHALL be a `DataFrame` with `df`'s schema and zero
  rows

#### Scenario: Selection from an unrelated source raises

- **GIVEN** `df1` and `df2` are constructed from unrelated data with no
  shared lineage
- **WHEN** `df1.pull_back(selection_from_df2)` is called
- **THEN** the system SHALL raise `ValueError` indicating the selection's
  source does not match `df1`'s source

### Requirement: Sub-statistics reuse the existing reducer protocol over a fiber

Each fiber's rows SHALL be obtainable without re-executing the pipeline
that produced the fibration: for a `Fibers` value `fibers` over source
`df`, `df.restrict(fibers[key])` SHALL be the `DataFrame` of exactly that
fiber's rows.

`Fibers.stats(key_or_selection, **named_reducers)` SHALL reduce one fiber —
or the fibers touched by a `Selection` — using any reducer defined per
`reducer/spec.md` or column-bound aggregation factory per
`aggregation/spec.md`, over the already-retained fibers, and SHALL return a
`dict[str, object]` of the completed results. This SHALL NOT re-execute the
source `DataFrame`'s pipeline. It is distinct from
`Fibers.aggregate(**named_reducers)` (per `relational/spec.md`), which
reduces every fiber and returns the collapsed `DataFrame`.

#### Scenario: Computing an additional statistic without re-scanning

- **GIVEN** `fibers = df | po.groupby(Person.dept)` and
  `fibers.aggregate(total=po.sum_of(Person.salary))` was already computed
- **WHEN** `fibers.stats("engineering", top=po.max_of(Person.salary),
  n=po.count_of())` is called
- **THEN** `top` and `n` SHALL be computed by reducing over the
  already-retained `"engineering"` fiber
- **AND** the result SHALL be a `dict` with keys `top` and `n`
- **AND** the source `DataFrame`'s pipeline SHALL NOT be re-executed

#### Scenario: Stats over a selection reduces each touched fiber

- **GIVEN** `fibers = df | po.groupby(Person.dept)` and `sel` is a
  `Selection` of source rows spanning the `"engineering"` and `"design"`
  fibers
- **WHEN** `fibers.stats(sel, n=po.count_of())` is called
- **THEN** `n` SHALL be computed once per touched fiber, over that fiber's
  intersection with the selection

#### Scenario: Empty fiber with a partial reducer

- **GIVEN** `sel` is a `Selection` whose intersection with the
  `"design"` fiber is empty (e.g. after cross-filtering removes all rows
  for `"design"`)
- **WHEN** `fibers.stats(sel, avg=po.mean_of(Person.salary))` is called
- **THEN** `ValueError` SHALL be raised, per `reducer/spec.md`'s existing
  empty-input behavior for partial reducers — this requirement does not
  change reducer semantics, only where the fiber comes from

### Requirement: Fibers is the first-class fibration object

`Fibers` SHALL be the public value produced by `po.groupby` with no
aggregation kwarg arguments (per `relational/spec.md`'s "Groupby as
relational pipeline step"), wrapping the retained `Fibration` over its
source `DataFrame`. A `Fibers` value SHALL expose:
- `.keys` — the distinct group keys, in first-appearance order
- `fibers[key]` — the `Selection` of source rows whose group key equals
  `key`
- `.aggregate(**named_reducers)` — the collapsed `DataFrame`, per
  `relational/spec.md`'s aggregation-equivalence requirement
- `.stats(key_or_selection, **named_reducers)` — sub-statistics over one
  fiber or the fibers touched by a `Selection`, per the "Sub-statistics
  reuse the existing reducer protocol over a fiber" requirement
- `.fiber_key_of(row_id)` — the group key of a source row, by direct
  reverse-map lookup

Illustrative public signatures (the bullets above are normative):

```python
class Fibers:
    keys: list                                   # first-appearance order
    def __getitem__(self, key) -> Selection: ...
    def aggregate(self, **named_reducers) -> DataFrame: ...
    def stats(self, key_or_selection, **named_reducers) -> dict: ...
    def fiber_key_of(self, row_id) -> object: ...
```

`Fibers` SHALL be terminal for `|`: piping a `Fibers` value into any
pipeline step SHALL raise `TypeError`. `Fibers` SHALL NOT subclass
`DataFrame`. Piping a bare `po.groupby` into a `DataFrame` SHALL materialize
the source plan — it is a terminal operation, like `to_dict`.

#### Scenario: Indexing a Fibers value yields a source-row Selection

- **GIVEN** `fibers = df | po.groupby(Person.dept)`
- **WHEN** `fibers["engineering"]` is taken
- **THEN** the result SHALL be a `Selection` of exactly the source rows
  whose `dept` equals `"engineering"`

#### Scenario: Fibers is terminal for |

- **GIVEN** `fibers = df | po.groupby(Person.dept)`
- **WHEN** `fibers | po.where(Person.age > 25)` is written
- **THEN** the system SHALL raise `TypeError`

#### Scenario: Keys are ordered by first appearance

- **GIVEN** a `df` whose `dept` values first appear in the order
  `"eng", "design", "eng"`
- **WHEN** `fibers.keys` is read from `df | po.groupby(Person.dept)`
- **THEN** the result SHALL be `["eng", "design"]`

#### Scenario: Unknown key raises KeyError

- **GIVEN** `fibers = df | po.groupby(Person.dept)` where no row has
  `dept == "sales"`
- **WHEN** `fibers["sales"]` is taken
- **THEN** the system SHALL raise `KeyError`

#### Scenario: Empty source yields empty Fibers

- **GIVEN** a `df` with zero rows
- **WHEN** `fibers = df | po.groupby(Person.dept)` is materialized
- **THEN** `fibers.keys` SHALL be `[]`
- **AND** `fibers.aggregate(n=po.count_of())` SHALL be an empty `DataFrame`
  containing only the `dept` column

### Requirement: Selection supports set algebra

`Selection` SHALL support `union`, `intersect`, and `difference` against
another `Selection`, each returning a new `Selection`. These operations
SHALL raise `ValueError` when the two selections do not share the same
underlying source, per the "Selection from an unrelated source raises"
scenario above. This is what allows combining brushes from more than one
linked view (e.g. "rows selected in chart A AND rows selected in chart B")
without either chart needing to know about the other's pipeline.

#### Scenario: Intersecting two brushes over the same source

- **GIVEN** `sel_a` (from a brush on `chart_a`) and `sel_b` (from a brush on
  `chart_b`), both pulled back to the same source `df`
- **WHEN** `sel_a.intersect(sel_b)` is called
- **THEN** the result SHALL be a `Selection` containing exactly the source
  `RowId`s present in both `sel_a` and `sel_b`

#### Scenario: Set algebra across unrelated sources raises

- **GIVEN** `sel_a` from `df1` and `sel_c` from unrelated `df2`
- **WHEN** `sel_a.union(sel_c)` is called
- **THEN** the system SHALL raise `ValueError`, per the existing
  cross-source rule

### Requirement: Fibration cuts combine by row-id intersection, never by cross-product

Cuts combined across multiple independent `Fibration`s SHALL be answered by
`Selection.intersect` on the cuts (each cut being a `Selection` over the
same source), which SHALL intersect the row-id sets for the requested keys,
never by constructing a cross-product, when the `Fibration`s are built over
the same source `DataFrame`. For example,
when a source feeds one `groupby(Person.dept)` and a
separate `groupby(Person.city)`, the query "rows where
dept is X and city is Y" SHALL be answered by
`by_dept[X].intersect(by_city[Y])`. The system SHALL NOT construct or require a
materialized join or cross-product of the two `Fibration`s' full key
spaces; each `Fibration` SHALL remain independently queryable and
independently recomputable if its own pipeline changes, without affecting
the other.

This generalizes the two-view `pull_back`/`push_forward` case (see
"Selection supports pull_back, push_forward, and restrict") to combining
cuts from any number of independently-built `Fibration`s over the same
source.

#### Scenario: Combine a dept cut and a city cut without a cross-product

- **GIVEN** `by_dept = df | po.groupby(Person.dept)` and
  `by_city = df | po.groupby(Person.city)`, both over the
  same `df`
- **WHEN** `by_dept["engineering"].intersect(by_city["nyc"])` is
  called
- **THEN** the result SHALL be a `Selection` of exactly the source rows
  where `dept == "engineering"` and `city == "nyc"`
- **AND** no structure indexed by the full `(dept, city)` combination space
  SHALL be built to answer it

#### Scenario: Independent Fibrations recompute independently

- **GIVEN** `by_dept` and `by_city` as above
- **WHEN** `by_city`'s source pipeline changes (e.g. a new `where` filter is
  added before the `groupby`) and `by_city` is recomputed
- **THEN** `by_dept`'s previously computed `Fibration` SHALL be unaffected
  and SHALL NOT require recomputation

### Requirement: Selection updates are revision-stamped so consumers can discard superseded results

Every `Selection` SHALL carry a `revision: int`. The system SHALL maintain
one monotonic revision counter per source lineage: every `Selection`-
producing operation (`df.select_rows(...)`, `fibers[key]`,
`df.pull_back(...)`, `df.push_forward(...)`, and `union`/`intersect`/
`difference`) SHALL assign the counter's next value to its result at
creation time. A consumer applying a sequence of `Selection` updates (e.g. a
linked chart re-rendering on each cross-filter event) SHALL discard any
incoming update whose `revision` is not strictly greater than the last
revision it applied, even if that update's computation happened to finish
after a later one's.

This exists because interactive selection is not requested at a rate that
guarantees in-order completion: `pull_back`/`push_forward`/`.stats(...)`
calls triggered in quick succession (e.g. during a drag) may finish out of
order, and a naive "apply whatever arrives" consumer would flicker between
a newer and an older selection state.

#### Scenario: Out-of-order completion does not regress the displayed selection

- **GIVEN** a user drags a brush, triggering selection computations at
  revisions `1`, `2`, and `3` in that order
- **WHEN** the computation for revision `2` finishes after the computation
  for revision `3` has already been applied
- **THEN** the consumer SHALL discard the revision-`2` result and SHALL
  continue displaying the revision-`3` result

#### Scenario: In-order completion applies normally

- **GIVEN** selection computations complete in the same order they were
  requested
- **WHEN** each result arrives
- **THEN** each SHALL be applied, since each carries a strictly greater
  revision than the last applied one

#### Scenario: Derived selections carry a fresh revision

- **GIVEN** `sel_a` carrying revision `7`
- **WHEN** `sel_a.intersect(sel_b)` is computed
- **THEN** the result SHALL carry a revision strictly greater than every
  revision previously issued for the source lineage


## Requirements
