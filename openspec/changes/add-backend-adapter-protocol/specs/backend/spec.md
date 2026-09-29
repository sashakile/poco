---
id: spec
kind: intent
statement: "THE system SHALL expose a Backend protocol with plan/supports/null_policy, backend-scoped NullPolicy, explicit capability negotiation with recorded fallback, and schema-strict pandas/polars import"
---

# Backend protocol

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| backend.protocol_surface | invariant | A Backend exposes `plan(logical_ops)`, `supports(op)`, and `null_policy`; plan yields materialized rows for a LogicalOp chain | [[spec]] |
| backend.default_python | invariant | Constructing a DataFrame with no `backend=` argument binds the pure-Python backend with `null_policy = NullPolicy.RAISE` | [[spec]] |
| backend.null_policy_scoped | invariant | NullPolicy is a property of the Backend as a whole; a pipeline's null-handling behavior is fully determined by the executing backend | [[spec]] |
| backend.raise_policy | invariant | Under NullPolicy.RAISE, a None reaching comparison or arithmetic raises `NullValueError`, matching expression/spec.md's unconditional behavior | [[spec]] |
| backend.propagate_policy | invariant | Under NullPolicy.PROPAGATE, nulls propagate without raising and `df.explain()` indicates the active NullPolicy | [[spec]] |
| backend.no_silent_fallback | invariant | Unsupported ops either raise `UnsupportedOperationError` (on_unsupported="raise") or execute via pure-Python with the fallback recorded in `explain()` (on_unsupported="fallback"); silent fallback never occurs | [[spec]] |
| backend.import_rejects_unsupported_dtype | invariant | `from_pandas`/`from_polars` raise `SchemaError` naming the first column with a dtype outside `int \| float \| str \| bool` (or Optional thereof) rather than coercing | [[spec]] |
| backend.import_rejects_invalid_names | invariant | Column names that are not valid Python identifiers or collide with keywords raise `SchemaError` unless an explicit `column_map` renames them | [[spec]] |

## Model

### States

- `constructed`
- `planning`
- `executing_native`
- `executing_fallback`
- `rejected`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_plan | constructed | planning | [[spec.backend.protocol_surface]] |
| t_dispatch_native | planning | executing_native | [[spec.backend.no_silent_fallback]] |
| t_dispatch_fallback | planning | executing_fallback | [[spec.backend.no_silent_fallback]] |
| t_reject_import | constructed | rejected | [[spec.backend.import_rejects_unsupported_dtype]] |
| t_reject_names | constructed | rejected | [[spec.backend.import_rejects_invalid_names]] |
| t_raise_null | executing_native | rejected | [[spec.backend.raise_policy]] |
| t_propagate_null | executing_native | executing_native | [[spec.backend.propagate_policy]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.protocol_surface | unit | [[spec.backend.protocol_surface]] | arbitrary LogicalOp chains | a conforming Backend's plan executes the chain and yields rows; supports and null_policy are inspectable |
| p.default_python | unit | [[spec.backend.default_python]] | DataFrame constructor calls without backend= | the bound backend is the pure-Python backend with NullPolicy.RAISE |
| p.null_policy_scoped | unit | [[spec.backend.null_policy_scoped]] | arbitrary backends and pipelines | null-handling behavior depends only on the executing backend's null_policy |
| p.raise_policy | unit | [[spec.backend.raise_policy]] | rows with None reaching comparisons/arithmetic under RAISE | `NullValueError` is raised |
| p.propagate_policy | unit | [[spec.backend.propagate_policy]] | rows with None under PROPAGATE | no raise; explain() reports the active NullPolicy |
| p.no_silent_fallback | unit | [[spec.backend.no_silent_fallback]] | pipelines with unsupported ops under both on_unsupported settings | either the named error is raised or the fallback appears in explain(); never silent |
| p.import_rejects_unsupported_dtype | unit | [[spec.backend.import_rejects_unsupported_dtype]] | pandas/polars frames with unsupported dtypes | `SchemaError` names the offending column and dtype |
| p.import_rejects_invalid_names | unit | [[spec.backend.import_rejects_invalid_names]] | frames with non-identifier/keyword column names, with and without column_map | `SchemaError` without a map; successful rename with one |

## Purpose

Enable alternative execution engines (columnar backends) for poco pipelines
while keeping the pure-Python behavior as the default and making any
departure from it explicit and inspectable.

## ADDED Requirements

### Requirement: Backend protocol

The system SHALL define a `Backend` protocol that executes a `LogicalOp`
chain (reified per `pipeline/spec.md`'s "PipelineStep SHALL only be
constructed through validated factories" requirement) and produces
materialized rows conforming to the row-model contract. A `Backend` SHALL expose:
- `plan(logical_ops: list[LogicalOp]) -> Iterator[dict[str, object]]` —
  execute the chain and yield rows
- `supports(op: LogicalOp) -> bool` — capability negotiation (see
  "Capability negotiation and explicit fallback")
- `null_policy: NullPolicy` — the strictness policy this backend executes
  under (see "NullPolicy is a backend-level setting")

The pure-Python backend SHALL be the default `Backend` for `DataFrame`
construction when no `backend=` argument is supplied, and SHALL execute
`LogicalOp` chains by lowering each node to its transducer, preserving all
behavior specified in `pipeline/spec.md` and `transducer/spec.md` exactly as
written.

#### Scenario: Default construction uses the pure-Python backend

- **WHEN** `po.DataFrame({"name": ["Ana"], "age": [30]})` is constructed
  with no `backend=` argument
- **THEN** `df.backend` SHALL be the pure-Python backend
- **AND** `df.backend.null_policy` SHALL be `NullPolicy.RAISE`

#### Scenario: Explicit backend is inspectable

- **GIVEN** a hypothetical `SomeBackend` instance conforming to `Backend`
- **WHEN** `po.DataFrame({"name": ["Ana"]}, backend=SomeBackend())` is
  constructed
- **THEN** `df.backend` SHALL be that `SomeBackend` instance

### Requirement: NullPolicy is a backend-level setting

The system SHALL define `NullPolicy` with two members:
- `RAISE` — any `None` reaching a comparison or arithmetic operation raises
  `NullValueError`, matching `expression/spec.md`'s current unconditional
  behavior. This is the pure-Python backend's default and preserves
  `add-core-architecture`'s behavior exactly.
- `PROPAGATE` — nulls propagate through comparisons and arithmetic without
  raising, matching the behavior of mainstream columnar engines (pandas,
  polars).

`NullPolicy` SHALL be a property of the `Backend` as a whole, not of
individual expressions or pipeline steps. A pipeline's null-handling
behavior SHALL be fully determined by which backend executes it.

Consequently, the null-strictness behavior stated unconditionally elsewhere
(e.g. `expression/spec.md`'s "Expression errors" requirement raising
`NullValueError`, and the strict comparison semantics in
`relational/spec.md`) SHALL be read as scoped to the `RAISE` policy: those
requirements hold in full whenever the executing backend's `null_policy` is
`RAISE` — which is the default, preserving `add-core-architecture`'s
behavior exactly — and, under `PROPAGATE`, they are superseded by the
executing backend's native null semantics for the operations they govern.
No requirement outside null strictness is affected by this scoping, and no
backend may relax any other documented error (e.g. `SchemaError` or
`IntegrityError`) via its `null_policy`.

#### Scenario: RAISE policy matches existing spec behavior

- **GIVEN** a `Backend` with `null_policy = NullPolicy.RAISE`
- **WHEN** a row with `age = None` reaches `Person.age > 30`
- **THEN** `NullValueError` SHALL be raised, exactly as specified in
  `expression/spec.md`

#### Scenario: PROPAGATE policy allows native execution

- **GIVEN** a `Backend` with `null_policy = NullPolicy.PROPAGATE`
- **WHEN** a row with `age = None` reaches `Person.age > 30`
- **THEN** the comparison SHALL evaluate to a null/false-like result without
  raising, matching that backend's native null semantics
- **AND** `df.explain()` SHALL indicate the active `NullPolicy` so the
  difference from the pure-Python default is never silent

### Requirement: Capability negotiation and explicit fallback

A `Backend` SHALL declare, via `supports(op)`, whether it can execute a
given `LogicalOp` natively. When a pipeline contains an operation a backend
does not support:
- If the `DataFrame` was constructed with `on_unsupported="raise"` (the
  default), materialization SHALL raise `UnsupportedOperationError` naming
  the unsupported operation.
- If constructed with `on_unsupported="fallback"`, that portion of the
  pipeline SHALL execute via the pure-Python backend, and `df.explain()`
  SHALL mark which steps fell back.

`LogicalOp` covers data manipulation only. Fiber-retention and selection
metadata carried by pipeline steps (per `add-provenance-tracking`) are
pure-Python lowering concerns: no `Backend` is required to inspect,
implement, or accelerate them in this change, and their presence in a step
SHALL NOT affect `supports(op)` for that step's `LogicalOp`.

Silent fallback (executing via a different backend than the one specified,
without either raising or recording it in `explain()`) SHALL NOT occur under
any configuration.

#### Scenario: Unsupported operation raises by default

- **GIVEN** a `Backend` whose `supports(op)` returns `False` for a
  `Distinct(ttl=...)` operation
- **WHEN** a pipeline containing `po.distinct(ttl=60)` is materialized
  against that backend with default `on_unsupported="raise"`
- **THEN** `UnsupportedOperationError` SHALL be raised, naming the
  unsupported `LogicalOp`

#### Scenario: Explicit fallback is recorded, not silent

- **GIVEN** the same backend and pipeline, constructed with
  `on_unsupported="fallback"`
- **WHEN** the pipeline is materialized
- **THEN** the `Distinct(ttl=60)` step SHALL execute via the pure-Python
  backend
- **AND** `df.explain()` SHALL show that step as `[fallback: python]`

### Requirement: Import boundary rejects unsupported dtypes and column names

`from_pandas(df)` and `from_polars(df)` SHALL raise `SchemaError` naming the
first column whose dtype is outside poco's supported set (`int | float |
str | bool`, or `Optional` thereof, per `schema/spec.md`'s "Supported column
types") rather than silently dropping, coercing, or stringifying it.

Column names that are not valid Python identifiers, or that collide with
Python keywords, SHALL raise `SchemaError` unless an explicit
`column_map: dict[str, str]` renaming those columns is supplied.

#### Scenario: Unsupported dtype is rejected, not coerced

- **GIVEN** a pandas DataFrame with a `datetime64[ns]` column named
  `"created_at"`
- **WHEN** `po.from_pandas(pdf)` is called with no further arguments
- **THEN** `SchemaError` SHALL be raised naming `"created_at"` and its
  unsupported dtype

#### Scenario: Non-identifier column name requires explicit mapping

- **GIVEN** a pandas DataFrame with a column named `"first name"`
- **WHEN** `po.from_pandas(pdf)` is called with no `column_map`
- **THEN** `SchemaError` SHALL be raised naming `"first name"` as an invalid
  column identifier
- **WHEN** `po.from_pandas(pdf, column_map={"first name": "first_name"})`
  is called instead
- **THEN** the import SHALL succeed with the column named `"first_name"`

## Requirements

### Requirement: Backend protocol

The system SHALL define a `Backend` protocol that executes a `LogicalOp`
chain (reified per `pipeline/spec.md`'s "PipelineStep SHALL only be
constructed through validated factories" requirement) and produces
materialized rows conforming to the row-model contract. A `Backend` SHALL expose:
- `plan(logical_ops: list[LogicalOp]) -> Iterator[dict[str, object]]` —
  execute the chain and yield rows
- `supports(op: LogicalOp) -> bool` — capability negotiation (see
  "Capability negotiation and explicit fallback")
- `null_policy: NullPolicy` — the strictness policy this backend executes
  under (see "NullPolicy is a backend-level setting")

The pure-Python backend SHALL be the default `Backend` for `DataFrame`
construction when no `backend=` argument is supplied, and SHALL execute
`LogicalOp` chains by lowering each node to its transducer, preserving all
behavior specified in `pipeline/spec.md` and `transducer/spec.md` exactly as
written.

#### Scenario: Default construction uses the pure-Python backend

- **WHEN** `po.DataFrame({"name": ["Ana"], "age": [30]})` is constructed
  with no `backend=` argument
- **THEN** `df.backend` SHALL be the pure-Python backend
- **AND** `df.backend.null_policy` SHALL be `NullPolicy.RAISE`

#### Scenario: Explicit backend is inspectable

- **GIVEN** a hypothetical `SomeBackend` instance conforming to `Backend`
- **WHEN** `po.DataFrame({"name": ["Ana"]}, backend=SomeBackend())` is
  constructed
- **THEN** `df.backend` SHALL be that `SomeBackend` instance

### Requirement: NullPolicy is a backend-level setting

The system SHALL define `NullPolicy` with two members:
- `RAISE` — any `None` reaching a comparison or arithmetic operation raises
  `NullValueError`, matching `expression/spec.md`'s current unconditional
  behavior. This is the pure-Python backend's default and preserves
  `add-core-architecture`'s behavior exactly.
- `PROPAGATE` — nulls propagate through comparisons and arithmetic without
  raising, matching the behavior of mainstream columnar engines (pandas,
  polars).

`NullPolicy` SHALL be a property of the `Backend` as a whole, not of
individual expressions or pipeline steps. A pipeline's null-handling
behavior SHALL be fully determined by which backend executes it.

Consequently, the null-strictness behavior stated unconditionally elsewhere
(e.g. `expression/spec.md`'s "Expression errors" requirement raising
`NullValueError`, and the strict comparison semantics in
`relational/spec.md`) SHALL be read as scoped to the `RAISE` policy: those
requirements hold in full whenever the executing backend's `null_policy` is
`RAISE` — which is the default, preserving `add-core-architecture`'s
behavior exactly — and, under `PROPAGATE`, they are superseded by the
executing backend's native null semantics for the operations they govern.
No requirement outside null strictness is affected by this scoping, and no
backend may relax any other documented error (e.g. `SchemaError` or
`IntegrityError`) via its `null_policy`.

#### Scenario: RAISE policy matches existing spec behavior

- **GIVEN** a `Backend` with `null_policy = NullPolicy.RAISE`
- **WHEN** a row with `age = None` reaches `Person.age > 30`
- **THEN** `NullValueError` SHALL be raised, exactly as specified in
  `expression/spec.md`

#### Scenario: PROPAGATE policy allows native execution

- **GIVEN** a `Backend` with `null_policy = NullPolicy.PROPAGATE`
- **WHEN** a row with `age = None` reaches `Person.age > 30`
- **THEN** the comparison SHALL evaluate to a null/false-like result without
  raising, matching that backend's native null semantics
- **AND** `df.explain()` SHALL indicate the active `NullPolicy` so the
  difference from the pure-Python default is never silent

### Requirement: Capability negotiation and explicit fallback

A `Backend` SHALL declare, via `supports(op)`, whether it can execute a
given `LogicalOp` natively. When a pipeline contains an operation a backend
does not support:
- If the `DataFrame` was constructed with `on_unsupported="raise"` (the
  default), materialization SHALL raise `UnsupportedOperationError` naming
  the unsupported operation.
- If constructed with `on_unsupported="fallback"`, that portion of the
  pipeline SHALL execute via the pure-Python backend, and `df.explain()`
  SHALL mark which steps fell back.

`LogicalOp` covers data manipulation only. Fiber-retention and selection
metadata carried by pipeline steps (per `add-provenance-tracking`) are
pure-Python lowering concerns: no `Backend` is required to inspect,
implement, or accelerate them in this change, and their presence in a step
SHALL NOT affect `supports(op)` for that step's `LogicalOp`.

Silent fallback (executing via a different backend than the one specified,
without either raising or recording it in `explain()`) SHALL NOT occur under
any configuration.

#### Scenario: Unsupported operation raises by default

- **GIVEN** a `Backend` whose `supports(op)` returns `False` for a
  `Distinct(ttl=...)` operation
- **WHEN** a pipeline containing `po.distinct(ttl=60)` is materialized
  against that backend with default `on_unsupported="raise"`
- **THEN** `UnsupportedOperationError` SHALL be raised, naming the
  unsupported `LogicalOp`

#### Scenario: Explicit fallback is recorded, not silent

- **GIVEN** the same backend and pipeline, constructed with
  `on_unsupported="fallback"`
- **WHEN** the pipeline is materialized
- **THEN** the `Distinct(ttl=60)` step SHALL execute via the pure-Python
  backend
- **AND** `df.explain()` SHALL show that step as `[fallback: python]`

### Requirement: Import boundary rejects unsupported dtypes and column names

`from_pandas(df)` and `from_polars(df)` SHALL raise `SchemaError` naming the
first column whose dtype is outside poco's supported set (`int | float |
str | bool`, or `Optional` thereof, per `schema/spec.md`'s "Supported column
types") rather than silently dropping, coercing, or stringifying it.

Column names that are not valid Python identifiers, or that collide with
Python keywords, SHALL raise `SchemaError` unless an explicit
`column_map: dict[str, str]` renaming those columns is supplied.

#### Scenario: Unsupported dtype is rejected, not coerced

- **GIVEN** a pandas DataFrame with a `datetime64[ns]` column named
  `"created_at"`
- **WHEN** `po.from_pandas(pdf)` is called with no further arguments
- **THEN** `SchemaError` SHALL be raised naming `"created_at"` and its
  unsupported dtype

#### Scenario: Non-identifier column name requires explicit mapping

- **GIVEN** a pandas DataFrame with a column named `"first name"`
- **WHEN** `po.from_pandas(pdf)` is called with no `column_map`
- **THEN** `SchemaError` SHALL be raised naming `"first name"` as an invalid
  column identifier
- **WHEN** `po.from_pandas(pdf, column_map={"first name": "first_name"})`
  is called instead
- **THEN** the import SHALL succeed with the column named `"first_name"`

## Requirements
