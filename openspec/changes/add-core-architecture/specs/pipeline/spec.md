## ADDED Requirements

### Requirement: Pipeline reusability across DataFrames

Composed pipeline steps SHALL be reusable across multiple DataFrames.

#### Scenario: Reusable pipeline

- **WHEN** `pipeline = po.where(Person.age > 25) | po.select(Person.name)`
- **THEN** `pipeline` SHALL be a composed pipeline step
- **AND** `df1 | pipeline` and `df2 | pipeline` SHALL both produce the expected
  filtered and projected result

#### Scenario: Pipeline step is callable

- **WHEN** `po.where(Person.age > 25)(df)`
- **THEN** it SHALL be equivalent to `df | po.where(Person.age > 25)`
  (returns a lazy DataFrame, does NOT force collection)

### Requirement: Schema mismatch on pipe raises early error

The system SHALL raise a `SchemaError` when a pipeline step built from one
schema is applied via `|` to a DataFrame with an incompatible schema. The
error SHALL be raised at pipe time (when `|` is evaluated), not at collection.

Schema validation uses the `required_columns` set stored on Expr-based
pipeline steps. Low-level transducers lifted to
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

#### Scenario: select rejects computed expressions

- **WHEN** `po.select(Person.age + 1)` is called with a non-ColumnRef Expr
- **THEN** the system SHALL raise a `TypeError` indicating that `select`
  only accepts column references

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

### Requirement: select builds project pipeline step from ColumnRefs

`po.select(*exprs)` SHALL accept one or more `ColumnRef` expressions and
return a pipeline step with:
- data transform: a transducer that keeps only the selected columns per row
- schema transform: `Project(selected_column_names)`

Passing a non-`ColumnRef` expression (e.g., `Person.age + 1`) SHALL raise a
`TypeError` indicating that `select` only accepts column references, not
computed expressions. Use `derive` to create computed columns first.

The result schema SHALL be auto-generated with only the selected columns.

#### Scenario: Select columns

- **WHEN** `po.select(Person.name)` is applied to a DataFrame with `name` and `age`
- **THEN** the result SHALL have only the `name` column after collection
- **AND** the result schema SHALL reflect the reduced column set

### Requirement: PipelineStep SHALL only be constructed through validated factories

`PipelineStep` SHALL NOT expose a public constructor that accepts arbitrary
`(data_op, schema_transform)` pairs. Pipeline steps SHALL only be created
through validated factory functions (`where()`, `select()`, `derive()`,
`sort_by()`, `distinct()`, `groupby()`, `comp()`, and cross-layer lifting)
that guarantee data-schema coherence — i.e., the data operation and schema
transform components are always consistent with each other.

The data component of a `PipelineStep` SHALL be a `DataOp`, which is either:
- `StreamingOp` — backed by a transducer (processes rows one at a time)
- `MaterializingOp` — requires all input rows before producing output
  (e.g., `sort_by`, `groupby`)

Streaming steps (`where`, `select`, `derive`, `distinct`) use `StreamingOp`.
Materializing steps (`sort_by`, `groupby`) use `MaterializingOp`.

When composing steps via `|`, if either step is materializing, the composed
step SHALL be materializing (the collection boundary is preserved).

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
implementations SHALL include an explicit unreachable default branch. When
static type-checking is configured, implementations SHOULD use
`typing.assert_never()` in that branch. Regardless of toolchain, the test suite
SHALL exercise every current `SchemaTransform` variant and verify that an
unsupported runtime variant raises an assertion-style error naming the variant.

`Extend(new_columns: dict[str, type])` represents adding computed columns.
It preserves all input columns and adds the named columns with their types.

#### Scenario: New variant causes type error in unhandled match

- **WHEN** a new `SchemaTransform` variant is added (e.g., `Extend` or `Rename`)
- **THEN** any code that matches on `SchemaTransform` variants without handling
  the new variant SHALL fail either in static analysis (when configured) or in
  the runtime exhaustiveness test for unsupported variants

### Requirement: comp composes left-to-right with named parameters

`po.comp(first=xf1, second=xf2)` SHALL compose transducers or pipeline steps
in left-to-right data flow order: `xf1` is applied first, then `xf2`.
`po.comp(first=a, second=b)` SHALL be equivalent to `a | b`.
`po.comp()` with no arguments SHALL return the identity transducer (as
defined in `transducer/spec.md`). When used in a pipeline context, the
identity transducer is auto-lifted to a pipeline step via cross-layer
composition.

#### Scenario: comp matches pipe order

- **WHEN** `po.comp(first=po.where(Person.age > 25), second=po.select(Person.name))`
- **THEN** the result SHALL be the same as `po.where(Person.age > 25) | po.select(Person.name)`

#### Scenario: comp with no args returns identity transducer

- **WHEN** `po.comp()` is called with no arguments
- **THEN** it SHALL return the identity transducer
- **AND** when used in a pipeline via `|`, it SHALL be auto-lifted to a
  pipeline step with `Identity` schema transform

### Requirement: sort_by orders rows by expression evaluation

`po.sort_by(*exprs, descending=False)` SHALL accept one or more `Expr` objects
and return a `PipelineStep` that reorders rows by evaluating the key expressions.

The `descending` parameter SHALL accept:
- `bool` — applies to all sort keys
- `list[bool]` — one per expression for mixed sort directions; length MUST
  match the number of expressions

`sort_by` is a **materializing** pipeline step: it requires all input rows
before producing any output. This is in contrast to streaming steps like
`where` and `select` whose data components are transducers. When a plan reaches
`sort_by`, the executor SHALL fully realize that step's input rows before
passing sorted rows to downstream steps.

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

- **WHEN** `(df | po.where(Person.age > 25) | po.sort_by(Person.age)).head(5)`
- **THEN** the pipeline SHALL filter (streaming), collect and sort (materializing),
  then take the first 5 via `taking(5)` (streaming)

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

#### Scenario: Sort with None key raises NullValueError

- **WHEN** `df | po.sort_by(Person.age)` and a row has `age` as `None`
- **THEN** the system SHALL raise a `NullValueError` at materialization time
- **AND** the error message SHALL suggest using `fill_null()` or filtering
  nulls before sorting

#### Scenario: head on sorted DataFrame materializes sort first

- **WHEN** `(df | po.sort_by(Person.age)).head(5)` is materialized
- **THEN** the sort SHALL execute on all rows first, then `taking(5)` SHALL
  return the first 5 sorted rows

#### Scenario: head before sort limits input to sort

- **WHEN** `df.head(5) | po.sort_by(Person.age)` is materialized
- **THEN** only 5 rows SHALL be taken first, then those 5 SHALL be sorted

### Requirement: derive adds computed columns via Expr evaluation

`po.derive(**named_exprs)` SHALL accept one or more keyword arguments where
each key is the new column name and each value is an `Expr`. It SHALL return
a `PipelineStep` that appends computed columns to each row.

The data component evaluates each Expr against the **original** input row and
adds the result as a new column. Derived columns SHALL NOT reference other
columns being derived in the same `derive()` call — all expressions are
evaluated against the row as it existed before the derive step. To chain
derived columns, use separate `derive()` calls.

The schema component is `Extend({name: dtype, ...})` where dtype is inferred
from the expression's result type inference (see `expression/spec.md`).

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

### [ARCH-004] Requirement: Schema validation checks column existence only

Schema validation at pipe time (`DataFrame | step`) verifies that all columns
in the step's `required_columns` exist in the current schema. It does NOT
verify type compatibility at pipe time.

Type errors (e.g., `Person.age > 30` where age is str) are detected at
materialization time when expressions are evaluated against actual row values.
This is because type inference is best-effort and some type errors can only be
detected with concrete data.

#### Scenario: Type mismatch detected at materialization

- **WHEN** df has column "age" with type str
- **AND** `df | po.where(Person.age > 30)` is piped
- **THEN** no error SHALL be raised at pipe time (column "age" exists)
- **AND** at materialization, `TypeError` SHALL be raised when comparing str
  to int

### [FORM-004] Requirement: Materializing steps act as collection boundaries

A materializing step (`sort_by`, `groupby`) acts as a collection boundary
within a pipeline. Data streams through preceding streaming steps into the
materializing step's internal buffer. After the materializing step completes
(e.g., sorting), its output streams through subsequent streaming steps.

In a pipeline `streaming₁ | materializing | streaming₂`:
1. `streaming₁` processes rows one-at-a-time into materializing's buffer
2. `materializing` collects all rows, performs its operation (e.g., sort)
3. `materializing`'s output streams one-at-a-time through `streaming₂`

Multiple materializing steps in a pipeline create multiple collection
boundaries. Each materializing step fully collects and processes before the
next segment begins.

#### Scenario: Filter-sort-filter pipeline

- **WHEN** `df | po.where(age > 20) | po.sort_by(Person.age) | po.where(age < 50)`
  is materialized
- **THEN** `where(age > 20)` SHALL stream into `sort_by`'s buffer, `sort_by`
  SHALL sort, and sorted rows SHALL stream through `where(age < 50)`

### [ARCH-008 / FORM-005] Requirement: SchemaTransform composition is defined for all valid pairs

All pairwise compositions of `SchemaTransform` variants are either valid
(producing a well-defined result) or explicitly invalid (raising `SchemaError`
at composition time).

| First ∘ Second | Identity | Project | Extend | GroupBy |
|---|---|---|---|---|
| Identity | Identity | Project | Extend | GroupBy |
| Project | Project | Project (intersected) | Extend (if projected cols available) | GroupBy (if keys in projected cols) |
| Extend | Extend (original+new, then second) | Project (from extended set) | Extend (merged new columns; SchemaError on name conflict) | GroupBy (from extended set) |
| GroupBy | GroupBy | Project (from groupby output cols) | Extend (add to groupby output) | SchemaError: "Cannot compose two GroupBy steps; combine into single groupby call" |

Validation: at composition time, if the second step's required columns are not
in the first step's output columns, `SchemaError` SHALL be raised.

#### Scenario: GroupBy composed with GroupBy

- **WHEN** `step1 = po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **AND** `step2 = po.groupby(other_key, ...)`
- **AND** `step1 | step2` is composed
- **THEN** `SchemaError` SHALL be raised: "Cannot compose two GroupBy steps;
  combine into single groupby call"

### [BIZ-013] Requirement: select with duplicate ColumnRefs deduplicates silently

`po.select(Person.name, Person.age, Person.name)` deduplicates to
`po.select(Person.name, Person.age)`. The first occurrence determines
position. No error SHALL be raised.

Rationale: deduplication is the least surprising behavior and avoids invalid
schemas with duplicate columns.

#### Scenario: Duplicate columns in select

- **WHEN** `po.select(Person.name, Person.age, Person.name)` is constructed
- **THEN** the schema SHALL be `Project(["name", "age"])` — deduplicated,
  first-occurrence order

### [BIZ-014] Requirement: Composing multiple sort_by steps applies sorts sequentially

Each `sort_by` step is a full independent sort. Composing
`sort_by(A) | sort_by(B)` sorts by A first (materializing), then re-sorts
by B (materializing again), discarding A's ordering.

To sort by multiple keys, use a single `sort_by` call: `sort_by(B, A)`.

#### Scenario: Chained sort_by steps

- **WHEN** `df | po.sort_by(Person.age) | po.sort_by(Person.name)` is
  materialized
- **THEN** the result SHALL be sorted by name only (age sort is discarded
  by re-sort)

### [MATH-005] Requirement: sort_by validates parameters in order

`sort_by` SHALL validate parameters in this order:
1. At least one expression required — `ValueError` if no expressions provided
2. Expressions must be valid `Expr` — `TypeError` if non-Expr argument
3. If `descending` is a list, its length must match the number of expressions
   — `ValueError` on mismatch

#### Scenario: No expressions with descending list

- **WHEN** `po.sort_by(descending=[True])` is called
- **THEN** `ValueError` SHALL be raised: "sort_by requires at least one
  expression" (checked before descending)

### [MATH-012] Requirement: taking and dropping accept non-negative integers

- `taking(0)`: valid, immediately produces Reduced on first item, yielding
  empty output
- `dropping(0)`: valid, passes all items through unchanged (identity behavior)
- `taking(n)` / `dropping(n)` where n < 0: `ValueError`: "n must be
  non-negative"
- Large values (e.g., `taking(10**18)`): valid, effectively passes all items
  if input is smaller

#### Scenario: taking zero

- **WHEN** `xf = po.taking(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[]` (empty)

#### Scenario: dropping zero

- **WHEN** `xf = po.dropping(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[1, 2, 3]` (all items)

#### Scenario: Negative taking

- **WHEN** `po.taking(-1)` is called
- **THEN** `ValueError` SHALL be raised: "n must be non-negative"

### [HUM-004] Requirement: DataFrame | Expr raises TypeError with guidance

`DataFrame | Expr` SHALL raise `TypeError` with message: "Cannot pipe Expr
directly to DataFrame. Use po.where(expr) for filtering or po.select(expr)
for column selection."

This prevents confusion between `|` as boolean OR on Expr and `|` as pipe
on DataFrame.

#### Scenario: Bare Expr piped to DataFrame

- **WHEN** `df = po.DataFrame(data)` and `expr = Person.age > 30`
- **AND** developer writes `df | expr`
- **THEN** `TypeError` SHALL be raised: "Cannot pipe Expr directly to
  DataFrame. Use po.where(expr) for filtering or po.select(expr) for column
  selection."

### [HUM-005] Requirement: derive error message suggests chaining for cross-references

When `derive` raises `SchemaError` because a derived column name references
another column being derived in the same call, the error message SHALL suggest
chaining separate `derive()` calls.

#### Scenario: Derived column references sibling derivation

- **WHEN** df has no column "bonus"
- **AND** `df | po.derive(bonus=Person.salary * 0.1, tax=ColumnRef("bonus") * 0.3)`
  is evaluated
- **THEN** `SchemaError` or `ColumnNotFoundError` SHALL be raised: "Column
  'bonus' not found. Note: derived columns in the same derive() call cannot
  reference each other. Chain separate derive() calls:
  `df | po.derive(bonus=...) | po.derive(tax=schema.bonus * 0.3)`"

### [HUM-006] Requirement: reduce TypeError for materializing transducer includes guidance

When `po.reduce(reducer, df, transducer=materializing_step)` raises
`TypeError`, the error message SHALL explain why and suggest the alternative.

#### Scenario: sort_by as transducer wrapper

- **WHEN** `po.reduce(po.count, df, transducer=po.sort_by(Person.age))` is
  called
- **THEN** `TypeError` SHALL be raised: "sort_by is a materializing step and
  cannot be used as a transducer wrapper in po.reduce(). Materializing steps
  require collecting all data before processing, which is incompatible with
  streaming reduction. Move it into the DataFrame pipeline instead:
  po.reduce(po.count, df | po.sort_by(Person.age))"

### [BIZ-006] Requirement: derive SchemaError on column conflict includes recovery guidance

When `derive` detects a column name conflict with an existing column, the
`SchemaError` message SHALL include a recovery path.

#### Scenario: derive with existing column name

- **WHEN** df has column "salary"
- **AND** `df | po.derive(salary=Person.salary * 1.1)` is evaluated
- **THEN** `SchemaError` SHALL be raised: "Column 'salary' already exists. To
  replace a column, first drop it with po.select() then add it with
  po.derive(): `df | po.select(Person.name, ...) | po.derive(salary=Person.salary * 1.1)`"

### [MATH-011] Requirement: derive accepts Literal-only expressions

`po.derive(constant=Literal(42))` SHALL be valid. The expression has empty
`required_columns`, so schema validation always passes. At materialization,
the `Literal` evaluates to its value for every row.

#### Scenario: Constant column via Literal

- **WHEN** `df | po.derive(flag=Literal(True))` is applied to a DataFrame
  with 3 rows
- **THEN** the result SHALL have 3 rows, each with `flag=True`
- **AND** derived column "flag" SHALL have type `bool`
