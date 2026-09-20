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

### Requirement: Plan inspection without materialization

`DataFrame.explain()` SHALL return a string representation of the pipeline
plan without triggering materialization. This allows users to inspect what
operations will be performed before paying the collection cost. The output
SHALL reflect the reified `LogicalOp` chain (see "PipelineStep SHALL only be
constructed through validated factories"), the active backend's name, and
the active `NullPolicy`. When any step executed via fallback (see
`backend/spec.md`'s "Capability negotiation and explicit fallback"),
`explain()` SHALL mark that step as `[fallback: python]`.

#### Scenario: Explain shows plan steps

- **WHEN** `(df | po.where(Person.age > 25) | po.select(Person.name)).explain()`
- **THEN** the output SHALL include the plan steps, their `LogicalOp`
  representations, and their schema transforms
- **AND** no data SHALL be processed

#### Scenario: Explain on base DataFrame

- **WHEN** `df.explain()` is called on a DataFrame with no plan steps
- **THEN** the output SHALL indicate an empty plan

#### Scenario: Explain on collected DataFrame

- **WHEN** `df.collect().explain()` is called
- **THEN** the output SHALL indicate an empty plan (data is inline)

#### Scenario: Explain shows schema evolution

- **WHEN** `(df | po.select(Person.name)).explain()` is called
- **THEN** the output SHALL show the schema transform (e.g., `Project(["name"])`)
  and the resulting column set

#### Scenario: Explain shows backend and null policy

- **GIVEN** `df` was constructed with a backend whose `null_policy` is
  `NullPolicy.PROPAGATE`
- **WHEN** `df.explain()` is called
- **THEN** the output SHALL name the active backend and state
  `null_policy=PROPAGATE`

#### Scenario: Explain marks fallback steps

- **GIVEN** a pipeline where one step fell back to the pure-Python backend
  (per `backend/spec.md`'s explicit-fallback requirement)
- **WHEN** `df.explain()` is called
- **THEN** that step's line SHALL be suffixed with `[fallback: python]`
