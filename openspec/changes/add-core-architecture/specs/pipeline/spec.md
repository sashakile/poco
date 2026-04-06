## ADDED Requirements

### Requirement: Pipe operator extends DataFrame plan

`DataFrame | step` SHALL return a new `DataFrame` with the pipeline step
appended to its plan. The original DataFrame SHALL NOT be modified. No data
SHALL be processed until materialization is triggered.

`DataFrame.__or__` SHALL accept a `PipelineStep`. If a bare `Transducer` is
provided, it SHALL be auto-lifted to a `PipelineStep` with `Identity` schema
transform. If the operand is neither, a `TypeError` SHALL be raised.

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

#### Scenario: Bare transducer auto-lifts on pipe

- **WHEN** `df | po.filtering(lambda row: row["age"] > 25)`
- **THEN** the bare transducer SHALL be lifted to a `PipelineStep` with
  `Identity` schema transform
- **AND** the result SHALL be a new `DataFrame` with the lifted step in its plan

#### Scenario: Invalid operand raises TypeError

- **WHEN** `df | 42` or `df | "hello"`
- **THEN** the system SHALL raise a `TypeError`

### Requirement: DataFrame API SHALL be immutable and always lazy

The user-facing `DataFrame` API SHALL be an immutable value object. Operations via `|` return new
DataFrames with extended plans — the original is never modified. A DataFrame
SHALL never mutate its observable state after construction. However, internal
engine implementations MAY use mutable structures during the materialization
phase (e.g., inside a transducer loop) for performance optimization, provided
this mutation is strictly isolated and not observable to the user.

Materialization (executing the plan) SHALL be triggered by:
- `repr(df)` / `_repr_html_(df)` — display
- `for row in df` — iteration via `__iter__`
- `len(df)` — row count via `__len__`
- `df.collect()` — explicit force, returns a new materialized DataFrame

Each materialization trigger SHALL execute the plan fresh. No internal cache
SHALL be maintained on the DataFrame instance.

#### Scenario: Display triggers collection

- **WHEN** `repr(df)` is called on a DataFrame with a non-empty plan
- **THEN** the plan SHALL be executed and the result displayed as a table
- **AND** the DataFrame instance SHALL NOT be mutated

#### Scenario: Iteration triggers collection

- **WHEN** `for row in df` is used on a DataFrame with a non-empty plan
- **THEN** the plan SHALL be executed and rows yielded as dicts
- **AND** the DataFrame instance SHALL NOT be mutated

#### Scenario: Collect returns new materialized DataFrame

- **WHEN** `df2 = df.collect()` is called
- **THEN** `df2` SHALL be a new DataFrame with the plan executed and data materialized
- **AND** `df2` SHALL have an empty plan (data is inline)
- **AND** the original `df` SHALL be unchanged (plan still present)

#### Scenario: Repeated materialization re-executes plan

- **WHEN** `repr(df)` is called twice on the same uncollected DataFrame
- **THEN** the plan SHALL be executed both times (no internal caching)

### Requirement: DataFrame display SHALL show plan and data

`repr(df)` SHALL display the plan steps, schema, and the materialized data
table. This makes the pipeline visible to the user.

#### Scenario: DataFrame with plan shows plan then data

- **WHEN** `repr(df)` is called on a DataFrame with plan `[where(age > 25)]`
- **THEN** the output SHALL include the plan steps and schema
- **AND** the output SHALL include the materialized data table

#### Scenario: Collected DataFrame shows data only

- **WHEN** `repr(df2)` is called on a DataFrame returned by `collect()` (empty plan)
- **THEN** the output SHALL show the data table without plan steps

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
appended, lifted to a `PipelineStep` with `Identity` schema transform.
The original DataFrame SHALL NOT be modified. The returned DataFrame
is lazy like any other — display happens when the REPL calls `repr` on the
return value. Early termination SHALL be supported via the `Reduced` protocol.

#### Scenario: Head returns new DataFrame without mutating original

- **WHEN** `df2 = df | po.where(Person.age > 25)` then `df3 = df2.head(5)`
- **THEN** `df3` SHALL be a new lazy DataFrame with `taking(5)` in its plan
- **AND** `df2` SHALL still be usable without the `taking(5)` in its plan
- **AND** `repr(df3)` SHALL show at most 5 matching rows

#### Scenario: Head with zero

- **WHEN** `df.head(0)`
- **THEN** the result SHALL be a DataFrame that materializes to 0 rows

### Requirement: Schema mismatch on pipe raises early error

The system SHALL raise a `SchemaError` when a pipeline step built from one
schema is applied via `|` to a DataFrame with an incompatible schema. The
error SHALL be raised at pipe time (when `|` is evaluated), not at collection.

Schema validation uses the `required_columns` set stored on Expr-based
pipeline steps (see `transducer/spec.md`). Low-level transducers lifted to
pipeline steps have `Identity` schema and no `required_columns`, so they
bypass schema validation.

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

Validation logic:
- `Identity` schema output preserves all input columns — any `required_columns`
  are presumed available (validation passes)
- `Project(columns)` schema output restricts to named columns — the second
  step's `required_columns` must be a subset of those columns
- `Extend(new_columns)` schema output preserves all input columns and adds
  named columns — any `required_columns` are presumed available (validation
  passes), and the extended column names are additionally known to be available
- `GroupBy(keys, aggregations)` schema output restricts to key columns and
  aggregation result columns — the second step's `required_columns` must be
  a subset of those columns
- Steps without `required_columns` (low-level transducers lifted to pipeline
  steps) bypass this validation entirely

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
- **THEN** no `SchemaError` SHALL be raised (the filtering step has Identity
  schema, which preserves all input columns)

### Requirement: High-level pipeline step constructors (Expr-based)

The system SHALL provide high-level constructors that accept `Expr` objects
(see `expression/spec.md`) and produce pipeline steps. These build on the
low-level transducers and add schema transforms:

- `where(expr)` — data: filtering transducer evaluating Expr per row; schema: Identity
- `select(*exprs)` — data: column dropper; schema: Project(selected columns)
- `derive(**named_exprs)` — data: row extender evaluating Exprs; schema: Extend(new columns)
- `sort_by(*exprs, descending=)` — data: materializing sort; schema: Identity
- `distinct(*exprs)` — data: stateful dedup transducer; schema: Identity

These are the primary user-facing API. The low-level `filtering`, `mapping`,
etc. are also public for advanced use and custom transducer construction.

Pipeline steps built from `Expr` objects SHALL store `required_columns` (the
set of column names referenced by the Expr tree). This enables schema
validation at pipe time.

#### Scenario: where wraps filtering with Expr evaluation

- **WHEN** `po.where(Person.age > 25)` is applied
- **THEN** it SHALL behave equivalently to `filtering(lambda row: row["age"] > 25)`
  with schema transform `Identity`

#### Scenario: where stores required columns

- **WHEN** `po.where(Person.age > 25)` is created
- **THEN** the pipeline step's `required_columns` SHALL be `{"age"}`

#### Scenario: select produces project schema transform

- **WHEN** `po.select(Person.name, Person.age)` is created
- **THEN** the schema transform SHALL be `Project(["name", "age"])`

#### Scenario: select with no arguments raises error

- **WHEN** `po.select()` is called with no arguments
- **THEN** the system SHALL raise a `ValueError` indicating that at least
  one column expression is required

### Requirement: Cross-layer composition

The system SHALL support composing a bare `Transducer` with a `PipelineStep`
via `|`. When this occurs, the bare transducer SHALL be lifted into a
pipeline step with `Identity` schema transform, and the composition SHALL
then proceed component-wise.

#### Scenario: Bare transducer composed with pipeline step

- **WHEN** `po.mapping(some_fn) | po.where(Person.age > 25)` is composed
- **THEN** the bare transducer SHALL be lifted into a pipeline step with
  `Identity` schema transform
- **AND** the composition SHALL produce a valid pipeline step with component-wise
  composition of both data and schema parts

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
An optional `transducer` keyword parameter accepts either a `Transducer` or a
`PipelineStep`. When a `PipelineStep` is passed, its data component (the
transducer) SHALL be extracted and applied; the schema component is ignored.

Because DataFrame iteration yields row dicts, reducers passed directly to
`po.reduce(..., df)` SHALL be compatible with rows. Reducers over scalar
column values SHALL use a column-bound reducer such as `sum_of(expr)` or
`mean_of(expr)`.

Only streaming transducers and streaming pipeline steps are valid in the
`transducer=` parameter. Materializing steps such as `sort_by` and `groupby`
SHALL raise a `TypeError` when passed to `po.reduce`, because `reduce` only
knows how to wrap a reducer with row-at-a-time transformations.

#### Scenario: Reduce DataFrame rows with count

- **WHEN** `po.reduce(po.count, df)` is called on a DataFrame with rows
  `{"age": 30}`, `{"age": 25}`, `{"age": 40}`
- **THEN** the result SHALL be `3`

#### Scenario: Reduce DataFrame column with column-bound reducer

- **WHEN** `po.reduce(po.sum_of(Person.age), df)` is called where `df` has column `age`
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

#### Scenario: Reduce rejects materializing pipeline steps

- **WHEN** `po.reduce(po.count, df, transducer=po.sort_by(Person.age))` is called
- **THEN** the system SHALL raise a `TypeError` indicating that materializing
  pipeline steps cannot be used as reducer wrappers

### Requirement: PipelineStep SHALL only be constructed through validated factories

`PipelineStep` SHALL NOT expose a public constructor that accepts arbitrary
`(transducer, schema_transform)` pairs. Pipeline steps SHALL only be created
through validated factory functions (`where()`, `select()`, `derive()`,
`sort_by()`, `distinct()`, `groupby()`, `comp()`, and cross-layer lifting)
that guarantee data-schema coherence — i.e., the data transform and schema
transform components are always consistent with each other.

#### Scenario: Factory functions are the only public constructors

- **WHEN** a user needs a pipeline step
- **THEN** they SHALL use `po.where(expr)`, `po.select(*exprs)`,
  `po.derive(**exprs)`, `po.sort_by(*exprs)`, `po.distinct(*exprs)`,
  `po.groupby(...)`, `po.comp(...)`, or the `|` operator on existing steps
- **AND** direct construction of `PipelineStep(transducer, schema_transform)`
  SHALL NOT be part of the public API

### Requirement: SchemaTransform SHALL be exhaustively handled

`SchemaTransform` SHALL be a sealed type hierarchy (`Identity`, `Project`,
`GroupBy`, `Extend`; future variants include `Rename`). All code matching on
`SchemaTransform` variants SHALL handle every variant explicitly. Python
implementations SHALL use `typing.assert_never()` in the default/else branch
to ensure type-checker enforcement when new variants are added.

`Extend(new_columns: dict[str, type])` represents adding computed columns.
It preserves all input columns and adds the named columns with their types.

#### Scenario: New variant causes type error in unhandled match

- **WHEN** a new `SchemaTransform` variant is added (e.g., `Extend` or `Rename`)
- **THEN** any code that matches on `SchemaTransform` variants without handling
  the new variant SHALL produce a type error detectable by mypy/pyright

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

### Requirement: sort_by orders rows by expression evaluation

`po.sort_by(*exprs, descending=False)` SHALL accept one or more `Expr` objects
and return a `PipelineStep` that reorders rows by evaluating the key expressions.

The `descending` parameter SHALL accept:
- `bool` — applies to all sort keys
- `list[bool]` — one per expression for mixed sort directions; length MUST
  match the number of expressions

`sort_by` is a **materializing** pipeline step: it requires all input rows
before producing any output. This is in contrast to streaming steps like
`where` and `select` whose data components are transducers. The pipeline
executor SHALL handle this collection boundary transparently.

Schema transform: `Identity` (columns unchanged, only row order changes).

#### Scenario: Sort by single column ascending

- **WHEN** `df | po.sort_by(Person.age)`
- **THEN** rows SHALL be ordered by `age` in ascending order

#### Scenario: Sort by single column descending

- **WHEN** `df | po.sort_by(Person.age, descending=True)`
- **THEN** rows SHALL be ordered by `age` in descending order

#### Scenario: Sort by multiple columns

- **WHEN** `df | po.sort_by(Person.dept, Person.age)`
- **THEN** rows SHALL be ordered by `dept` first (ascending), then by `age`
  within each `dept` group (ascending)

#### Scenario: Mixed sort directions

- **WHEN** `df | po.sort_by(Person.dept, Person.age, descending=[False, True])`
- **THEN** rows SHALL be ordered by `dept` ascending, then `age` descending
  within each `dept` group

#### Scenario: Descending list length mismatch raises error

- **WHEN** `po.sort_by(Person.dept, Person.age, descending=[True])` with 2
  expressions and 1 bool
- **THEN** the system SHALL raise a `ValueError` indicating the length mismatch

#### Scenario: Sort is lazy

- **WHEN** `result = df | po.sort_by(Person.age)`
- **THEN** no computation SHALL occur until materialization is triggered

#### Scenario: Sort composes with streaming steps

- **WHEN** `df | po.where(Person.age > 25) | po.sort_by(Person.age) | po.head(5)`
- **THEN** the pipeline SHALL filter (streaming), collect and sort (materializing),
  then take the first 5 (streaming)

#### Scenario: Sort validates columns at pipe time

- **WHEN** `df | po.sort_by(Person.salary)` where `df` has no `salary` column
- **THEN** the system SHALL raise a `SchemaError` at pipe time

#### Scenario: Stable sort

- **WHEN** rows have equal sort key values
- **THEN** the relative order of those rows SHALL be preserved (stable sort)

#### Scenario: Sort empty DataFrame

- **WHEN** `df | po.sort_by(Person.age)` where `df` has 0 rows
- **THEN** the result SHALL be an empty DataFrame with the same schema

#### Scenario: Sort with no expressions raises error

- **WHEN** `po.sort_by()` is called with no arguments
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Sort stores required columns

- **WHEN** `po.sort_by(Person.dept, Person.age)` is created
- **THEN** the pipeline step's `required_columns` SHALL be `{"dept", "age"}`

### Requirement: derive adds computed columns via Expr evaluation

`po.derive(**named_exprs)` SHALL accept one or more keyword arguments where
each key is the new column name and each value is an `Expr`. It SHALL return
a `PipelineStep` that appends computed columns to each row.

The data component evaluates each Expr against the current row and adds the
result as a new column. The schema component is `Extend({name: dtype, ...})`
where dtype is inferred from the expression's type information.

#### Scenario: Add a single computed column

- **WHEN** `df | po.derive(bonus=Person.salary * 0.1)`
- **THEN** the result SHALL have all original columns plus a `bonus` column
- **AND** each row's `bonus` SHALL equal `salary * 0.1`

#### Scenario: Add multiple computed columns

- **WHEN** `df | po.derive(bonus=Person.salary * 0.1, tax=Person.salary * 0.3)`
- **THEN** the result SHALL have all original columns plus `bonus` and `tax`

#### Scenario: Derive is lazy

- **WHEN** `result = df | po.derive(bonus=Person.salary * 0.1)`
- **THEN** no computation SHALL occur until materialization is triggered

#### Scenario: Derive schema accessible without materialization

- **WHEN** `df2 = df | po.derive(bonus=Person.salary * 0.1)`
- **THEN** `df2.columns` SHALL include `"bonus"`
- **AND** `df2.schema.bonus` SHALL return a `ColumnRef` expression
- **AND** this SHALL NOT trigger materialization

#### Scenario: Column name conflict raises error

- **WHEN** `df | po.derive(age=Person.age + 1)` where `age` already exists
- **THEN** the system SHALL raise a `SchemaError` indicating the column name
  already exists and suggesting using `select` to drop the original first

#### Scenario: Derive with no arguments raises error

- **WHEN** `po.derive()` is called with no keyword arguments
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Derive validates source columns at pipe time

- **WHEN** `df | po.derive(bonus=Person.salary * 0.1)` where `df` has no
  `salary` column
- **THEN** the system SHALL raise a `SchemaError` at pipe time

#### Scenario: Derive composes with downstream steps

- **WHEN** a pipeline chains derive then filter on the derived column:
  `df | po.derive(bonus=Person.salary * 0.1) | po.where(S.bonus > 100)`
  where `S` is the result schema after derive
- **THEN** the pipeline SHALL compute the bonus column, then filter on it

#### Scenario: Derive stores required columns

- **WHEN** `po.derive(bonus=Person.salary * 0.1)` is created
- **THEN** the pipeline step's `required_columns` SHALL be `{"salary"}`

### Requirement: distinct removes duplicate rows

`po.distinct(*exprs)` SHALL return a `PipelineStep` that removes duplicate rows.

- With no `Expr` arguments: removes rows where all column values are duplicated.
- With one or more `Expr` arguments: removes rows where the specified column
  values are duplicated, keeping the first occurrence of each unique combination.

The data component is a stateful transducer that tracks seen key values and
only passes through rows whose key has not been seen before. Schema transform:
`Identity` (all columns preserved; only duplicate rows are removed).

#### Scenario: Distinct all columns

- **WHEN** `df | po.distinct()`
- **THEN** duplicate rows (where all column values match) SHALL be removed
- **AND** the first occurrence of each unique row SHALL be preserved

#### Scenario: Distinct on specific columns

- **WHEN** `df | po.distinct(Person.dept)`
- **THEN** only the first row per unique `dept` value SHALL be preserved
- **AND** all columns SHALL be present in the result

#### Scenario: Distinct is lazy

- **WHEN** `result = df | po.distinct()`
- **THEN** no computation SHALL occur until materialization is triggered

#### Scenario: Distinct preserves first-seen order

- **WHEN** `df | po.distinct()` is applied
- **THEN** rows SHALL appear in the order of their first occurrence

#### Scenario: Distinct on empty DataFrame

- **WHEN** `df | po.distinct()` where `df` has 0 rows
- **THEN** the result SHALL be an empty DataFrame with the same schema

#### Scenario: Distinct validates columns at pipe time

- **WHEN** `df | po.distinct(Person.salary)` where `df` has no `salary` column
- **THEN** the system SHALL raise a `SchemaError` at pipe time

#### Scenario: Distinct with nullable columns

- **WHEN** `df | po.distinct(Person.dept)` where some rows have `dept` as `None`
- **THEN** all `None` values SHALL be treated as equal (one group for `None`)

#### Scenario: Distinct stores required columns

- **WHEN** `po.distinct(Person.dept, Person.city)` is created
- **THEN** the pipeline step's `required_columns` SHALL be `{"dept", "city"}`

#### Scenario: Distinct with no exprs uses all columns

- **WHEN** `po.distinct()` is applied to a DataFrame with columns `name`, `age`
- **THEN** rows are compared on all columns — `required_columns` SHALL be empty
  (schema validation bypassed; all columns are used at collection time)
