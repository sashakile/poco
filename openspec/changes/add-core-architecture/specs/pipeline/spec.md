## ADDED Requirements

### Requirement: Pipe operator applies transducer to DataFrame

`DataFrame | transducer` SHALL return a `LazyFrame` that records the
transducer as part of its execution plan. The data SHALL NOT be processed
until `collect()` is called.

#### Scenario: Pipe creates LazyFrame

- **WHEN** `df | po.where(Person.age > 25)`
- **THEN** the result SHALL be a `LazyFrame` with the filter in its plan
- **AND** no rows SHALL have been processed yet

### Requirement: LazyFrame stacks transducers

`LazyFrame | transducer` SHALL return a new `LazyFrame` with the transducer
appended to the plan. The original LazyFrame SHALL NOT be modified.

#### Scenario: Chain multiple operations

- **WHEN** `df | po.where(Person.age > 25) | po.select(Person.name)`
- **THEN** the result SHALL be a `LazyFrame` with both filter and project in its plan

#### Scenario: Original LazyFrame is immutable

- **WHEN** `lazy1 = df | po.where(Person.age > 25)` then `lazy2 = lazy1 | po.select(Person.name)`
- **THEN** `lazy1` SHALL still contain only the filter (not the select)
- **AND** `lazy2` SHALL contain both filter and select

### Requirement: LazyFrame collect materializes

`LazyFrame.collect()` SHALL execute the recorded plan and return an eager
`DataFrame` with the results. Calling `collect()` SHALL NOT modify the
LazyFrame — the plan MAY be re-executed on subsequent calls.

#### Scenario: Collect executes the plan

- **WHEN** `(df | po.where(Person.age > 25)).collect()`
- **THEN** the result SHALL be an eager `DataFrame` containing only rows where age > 25

#### Scenario: Collect is repeatable

- **WHEN** `lazy = df | po.where(Person.age > 25)` then `r1 = lazy.collect()` and `r2 = lazy.collect()`
- **THEN** `r1` and `r2` SHALL be equal DataFrames
- **AND** the plan SHALL be re-executed on each call

### Requirement: LazyFrame display shows plan

`LazyFrame.__repr__` SHALL display the execution plan and the schema, but
SHALL NOT display data or trigger collection.

#### Scenario: Display lazy plan

- **WHEN** `repr(lazy_df)` is called
- **THEN** the output SHALL include the schema and plan steps (e.g., `where(age > 25)`)
- **AND** no data SHALL be materialized

### Requirement: Transducer-to-transducer pipe composes

`transducer | transducer` SHALL return a new composed transducer. The composed
transducer SHALL be reusable across different DataFrames.

#### Scenario: Compose and reuse pipeline

- **WHEN** `pipeline = po.where(Person.age > 25) | po.select(Person.name)`
- **THEN** `pipeline(df1)` and `pipeline(df2)` SHALL both produce the expected
  filtered and projected result

### Requirement: Transducer callable convenience

`transducer(df)` SHALL be equivalent to `(df | transducer).collect()`.
This provides a convenience for one-shot application.

#### Scenario: Call transducer on DataFrame

- **WHEN** `po.where(Person.age > 25)(df)`
- **THEN** the result SHALL be the same as `(df | po.where(Person.age > 25)).collect()`

### Requirement: head as take transducer (non-mutating)

`LazyFrame.head(n)` SHALL create a new LazyFrame with a `taking(n)` transducer
appended, then collect it. The original LazyFrame SHALL NOT be modified.
Early termination SHALL be supported via the `Reduced` protocol.

#### Scenario: Head returns n rows without mutating

- **WHEN** `lazy = df | po.where(Person.age > 25)` then `result = lazy.head(5)`
- **THEN** `result` SHALL be an eager `DataFrame` with at most 5 matching rows
- **AND** `lazy` SHALL still be usable without the take(5) in its plan

### Requirement: Schema mismatch on pipe raises early error

The system SHALL raise a `SchemaError` when a transducer built from one schema
is applied via `|` to a DataFrame with an incompatible schema. The error SHALL
be raised at pipe time (when `|` is evaluated), not at collect time.

Schema validation uses the `required_columns` set stored on Expr-based
transducers (see `transducer/spec.md`). Low-level transducers without
`required_columns` SHALL bypass schema validation.

#### Scenario: Incompatible schema raises on pipe

- **WHEN** `pipeline = po.where(Person.age > 25)` is applied via `df_other | pipeline`
  where `df_other` has columns `["name", "salary"]` (no `age` column)
- **THEN** the system SHALL raise a `SchemaError` immediately
- **AND** the error message SHALL name the missing column and list available columns

#### Scenario: Low-level transducers bypass schema check

- **WHEN** `po.filtering(lambda row: row["x"] > 0)` is applied via `df | xf`
- **THEN** no `SchemaError` SHALL be raised at pipe time (no `required_columns`)

### Requirement: where builds filtering transducer from Expr

`po.where(expr)` SHALL accept an `Expr` and return a transducer that filters
rows where the expression evaluates to true.

#### Scenario: Where with expression

- **WHEN** `po.where(Person.age > 25)` is applied to a DataFrame
- **THEN** only rows where `age > 25` SHALL be included in the result

### Requirement: select builds project operation from Exprs

`po.select(*exprs)` SHALL accept one or more `Expr` (column references) and
return an operation that projects the DataFrame to those columns. The result
schema SHALL be auto-generated with only the selected columns.

`select` is the user-facing API for the `project` primitive (Δ in Spivak's
framework). Internally it operates on schema structure. It is implemented as
a transducer for composability with the pipe operator.

#### Scenario: Select columns

- **WHEN** `po.select(Person.name)` is applied to a DataFrame with `name` and `age`
- **THEN** the result SHALL have only the `name` column
- **AND** the result schema SHALL reflect the reduced column set

### Requirement: User-facing reduce on DataFrame

`po.reduce(reducer, df)` SHALL apply a reducer to a DataFrame's rows and
return the final result. This is the user-facing API for the reduce primitive.

#### Scenario: Reduce DataFrame with sum

- **WHEN** `po.reduce(po.sum_reducer, df)` is called where `df` has column `age`
  with values `[30, 25, 40]`
- **THEN** the result SHALL be `95`

#### Scenario: Reduce with transducer

- **WHEN** `po.reduce(po.count, df, transducer=po.where(Person.age > 25))` is called
  where `df` has ages `[30, 20, 40]`
- **THEN** the transducer SHALL filter to ages `[30, 40]` and the count SHALL be `2`
