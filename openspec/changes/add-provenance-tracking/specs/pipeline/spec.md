---
id: pipeline
kind: intent
statement: "WHEN a pipeline step is created THE system SHALL construct it only through validated factories whose step carries a LogicalOp, a pure-Python lowering, and a zero-cost ProvenanceTransform composed by pullback"
---

# PipelineStep provenance metadata

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| pp.factory_only | invariant | PipelineStep has no public constructor accepting arbitrary pairs; steps are created only via validated factories and `\|` | [[pipeline]] |
| pp.dual_representation | invariant | Every step's DataOp carries a sealed backend-neutral LogicalOp plus a pure-Python lowering (StreamingOp or MaterializingOp); streaming steps stream, materializing steps materialize | [[pipeline]] |
| pp.provenance_component | invariant | Each factory attaches a ProvenanceTransform computed at construction time from the same information as SchemaTransform, without touching row data, as an optional third component | [[pipeline]] |
| pp.composition | invariant | `\|` composition preserves materializing dominance, concatenates LogicalOps in pipe order, and pullback-composes ProvenanceTransforms | [[pipeline]] |
| pp.rule_provenance_zero_cost | invariant | Pipelines whose provenance is only Bijection/Injection rules materialize no per-row provenance storage and behave identically to add-core-architecture | [[pipeline]] |

## Model

### States

- `unconstructed`
- `factory_built`
- `composed`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_factory | unconstructed | factory_built | [[pipeline.pp.factory_only]] |
| t_attach | factory_built | factory_built | [[pipeline.pp.provenance_component]] |
| t_compose | factory_built | composed | [[pipeline.pp.composition]] |
| t_zero_cost | composed | composed | [[pipeline.pp.rule_provenance_zero_cost]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.factory_only | unit | [[pipeline.pp.factory_only]] | arbitrary factory calls | steps are only obtainable via factories and `\|` |
| p.dual_representation | unit | [[pipeline.pp.dual_representation]] | steps from every factory | LogicalOp plus correct lowering are attached |
| p.provenance_component | unit | [[pipeline.pp.provenance_component]] | steps from every factory | a correct ProvenanceTransform is attached without touching row data |
| p.composition | unit | [[pipeline.pp.composition]] | pairs of steps composed with `\|` | dominance, LogicalOp concatenation, and pullback composition hold |
| p.rule_provenance_zero_cost | unit | [[pipeline.pp.rule_provenance_zero_cost]] | rule-only pipelines vs core-architecture baselines | outputs are identical and no per-row provenance storage exists |

## Purpose

Carry provenance metadata on pipeline steps at zero cost to pipelines that
never inspect it, reconciling the LogicalOp reification with provenance
tracking.

## MODIFIED Requirements

<!-- Application order: this delta is written against `pipeline/spec.md` as
     modified by `add-backend-adapter-protocol` (which reifies `LogicalOp`
     into the `DataOp`). Apply the backend change BEFORE this one. It
     reconciles the two proposals' shared requirement by combining the
     `LogicalOp`-carrying `DataOp` with this proposal's `ProvenanceTransform`
     third component; neither side's addition is dropped. -->

### Requirement: PipelineStep SHALL only be constructed through validated factories

`PipelineStep` SHALL NOT expose a public constructor that accepts arbitrary
`(data_op, schema_transform)` pairs. Pipeline steps SHALL only be created
through validated factory functions (`where()`, `select()`, `derive()`,
`sort_by()`, `distinct()`, `groupby()`, `comp()`, and cross-layer lifting)
that guarantee data-schema coherence — i.e., the data operation and schema
transform components are always consistent with each other.

The data component of a `PipelineStep` SHALL be a `DataOp`, which SHALL
carry both:
- a `LogicalOp` — a sealed, backend-neutral node describing the operation's
  declarative intent (`Filter`, `Project`, `Extend`, `Sort`, `Distinct`,
  `GroupBy`, `Join`, `Identity`), computable and inspectable without
  touching row data, mirroring how `SchemaTransform` is computed without
  touching row data
- a pure-Python lowering, which SHALL be either:
  - `StreamingOp` — backed by a transducer (processes rows one at a time)
  - `MaterializingOp` — requires all input rows before producing output
    (e.g., `sort_by`, `groupby`)

The pure-Python lowering SHALL remain the sole execution path when no
`backend=` is specified (see `backend/spec.md`); this requirement's change
is additive to the internal representation and does not alter the pure-
Python backend's observable behavior. A non-Python `Backend` executes by
matching on `LogicalOp` and does not use the pure-Python lowering.

Streaming steps (`where`, `select`, `derive`, `distinct`) use `StreamingOp`.
Materializing steps (`sort_by`, `groupby`) use `MaterializingOp`.

Each factory SHALL also attach a `ProvenanceTransform` (see
`provenance/spec.md`) computed from the same construction-time information
used to compute the `SchemaTransform` and the `LogicalOp`, without touching
row data. The `ProvenanceTransform` is metadata carried by the
`PipelineStep` as an optional third component, alongside its `DataOp` and
`SchemaTransform`; it does not change `DataOp` execution and imposes no cost
on pipelines that never inspect it.

When composing steps via `|`, if either step is materializing, the composed
step SHALL be materializing (the collection boundary is preserved). The
composed step's `LogicalOp` sequence SHALL be the concatenation of its
constituents' `LogicalOp`s, in pipe order, and its `ProvenanceTransform`
SHALL be the pullback composition of its constituents'
`ProvenanceTransform`s, per `provenance/spec.md`'s "ProvenanceTransform
composes by pullback under `|`" requirement.

#### Scenario: Factory functions are the only public constructors

- **WHEN** a user needs a pipeline step
- **THEN** they SHALL use `po.where(expr)`, `po.select(*exprs)`,
  `po.derive(**exprs)`, `po.sort_by(*exprs)`, `po.distinct(*exprs)`,
  `po.groupby(...)`, `po.comp(...)`, or the `|` operator on existing steps
- **AND** direct construction of `PipelineStep(transducer, schema_transform)`
  SHALL NOT be part of the public API

#### Scenario: Every factory attaches a LogicalOp

- **WHEN** `po.where(Person.age > 25)` is called
- **THEN** the resulting `PipelineStep`'s data component SHALL carry
  `LogicalOp.Filter(Person.age > 25)` in addition to its `StreamingOp`
  transducer lowering

#### Scenario: Every factory attaches a ProvenanceTransform

- **WHEN** `po.select(Person.name)` is called
- **THEN** the resulting `PipelineStep` SHALL carry a `ProvenanceTransform`
  of `Bijection`, alongside its existing `DataOp` and `SchemaTransform`

#### Scenario: LogicalOp sequence is inspectable without materialization

- **GIVEN** `pipeline = po.where(Person.age > 25) | po.select(Person.name)`
- **WHEN** `pipeline` is inspected before any DataFrame is piped through it
- **THEN** its `LogicalOp` sequence SHALL be
  `[Filter(Person.age > 25), Project(["name"])]`
- **AND** no row data SHALL be processed to produce that sequence

#### Scenario: LogicalOp composition preserves pipe order

- **GIVEN** `step1 = po.where(Person.age > 25)` and
  `step2 = po.select(Person.name)`
- **WHEN** `composed = step1 | step2`
- **THEN** `composed`'s `LogicalOp` sequence SHALL equal
  `step1`'s `LogicalOp` sequence followed by `step2`'s, in that order

#### Scenario: Rule-only provenance is zero-cost

- **GIVEN** a pipeline whose steps are only `where`, `select`, `derive`,
  `sort_by`, or `distinct` (Bijection/Injection provenance), with no
  `groupby` and no `join`
- **WHEN** that pipeline is materialized
- **THEN** observable behavior and output SHALL be identical to a pipeline
  built under `add-core-architecture` with no `ProvenanceTransform` concept
  present
- **AND** no per-row provenance storage SHALL be materialized: those
  variants are transformation rules computed at construction time, not
  row-id maps

## Requirements

<!-- Application order: this delta is written against `pipeline/spec.md` as
     modified by `add-backend-adapter-protocol` (which reifies `LogicalOp`
     into the `DataOp`). Apply the backend change BEFORE this one. It
     reconciles the two proposals' shared requirement by combining the
     `LogicalOp`-carrying `DataOp` with this proposal's `ProvenanceTransform`
     third component; neither side's addition is dropped. -->

### Requirement: PipelineStep SHALL only be constructed through validated factories

`PipelineStep` SHALL NOT expose a public constructor that accepts arbitrary
`(data_op, schema_transform)` pairs. Pipeline steps SHALL only be created
through validated factory functions (`where()`, `select()`, `derive()`,
`sort_by()`, `distinct()`, `groupby()`, `comp()`, and cross-layer lifting)
that guarantee data-schema coherence — i.e., the data operation and schema
transform components are always consistent with each other.

The data component of a `PipelineStep` SHALL be a `DataOp`, which SHALL
carry both:
- a `LogicalOp` — a sealed, backend-neutral node describing the operation's
  declarative intent (`Filter`, `Project`, `Extend`, `Sort`, `Distinct`,
  `GroupBy`, `Join`, `Identity`), computable and inspectable without
  touching row data, mirroring how `SchemaTransform` is computed without
  touching row data
- a pure-Python lowering, which SHALL be either:
  - `StreamingOp` — backed by a transducer (processes rows one at a time)
  - `MaterializingOp` — requires all input rows before producing output
    (e.g., `sort_by`, `groupby`)

The pure-Python lowering SHALL remain the sole execution path when no
`backend=` is specified (see `backend/spec.md`); this requirement's change
is additive to the internal representation and does not alter the pure-
Python backend's observable behavior. A non-Python `Backend` executes by
matching on `LogicalOp` and does not use the pure-Python lowering.

Streaming steps (`where`, `select`, `derive`, `distinct`) use `StreamingOp`.
Materializing steps (`sort_by`, `groupby`) use `MaterializingOp`.

Each factory SHALL also attach a `ProvenanceTransform` (see
`provenance/spec.md`) computed from the same construction-time information
used to compute the `SchemaTransform` and the `LogicalOp`, without touching
row data. The `ProvenanceTransform` is metadata carried by the
`PipelineStep` as an optional third component, alongside its `DataOp` and
`SchemaTransform`; it does not change `DataOp` execution and imposes no cost
on pipelines that never inspect it.

When composing steps via `|`, if either step is materializing, the composed
step SHALL be materializing (the collection boundary is preserved). The
composed step's `LogicalOp` sequence SHALL be the concatenation of its
constituents' `LogicalOp`s, in pipe order, and its `ProvenanceTransform`
SHALL be the pullback composition of its constituents'
`ProvenanceTransform`s, per `provenance/spec.md`'s "ProvenanceTransform
composes by pullback under `|`" requirement.

#### Scenario: Factory functions are the only public constructors

- **WHEN** a user needs a pipeline step
- **THEN** they SHALL use `po.where(expr)`, `po.select(*exprs)`,
  `po.derive(**exprs)`, `po.sort_by(*exprs)`, `po.distinct(*exprs)`,
  `po.groupby(...)`, `po.comp(...)`, or the `|` operator on existing steps
- **AND** direct construction of `PipelineStep(transducer, schema_transform)`
  SHALL NOT be part of the public API

#### Scenario: Every factory attaches a LogicalOp

- **WHEN** `po.where(Person.age > 25)` is called
- **THEN** the resulting `PipelineStep`'s data component SHALL carry
  `LogicalOp.Filter(Person.age > 25)` in addition to its `StreamingOp`
  transducer lowering

#### Scenario: Every factory attaches a ProvenanceTransform

- **WHEN** `po.select(Person.name)` is called
- **THEN** the resulting `PipelineStep` SHALL carry a `ProvenanceTransform`
  of `Bijection`, alongside its existing `DataOp` and `SchemaTransform`

#### Scenario: LogicalOp sequence is inspectable without materialization

- **GIVEN** `pipeline = po.where(Person.age > 25) | po.select(Person.name)`
- **WHEN** `pipeline` is inspected before any DataFrame is piped through it
- **THEN** its `LogicalOp` sequence SHALL be
  `[Filter(Person.age > 25), Project(["name"])]`
- **AND** no row data SHALL be processed to produce that sequence

#### Scenario: LogicalOp composition preserves pipe order

- **GIVEN** `step1 = po.where(Person.age > 25)` and
  `step2 = po.select(Person.name)`
- **WHEN** `composed = step1 | step2`
- **THEN** `composed`'s `LogicalOp` sequence SHALL equal
  `step1`'s `LogicalOp` sequence followed by `step2`'s, in that order

#### Scenario: Rule-only provenance is zero-cost

- **GIVEN** a pipeline whose steps are only `where`, `select`, `derive`,
  `sort_by`, or `distinct` (Bijection/Injection provenance), with no
  `groupby` and no `join`
- **WHEN** that pipeline is materialized
- **THEN** observable behavior and output SHALL be identical to a pipeline
  built under `add-core-architecture` with no `ProvenanceTransform` concept
  present
- **AND** no per-row provenance storage SHALL be materialized: those
  variants are transformation rules computed at construction time, not
  row-id maps

## Requirements
