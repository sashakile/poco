## ADDED Requirements

### Requirement: Pipe operator extends DataFrame plan

`DataFrame | step` SHALL return a new `DataFrame` with the pipeline step
appended to its plan. The original DataFrame SHALL NOT be modified. No data
SHALL be processed until materialization is triggered.

#### Scenario: Pipe creates new DataFrame with extended plan

- **WHEN** `df | po.where(Person.age > 25)`
- **THEN** the result SHALL be a new `DataFrame` with the filter in its plan
- **AND** no rows SHALL have been processed yet
- **AND** the original `df` SHALL be unchanged

#### Scenario: Chain multiple operations

- **WHEN** `df | po.where(Person.age > 25) | po.select(Person.name)`
- **THEN** the result SHALL be a `DataFrame` with both filter and project in its plan

#### Scenario: DataFrame is immutable value object

- **WHEN** `df2 = df | po.where(Person.age > 25)` then `df3 = df2 | po.select(Person.name)`
- **THEN** `df` SHALL have no steps in its plan
- **AND** `df2` SHALL have only the filter
- **AND** `df3` SHALL have both filter and select

### Requirement: DataFrame is always lazy

DataFrame SHALL be lazy by default. Operations via `|` extend the plan without
executing it. Materialization (executing the plan) SHALL be triggered by:
- `repr(df)` / `_repr_html_(df)` — display
- `for row in df` — iteration via `__iter__`
- `len(df)` — row count via `__len__`
- `df.collect()` — explicit force

After materialization, the result SHALL be cached. Extending the plan with
another `|` step SHALL invalidate the cache.

#### Scenario: Display triggers collection

- **WHEN** `repr(df)` is called on a DataFrame with a non-empty plan
- **THEN** the plan SHALL be executed and the result displayed as a table

#### Scenario: Iteration triggers collection

- **WHEN** `for row in df` is used on a DataFrame with a non-empty plan
- **THEN** the plan SHALL be executed and rows yielded as dicts

#### Scenario: Collect caches results

- **WHEN** `df.collect()` is called, then `repr(df)` is called
- **THEN** `collect()` SHALL execute the plan and cache the result
- **AND** `repr(df)` SHALL use the cached result (no re-execution)

#### Scenario: Extending plan invalidates cache

- **WHEN** `df.collect()` is called, then `df2 = df | po.where(Person.age > 25)`
- **THEN** `df2` SHALL NOT use df's cached result for its own collection
  (df2 has a different plan)

### Requirement: DataFrame display shows plan when uncollected

When a DataFrame has not yet been collected, `repr(df)` SHALL first display
the plan and schema, then trigger collection and display the result table.
This makes the lazy-to-eager transition visible to the user.

#### Scenario: Uncollected DataFrame shows plan then data

- **WHEN** `repr(df)` is called on an uncollected DataFrame with plan `[where(age > 25)]`
- **THEN** the output SHALL include the plan steps and schema
- **AND** the output SHALL include the materialized data table

### Requirement: Pipeline step composition

`step | step` SHALL return a new composed pipeline step. Composition SHALL
be component-wise: data transforms compose via transducer composition,
schema transforms compose via function composition. Both are left-to-right.

#### Scenario: Compose and reuse pipeline

- **WHEN** `pipeline = po.where(Person.age > 25) | po.select(Person.name)`
- **THEN** `pipeline` SHALL be a composed pipeline step
- **AND** `df1 | pipeline` and `df2 | pipeline` SHALL both produce the expected
  filtered and projected result

#### Scenario: Pipeline step is callable

- **WHEN** `po.where(Person.age > 25)(df)`
- **THEN** it SHALL be equivalent to `df | po.where(Person.age > 25)`
  (returns a lazy DataFrame, does NOT force collection)

### Requirement: head as take shorthand

`DataFrame.head(n)` SHALL return a new DataFrame with a `taking(n)` step
appended. The original DataFrame SHALL NOT be modified. The returned DataFrame
is lazy like any other — display happens when the REPL calls `repr` on the
return value. Early termination SHALL be supported via the `Reduced` protocol.

#### Scenario: Head returns new DataFrame without mutating original

- **WHEN** `df2 = df | po.where(Person.age > 25)` then `df3 = df2.head(5)`
- **THEN** `df3` SHALL be a new lazy DataFrame with `taking(5)` in its plan
- **AND** `df2` SHALL still be usable without the `taking(5)` in its plan
- **AND** `repr(df3)` SHALL show at most 5 matching rows

### Requirement: Schema mismatch on pipe raises early error

The system SHALL raise a `SchemaError` when a pipeline step built from one
schema is applied via `|` to a DataFrame with an incompatible schema. The
error SHALL be raised at pipe time (when `|` is evaluated), not at collection.

Schema validation uses the `required_columns` set stored on Expr-based
pipeline steps (see `transducer/spec.md`). Low-level transducers without
`required_columns` SHALL bypass schema validation.

#### Scenario: Incompatible schema raises on pipe

- **WHEN** `pipeline = po.where(Person.age > 25)` is applied via `df_other | pipeline`
  where `df_other` has columns `["name", "salary"]` (no `age` column)
- **THEN** the system SHALL raise a `SchemaError` immediately
- **AND** the error message SHALL name the missing column and list available columns

#### Scenario: Low-level transducers bypass schema check

- **WHEN** `po.filtering(lambda row: row["x"] > 0)` is applied via `df | xf`
- **THEN** no `SchemaError` SHALL be raised at pipe time

### Requirement: Step composition SHALL validate schema compatibility

The system SHALL validate schema compatibility when two pipeline steps with
known schema transforms are composed via `|`. If the output schema of the
first step does not satisfy the `required_columns` of the second step, the
system SHALL raise a `SchemaError` at composition time.

Steps without `required_columns` (low-level transducers lifted to pipeline
steps) SHALL bypass this validation.

#### Scenario: select then where on missing column raises on composition

- **WHEN** `po.select(Person.name) | po.where(Person.age > 25)` is composed
- **THEN** the system SHALL raise a `SchemaError` at composition time
- **AND** the error message SHALL indicate that column `age` is not available
  after the `select` step

#### Scenario: where then select composes successfully

- **WHEN** `po.where(Person.age > 25) | po.select(Person.name)` is composed
- **THEN** composition SHALL succeed (where has Identity schema, so all
  columns remain available for select)

#### Scenario: Low-level steps bypass composition validation

- **WHEN** `po.filtering(lambda r: r["x"] > 0) | po.where(Person.age > 25)` is composed
- **THEN** no `SchemaError` SHALL be raised (the filtering step has no schema info)

### Requirement: where builds filtering pipeline step from Expr

`po.where(expr)` SHALL accept an `Expr` and return a pipeline step with:
- data transform: a filtering transducer evaluating the Expr per row
- schema transform: Identity (columns unchanged)

#### Scenario: Where with expression

- **WHEN** `po.where(Person.age > 25)` is applied to a DataFrame
- **THEN** only rows where `age > 25` SHALL be included after collection

### Requirement: select builds project pipeline step from Exprs

`po.select(*exprs)` SHALL accept one or more `Expr` (column references) and
return a pipeline step with:
- data transform: a transducer that keeps only the selected columns per row
- schema transform: `Project(selected_column_names)`

The result schema SHALL be auto-generated with only the selected columns.

#### Scenario: Select columns

- **WHEN** `po.select(Person.name)` is applied to a DataFrame with `name` and `age`
- **THEN** the result SHALL have only the `name` column after collection
- **AND** the result schema SHALL reflect the reduced column set

### Requirement: User-facing reduce on DataFrame

`po.reduce(reducer, df)` SHALL apply a reducer to a DataFrame's rows and
return the final result. This forces collection and returns a scalar value.
An optional `transducer` parameter accepts either a `Transducer` or a
`PipelineStep`. When a `PipelineStep` is passed, its data component (the
transducer) SHALL be extracted and applied; the schema component is ignored.

#### Scenario: Reduce DataFrame with sum

- **WHEN** `po.reduce(po.sum_reducer, df)` is called where `df` has column `age`
  with values `[30, 25, 40]`
- **THEN** the result SHALL be `95`

#### Scenario: Reduce with PipelineStep as transducer

- **WHEN** `po.reduce(po.count, df, transducer=po.where(Person.age > 25))` is called
  where `df` has ages `[30, 20, 40]`
- **THEN** the data component of `po.where(...)` SHALL be extracted
- **AND** the transducer SHALL filter to ages `[30, 40]` and the count SHALL be `2`

#### Scenario: Reduce with bare transducer

- **WHEN** `po.reduce(po.count, df, transducer=po.filtering(lambda r: r["age"] > 25))`
- **THEN** the bare transducer SHALL be applied directly to the reducer

### Requirement: comp composes left-to-right with named parameters

`po.comp(first=xf1, second=xf2)` SHALL compose transducers or pipeline steps
in left-to-right data flow order: `xf1` is applied first, then `xf2`.
`po.comp(first=a, second=b)` SHALL be equivalent to `a | b`.
`po.comp()` with no arguments SHALL return the identity.

#### Scenario: comp matches pipe order

- **WHEN** `po.comp(first=po.where(Person.age > 25), second=po.select(Person.name))`
- **THEN** the result SHALL be the same as `po.where(Person.age > 25) | po.select(Person.name)`

#### Scenario: comp with no args returns identity

- **WHEN** `po.comp()` is called with no arguments
- **THEN** it SHALL return an identity pipeline step that passes data and schema unchanged
