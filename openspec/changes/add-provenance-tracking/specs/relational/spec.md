---
id: relational
kind: intent
statement: "WHEN po.groupby is applied THE system SHALL return Fibers for bare grouping and a materializing step collapsing to a DataFrame with unconditionally retained fibration otherwise"
---

# Groupby as relational pipeline step

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| rel.groupby_keys | invariant | `po.groupby` accepts direct ColumnRef keys plus named aggregation factories; computed key expressions require a prior `po.derive`; None keys group together and key columns are validated at pipe time with `SchemaError` | [[relational]] |
| rel.bare_groupby_fibers | invariant | groupby with no aggregation kwargs returns a `Fibers` value (terminal for `\|`, not a DataFrame) whose per-key selections retain every source row | [[relational]] |
| rel.aggregating_groupby | invariant | groupby with aggregations returns a materializing PipelineStep preserving `DataFrame \| step -> DataFrame`, carrying a Fibration ProvenanceTransform exposed as `.fibers` on the materialized result | [[relational]] |
| rel.unconditional_retention | invariant | Fibration retention is unconditional — there is no per-call `keep_fibers` flag; any future memory knob is a global or per-backend setting | [[relational]] |
| rel.aggregate_equivalence | invariant | `Fibers.aggregate(**named_reducers)` produces the same collapsed DataFrame as the aggregating groupby form, without re-executing any pre-groupby step | [[relational]] |
| rel.name_collision | invariant | Key-aggregation name collisions raise `SchemaError` | [[relational]] |

## Model

### States

- `ungrouped`
- `fibers_value`
- `collapsed`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_validate | ungrouped | ungrouped | [[relational.rel.groupby_keys]] |
| t_bare | ungrouped | fibers_value | [[relational.rel.bare_groupby_fibers]] |
| t_aggregate_form | ungrouped | collapsed | [[relational.rel.aggregating_groupby]] |
| t_aggregate_method | fibers_value | collapsed | [[relational.rel.aggregate_equivalence]] |
| t_reject_collision | ungrouped | ungrouped | [[relational.rel.name_collision]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.groupby_keys | unit | [[relational.rel.groupby_keys]] | key expressions and frames with/without the key columns | validation errors at pipe time; None keys group together |
| p.bare_groupby_fibers | unit | [[relational.rel.bare_groupby_fibers]] | bare groupby materializations | result is Fibers; per-key selections cover exactly the sharing source rows |
| p.aggregating_groupby | unit | [[relational.rel.aggregating_groupby]] | groupby calls with aggregations | result preserves the endomorphism and exposes `.fibers` |
| p.unconditional_retention | unit | [[relational.rel.unconditional_retention]] | all groupby forms | no keep_fibers flag exists; retention always holds |
| p.aggregate_equivalence | unit | [[relational.rel.aggregate_equivalence]] | paired aggregating-groupby and Fibers.aggregate computations | results are equivalent; no pre-groupby step re-execution |
| p.name_collision | unit | [[relational.rel.name_collision]] | groupby calls with colliding names | `SchemaError` is raised |

## Purpose

Make grouping retain its fibration unconditionally so aggregation results
remain traceable to source rows and bare grouping yields a first-class
queryable value.

## MODIFIED Requirements

### Requirement: Groupby as relational pipeline step

`po.groupby(*key_exprs, **aggregations)` SHALL accept one or more `ColumnRef`
objects as direct group keys and optional named aggregation reducers
(column-bound reducer factories per `aggregation/spec.md`). Computed key
expressions SHALL require a prior `po.derive(...)` step so that
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

## Requirements

### Requirement: Groupby as relational pipeline step

`po.groupby(*key_exprs, **aggregations)` SHALL accept one or more `ColumnRef`
objects as direct group keys and optional named aggregation reducers
(column-bound reducer factories per `aggregation/spec.md`). Computed key
expressions SHALL require a prior `po.derive(...)` step so that
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

## Requirements
