---
id: spec
kind: intent
statement: "WHEN a pipeline step is created THE system SHALL construct it only through validated factories whose data component carries both a backend-neutral LogicalOp and a pure-Python lowering"
---

# PipelineStep LogicalOp reification

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| pipe.factory_only | invariant | PipelineStep has no public constructor accepting arbitrary pairs; steps are created only via validated factories and `\|` | [[spec]] |
| pipe.dual_representation | invariant | Every step's data component is a DataOp carrying a sealed backend-neutral LogicalOp plus a pure-Python lowering (StreamingOp or MaterializingOp) | [[spec]] |
| pipe.lowering_taxonomy | invariant | Streaming steps (where, select, derive, distinct) use StreamingOp; materializing steps (sort_by, groupby) use MaterializingOp | [[spec]] |
| pipe.composition | invariant | Composing steps via `\|` yields a materializing step if either side is materializing, with LogicalOp sequence equal to the concatenation in pipe order | [[spec]] |
| pipe.logical_op_pure | invariant | LogicalOp sequences are inspectable without processing row data; the pure-Python lowering remains the sole execution path when no backend is specified | [[spec]] |

## Model

### States

- `unconstructed`
- `factory_built`
- `composed`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_factory | unconstructed | factory_built | [[spec.pipe.factory_only]] |
| t_attach_op | factory_built | factory_built | [[spec.pipe.dual_representation]] |
| t_compose | factory_built | composed | [[spec.pipe.composition]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.factory_only | unit | [[spec.pipe.factory_only]] | arbitrary factory calls | steps are only obtainable via factories and `\|` |
| p.dual_representation | unit | [[spec.pipe.dual_representation]] | steps from every factory | the DataOp carries both a LogicalOp and a lowering |
| p.lowering_taxonomy | unit | [[spec.pipe.lowering_taxonomy]] | each factory name | streaming vs materializing lowering assignment matches the spec |
| p.composition | unit | [[spec.pipe.composition]] | pairs of steps composed with `\|` | materializing dominance and LogicalOp concatenation in pipe order hold |
| p.logical_op_pure | unit | [[spec.pipe.logical_op_pure]] | pipelines inspected before materialization | LogicalOp sequences are computable without touching row data |

## Purpose

Reify each pipeline step's declarative intent as a LogicalOp so non-Python
backends can execute pipelines, without changing pure-Python behavior.

## MODIFIED Requirements

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

When composing steps via `|`, if either step is materializing, the composed
step SHALL be materializing (the collection boundary is preserved). The
composed step's `LogicalOp` sequence SHALL be the concatenation of its
constituents' `LogicalOp`s, in pipe order.

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

## Requirements

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

When composing steps via `|`, if either step is materializing, the composed
step SHALL be materializing (the collection boundary is preserved). The
composed step's `LogicalOp` sequence SHALL be the concatenation of its
constituents' `LogicalOp`s, in pipe order.

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

## Requirements
