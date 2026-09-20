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
