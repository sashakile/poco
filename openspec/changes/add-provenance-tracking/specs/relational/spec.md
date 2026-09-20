## MODIFIED Requirements

### Requirement: Groupby as relational pipeline step

`po.groupby(*key_exprs, **aggregations)` SHALL accept one or more `ColumnRef`
objects as direct group keys and optional named aggregation reducers.
Computed key expressions SHALL require a prior `po.derive(...)` step so that
the grouped key has a stable output column name.

Grouping and collapsing are two different operations, and grouping SHALL
always produce a `Fibration` — poco never discards the fibration to keep
only the collapse:

- `po.groupby(*keys)` — with no aggregation kwargs — SHALL return a `Fibers`
  value (see `provenance/spec.md`'s "Fibers is the first-class fibration
  object" requirement): the retained fibration presented as a first-class
  object. `Fibers` is terminal for `|` and is not a `DataFrame`.
- `po.groupby(*keys, **aggregations)` SHALL return a `PipelineStep`
  (materializing) whose materialized result is a lazy `DataFrame`,
  preserving the endomorphism `DataFrame | step -> DataFrame`. The step's
  `ProvenanceTransform` SHALL be `Fibration` (see `provenance/spec.md`),
  and the materialized result SHALL expose it as `.fibers`, so every
  aggregate row remains traceable to the source rows that produced it.

There is no `keep_fibers` flag: retention is unconditional because the
fibration *is* the provenance. A future memory knob, if ever needed, SHALL
be a global or per-backend setting, never a per-call flag.

`.aggregate(**named_reducers)` on a `Fibers` value SHALL produce the same
collapsed `DataFrame` (with `.fibers` exposed) as piping the same
aggregations into `po.groupby`, without re-executing any step of the source
pipeline prior to the groupby.

Key-aggregation name collisions SHALL raise a `SchemaError` (e.g.,
`po.groupby(Person.dept, dept=po.count_of())`).

#### Scenario: Groupby single column with aggregation

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** the result SHALL be a lazy `DataFrame` with columns `dept` and `total`

#### Scenario: Groupby with multiple keys

- **WHEN** `df | po.groupby(Person.dept, Person.city, count=po.count_of())`
- **THEN** the result SHALL be partitioned by unique combinations of `dept` and `city`
- **AND** `(None, 1)` and `(None, 2)` SHALL be treated as distinct groups

#### Scenario: None group keys are treated as equal

- **WHEN** rows with `dept` as `None` are grouped by `Person.dept`
- **THEN** all `None`-keyed rows SHALL belong to the same group

#### Scenario: Groupby preserves DataFrame endomorphism

- **WHEN** `result = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** `result` SHALL be a `DataFrame`

#### Scenario: Bare groupby returns Fibers, not a DataFrame

- **WHEN** `fibers = df | po.groupby(Person.dept)`
- **THEN** the result SHALL be a `Fibers` value, not a `DataFrame`
- **AND** piping it onward (`fibers | po.where(Person.age > 25)`) SHALL
  raise `TypeError`

#### Scenario: Bare groupby retains every source row per key

- **WHEN** `fibers = df | po.groupby(Person.dept)` is materialized
- **THEN** for each distinct `dept` value, `fibers[dept_value]` SHALL be a
  `Selection` of exactly the source rows sharing that value

#### Scenario: Fibers.aggregate matches the aggregating form without re-execution

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))` and
  `(df | po.groupby(Person.dept)).aggregate(total=po.sum_of(Person.salary))`
  are compared
- **THEN** the two results SHALL be equivalent `DataFrame`s (same data and
  schema, each with `.fibers` exposed)
- **AND** the `Fibers`-based path SHALL NOT re-execute any step of `df`'s
  pipeline prior to the groupby

#### Scenario: Key-aggregation name collision raises error

- **WHEN** `po.groupby(Person.dept, dept=po.count_of())` is called
- **THEN** the system SHALL raise a `SchemaError` indicating the name collision

#### Scenario: Groupby validates columns at pipe time

- **WHEN** `df | po.groupby(Person.salary, n=po.count_of())` where `df` has
  no `salary` column
- **THEN** the system SHALL raise a `SchemaError` at pipe time

#### Scenario: Collapsed result exposes its fibration

- **WHEN** `grouped = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
  is materialized
- **THEN** `grouped.fibers` SHALL be the `Fibration` retaining, per distinct
  `dept` value, the full set of source rows sharing that value
- **AND** `grouped.fibers["engineering"]` SHALL be the `Selection` of every
  source row whose `dept` was `"engineering"`
