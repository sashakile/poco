## ADDED Requirements

### Requirement: Materialized row contract

The system SHALL use a single shared contract for materialized rows across
expression evaluation, reducers, transducers, and DataFrame iteration.

A materialized row SHALL be a Python `dict[str, object]` mapping column names
to values. Keys SHALL be insertion-ordered and correspond to the current schema
field order. `object` describes the runtime container type only; valid column
value types remain constrained by `schema/spec.md`.

*Note: This hard requirement for `dict[str, object]` prioritizes API ergonomics and simplicity over raw performance. It creates a performance ceiling for large datasets but is the correct trade-off for the current exploratory and teaching scope. Future iterations may abstract this behind a Row protocol if scaling is required.*

#### Scenario: Row values are keyed by column name

- **WHEN** a materialized row is produced from a DataFrame with columns
  `name` and `age`
- **THEN** the row SHALL be a dict equivalent to `{"name": "Ana", "age": 30}`

#### Scenario: Row key order follows schema order

- **WHEN** a DataFrame schema orders columns as `name`, `age`, `city`
- **THEN** every materialized row SHALL expose keys in that same order

### Requirement: Row copies are isolated from DataFrame storage

Rows yielded to user code SHALL be independent dict copies. Mutating a yielded
row SHALL NOT affect DataFrame storage, pipeline execution, or subsequent rows.

#### Scenario: Mutating a yielded row does not mutate the DataFrame

- **WHEN** a user iterates a DataFrame row and mutates the returned dict
- **THEN** the mutation SHALL NOT affect the DataFrame's stored or future
  materialized values

### Requirement: Row contract is the evaluation input for expressions and reducers

All expression evaluation and row-oriented reducer/transducer processing SHALL
accept the materialized row contract defined in this capability.

#### Scenario: Expression evaluation consumes shared row contract

- **WHEN** an `Expr` is evaluated against `{"age": 30}`
- **THEN** the evaluation input SHALL be interpreted using the shared row contract

#### Scenario: Row reducers consume shared row contract

- **WHEN** `po.reduce(reducer, df)` iterates a DataFrame
- **THEN** the reducer SHALL receive materialized rows matching the shared row contract
