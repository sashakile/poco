## ADDED Requirements

### Requirement: DataFrame construction from dict

The system SHALL construct a DataFrame from a dict of `{column_name: [values]}`.
All value lists MUST have equal length. An optional schema parameter SHALL
validate the data against declared types.

#### Scenario: Construct from dict without schema

- **WHEN** `po.DataFrame({"name": ["Ana", "Luis"], "age": [30, 25]})`
- **THEN** a DataFrame with 2 rows and inferred schema SHALL be created

#### Scenario: Construct from dict with schema

- **WHEN** `po.DataFrame({"name": ["Ana"], "age": [30]}, schema=Person)`
- **THEN** the DataFrame SHALL validate columns and types against the `Person` schema

#### Scenario: Mismatched column lengths raise error

- **WHEN** `po.DataFrame({"name": ["Ana", "Luis"], "age": [30]})`
- **THEN** the system SHALL raise a `ValueError` with a message showing
  each column name and its length

#### Scenario: Schema mismatch raises error

- **WHEN** data has column `"salary"` not in the declared schema
- **THEN** the system SHALL raise a `SchemaError` listing unexpected columns
  and expected columns from the schema

### Requirement: DataFrame construction from rows

The system SHALL construct a DataFrame from a list of dicts (rows).
All dicts MUST have the same keys.

#### Scenario: Construct from rows

- **WHEN** `po.DataFrame([{"name": "Ana", "age": 30}, {"name": "Luis", "age": 25}])`
- **THEN** a DataFrame with 2 rows and columns `name`, `age` SHALL be created

#### Scenario: Inconsistent row keys raise error

- **WHEN** rows have different keys
- **THEN** the system SHALL raise a `SchemaError` identifying which row
  has different keys and what the difference is

### Requirement: Empty DataFrame construction

The system SHALL support constructing DataFrames with zero rows. A DataFrame
with columns but no rows preserves its schema. A DataFrame with no columns
and no rows is valid but has an empty schema.

#### Scenario: Empty columns with explicit schema

- **WHEN** `po.DataFrame({"name": [], "age": []}, schema=Person)`
- **THEN** a DataFrame with 0 rows SHALL be created
- **AND** `df.schema` SHALL match the `Person` schema

#### Scenario: Empty columns without schema raises error

- **WHEN** `po.DataFrame({"name": [], "age": []})` is called without a schema
- **THEN** the system SHALL raise a `SchemaError` because types cannot be
  inferred from empty columns
- **AND** the error message SHALL suggest providing an explicit schema

#### Scenario: Empty dict, zero columns

- **WHEN** `po.DataFrame({})`
- **THEN** a DataFrame with 0 columns and 0 rows SHALL be created

#### Scenario: Empty list of rows, zero columns

- **WHEN** `po.DataFrame([])`
- **THEN** a DataFrame with 0 columns and 0 rows SHALL be created

#### Scenario: Filter removes all rows

- **WHEN** all rows are filtered out by a `where` operation
- **THEN** the result SHALL be a valid DataFrame with 0 rows and the original schema

### Requirement: DataFrame iteration and length

The DataFrame SHALL implement `__iter__` (yielding rows as dicts) and `__len__`
(returning the number of rows). Both `__iter__` and `__len__` SHALL trigger
materialization if the DataFrame has an uncollected plan.

#### Scenario: Row iteration yields independent dict copies

- **WHEN** a user iterates via `for row in df`
- **THEN** each row SHALL be an independent dict copy mapping `{column_name: value}`
- **AND** rows SHALL be yielded in insertion order
- **AND** mutating a yielded dict SHALL NOT affect the DataFrame's internal data

#### Scenario: Column count and row count accessible

- **WHEN** a user accesses `len(df)` and `df.columns`
- **THEN** `len(df)` SHALL return the number of rows
- **AND** `df.columns` SHALL return the list of column names

#### Scenario: df.columns reflects schema after plan transforms

- **WHEN** `df2 = df | po.select(Person.name)` and `df2.columns` is accessed
- **THEN** `df2.columns` SHALL return `["name"]` (reflecting the schema after
  applying the plan's schema transforms)
- **AND** this SHALL NOT trigger materialization — the column list is computed
  from the schema transform chain, not from data

#### Scenario: df.schema reflects schema after plan transforms

- **WHEN** `df2 = df | po.select(Person.name)` and `df2.schema` is accessed
- **THEN** `df2.schema` SHALL reflect only the `name` column
- **AND** `df2.schema.name` SHALL return a `ColumnRef` expression
- **AND** this SHALL NOT trigger materialization

### Requirement: DataFrame display

`DataFrame.__repr__` SHALL display the data as a formatted table with column
names, types, and values. The default display limit SHALL be 10 rows.
Display triggers materialization of the full plan.

#### Scenario: Small DataFrame display

- **WHEN** `repr(df)` is called on a DataFrame with 3 rows
- **THEN** all 3 rows SHALL be displayed with column headers and types

#### Scenario: Large DataFrame display

- **WHEN** `repr(df)` is called on a DataFrame with 1000 rows
- **THEN** the first 5 and last 5 rows SHALL be shown with a `...` truncation
  indicator and a total row count
- **NOTE** this requires materializing all rows; users who want to avoid full
  materialization should use `df.head(n)` for a preview that supports early
  termination via the `Reduced` protocol

#### Scenario: Display of erroring plan

- **WHEN** `repr(df)` is called and the plan raises an error during materialization
- **THEN** the exception SHALL propagate to the caller (no suppression)

### Requirement: HTML display for notebooks

`DataFrame._repr_html_()` SHALL provide an HTML table representation suitable
for Jupyter and other notebook frontends. It SHALL follow the same
materialization semantics and row-limit policy as `__repr__`.

#### Scenario: HTML display materializes lazily

- **WHEN** `df._repr_html_()` is called on a DataFrame with a non-empty plan
- **THEN** the plan SHALL be executed to produce the HTML table
- **AND** the original DataFrame instance SHALL remain unchanged

#### Scenario: HTML display truncates large results

- **WHEN** `df._repr_html_()` is called on a DataFrame with more than 10 rows
- **THEN** the HTML output SHALL show the same first-5 / last-5 truncation
  policy as `repr(df)`

### Requirement: No Series type

The system SHALL NOT have a `Series` type. A single column SHALL be
represented as a one-column DataFrame.

#### Scenario: Single column is a DataFrame

- **WHEN** a user selects a single column from a DataFrame
- **THEN** the result SHALL be a `DataFrame`, not a `Series`

### Requirement: Helpful error messages

All errors raised by the DataFrame system SHALL include:
- What was expected (schema, types, column names)
- What was actually received
- A suggestion for how to fix the issue

#### Scenario: Error includes expected and actual

- **WHEN** a `SchemaError` is raised due to a missing column
- **THEN** the message SHALL include the expected column names, the actual
  column names, and a suggestion (e.g., "Did you mean 'nombre'?" for close matches)

#### Scenario: Type error includes context

- **WHEN** a `SchemaError` is raised due to mixed types in a column
- **THEN** the message SHALL name the column, list the types found, and
  suggest declaring an explicit schema

### Requirement: Column names

Column names SHALL be non-empty strings. The system SHALL raise a `SchemaError`
if a column name is empty or not a string.

#### Scenario: Empty column name raises error

- **WHEN** `po.DataFrame({"": [1, 2, 3]})`
- **THEN** the system SHALL raise a `SchemaError` indicating that column
  names must be non-empty strings

### Requirement: Plan inspection without materialization

`DataFrame.explain()` SHALL return a string representation of the pipeline
plan without triggering materialization. This allows users to inspect what
operations will be performed before paying the collection cost.

#### Scenario: Explain shows plan steps

- **WHEN** `(df | po.where(Person.age > 25) | po.select(Person.name)).explain()`
- **THEN** the output SHALL include the plan steps and their schema transforms
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

### Requirement: DataFrame export to Python structures

The DataFrame SHALL provide methods to export data as standard Python
structures. Both methods SHALL trigger materialization if the DataFrame has
an uncollected plan.

- `df.to_dict()` SHALL return `dict[str, list]` in columnar format
- `df.to_rows()` SHALL return `list[dict]` in row format

#### Scenario: to_dict returns columnar dict

- **WHEN** `df.to_dict()` is called on a DataFrame with `name` and `age` columns
- **THEN** the result SHALL be `{"name": ["Ana", "Luis"], "age": [30, 25]}`
- **AND** column order SHALL match the schema field order

#### Scenario: to_rows returns list of dicts

- **WHEN** `df.to_rows()` is called
- **THEN** the result SHALL be `[{"name": "Ana", "age": 30}, {"name": "Luis", "age": 25}]`
- **AND** rows SHALL be in the same order as iteration

#### Scenario: Export triggers materialization

- **WHEN** `(df | po.where(Person.age > 25)).to_dict()` is called
- **THEN** the plan SHALL be executed and the filtered result returned as a dict

#### Scenario: Export empty DataFrame to dict

- **WHEN** `df.to_dict()` is called on a 0-row DataFrame with columns `name` and `age`
- **THEN** the result SHALL be `{"name": [], "age": []}`

#### Scenario: Export empty DataFrame to rows

- **WHEN** `df.to_rows()` is called on a 0-row DataFrame
- **THEN** the result SHALL be `[]`

#### Scenario: Roundtrip dict to DataFrame and back

- **WHEN** `po.DataFrame(df.to_dict(), schema=df.schema)` is constructed
- **THEN** the new DataFrame SHALL be equivalent to the original (same data and schema)

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
- **AND** the original `df` SHALL be unchanged

#### Scenario: Bare transducer auto-lifts on pipe

- **WHEN** `df | po.filtering(lambda row: row["age"] > 25)`
- **THEN** the bare transducer SHALL be lifted to a `PipelineStep` with
  `Identity` schema transform

#### Scenario: Invalid operand raises TypeError

- **WHEN** `df | 42`
- **THEN** the system SHALL raise a `TypeError`

### Requirement: DataFrame API SHALL be immutable and always lazy

The user-facing `DataFrame` API SHALL be an immutable value object.
Operations via `|` return new DataFrames with extended plans. A DataFrame
SHALL never mutate its observable state after construction.

Materialization SHALL be triggered by:
- `repr(df)`
- `df._repr_html_()`
- `for row in df`
- `len(df)`
- `df.collect()`

Each materialization trigger SHALL execute the plan fresh. No internal cache
SHALL be maintained on the DataFrame instance.

#### Scenario: Collect returns new materialized DataFrame

- **WHEN** `df2 = df.collect()` is called
- **THEN** `df2` SHALL have materialized data and an empty plan
- **AND** the original `df` SHALL be unchanged

#### Scenario: Repeated materialization re-executes plan

- **WHEN** `repr(df)` is called twice on the same uncollected DataFrame
- **THEN** the plan SHALL be executed both times

### Requirement: DataFrame display SHALL show plan and data

`repr(df)` SHALL display plan steps, schema, and the materialized data table.

#### Scenario: DataFrame with plan shows plan then data

- **WHEN** `repr(df)` is called on a DataFrame with a non-empty plan
- **THEN** the output SHALL include the plan steps and the materialized data table

#### Scenario: Collected DataFrame shows data only

- **WHEN** `repr(df.collect())` is called
- **THEN** the output SHALL show the data table without plan steps

### Requirement: head as take shorthand

`DataFrame.head(n)` SHALL return a new DataFrame with a `taking(n)` step
appended, lifted to a `PipelineStep` with `Identity` schema transform.

#### Scenario: Head returns new DataFrame without mutating original

- **WHEN** `df2 = df.head(5)`
- **THEN** `df2` SHALL be a new lazy DataFrame with `taking(5)` in its plan

#### Scenario: Head with zero

- **WHEN** `df.head(0)`
- **THEN** the result SHALL materialize to 0 rows

#### Scenario: Head with negative raises error

- **WHEN** `df.head(-1)` is called
- **THEN** the system SHALL raise a `ValueError`

### Requirement: DataFrame schema property

`df.schema` SHALL return the `@po.schema` class associated with this
DataFrame. For DataFrames constructed with an explicit schema, it returns
that class. For DataFrames constructed without a schema, it returns a
dynamically inferred `@po.schema` class (see `schema/spec.md`).

#### Scenario: Declared schema accessible via df.schema

- **WHEN** `df = po.DataFrame({"name": ["Ana"], "age": [30]}, schema=Person)`
- **THEN** `df.schema` SHALL be the `Person` class
- **AND** `df.schema.age` SHALL return a `ColumnRef("age", dtype=int)` expression

#### Scenario: Inferred schema accessible via df.schema

- **WHEN** `df = po.DataFrame({"name": ["Ana"], "age": [30]})`
- **THEN** `df.schema` SHALL be a dynamically created `@po.schema` class
- **AND** `df.schema.age` SHALL return a `ColumnRef("age", dtype=int)` expression

### Requirement: DataFrame generic typing

`DataFrame` SHALL support `DataFrame[Schema]` syntax for static typing.
`DataFrame.__class_getitem__` SHALL accept a schema type parameter and return
the `DataFrame` class unchanged at runtime.

#### Scenario: Generic parameter is runtime no-op

- **WHEN** a user writes `po.DataFrame[Person]`
- **THEN** the result SHALL be the `DataFrame` class object at runtime
- **AND** the type parameter SHALL exist only for type checkers and annotations

### Requirement: User-facing reduce on DataFrame

`po.reduce(reducer, df)` SHALL apply a reducer to a DataFrame's rows and return
the final result. This SHALL force collection.

An optional `transducer` keyword parameter accepts either a `Transducer` or a
`PipelineStep`. If a `PipelineStep` is passed, only its data component SHALL be
used as the reducer wrapper.

**Constraint Boundary:** Only streaming transducers and streaming pipeline steps
(e.g., `where`, `select`, `distinct`) are valid in the `transducer=` parameter.
Materializing pipeline steps (e.g., `sort_by`, `groupby`)
SHALL raise a `TypeError` when passed as a `transducer=` argument. However,
the source `df` itself MAY contain any number of materializing steps in its
plan; `po.reduce` SHALL execute that plan fully before applying the final
reduction.

#### Scenario: Reduce DataFrame rows with count

- **WHEN** `po.reduce(po.count, df)` is called on a DataFrame with 3 rows
- **THEN** the result SHALL be `3`

#### Scenario: Reduce on sorted source DataFrame is valid

- **WHEN** `po.reduce(po.to_list, df | po.sort_by(Person.age))` is called
- **THEN** the sort SHALL be executed as part of the DataFrame materialization
- **AND** the reduction SHALL process rows in the sorted order

#### Scenario: Reduce with PipelineStep as transducer

- **WHEN** `po.reduce(po.count, df, transducer=po.where(Person.age > 25))` is called
- **THEN** the pipeline step's data transform SHALL wrap the reducer

#### Scenario: Reduce rejects materializing pipeline steps as transducer argument

- **WHEN** `po.reduce(po.count, df, transducer=po.sort_by(Person.age))` is called
- **THEN** the system SHALL raise a `TypeError` because `sort_by` is not
  a streaming transducer

### Requirement: Auto-generated schemas after schema-changing steps

The system SHALL auto-generate output schemas for schema-changing steps.
Schema-changing operations such as `select` and `derive` SHALL produce a
`df.schema` object that reflects the output columns and types without
requiring materialization. Relational operations (`groupby`, `join`) also
produce auto-generated schemas; their rules are defined in `relational/spec.md`.

#### Scenario: Select produces projected schema

- **WHEN** `df2 = df | po.select(Person.name, Person.age)`
- **THEN** `df2.schema` SHALL expose only `name` and `age`

### [ARCH-001] Requirement: DataFrame defensively copies input data at construction time

DataFrame construction SHALL shallow-copy the input data structure (dict-of-lists
or list-of-dicts). Mutations to the original data source after construction
SHALL NOT affect the DataFrame.

- Dict-of-lists: each list is shallow-copied
- List-of-dicts: the outer list is shallow-copied; individual dicts are
  shallow-copied when yielded as rows

This ensures that the "no internal cache, re-execute plan" model produces
consistent results even if the user mutates the original data.

#### Scenario: Mutating source list after construction

- **GIVEN** `data = {"x": [1, 2, 3]}`
- **AND** `df = po.DataFrame(data)`
- **WHEN** `data["x"].append(4)`
- **THEN** `list(df)` SHALL still yield `[{"x": 1}, {"x": 2}, {"x": 3}]`
  (3 rows, not 4)

#### Scenario: Mutating source dict after construction

- **GIVEN** `data = {"x": [1, 2]}`
- **AND** `df = po.DataFrame(data)`
- **WHEN** `data["y"] = [3, 4]`
- **THEN** `df.columns` SHALL be `["x"]` (no `"y"` column)

### [ARCH-003] Requirement: poco types are not thread-safe

poco types (`DataFrame`, `Reducer`, `Transducer`, `PipelineStep`) are not
thread-safe. Concurrent access to the same mutable state produces undefined
behavior.

However, concurrent materialization of the same DataFrame is safe because
materialization creates fresh transducer state per execution (see FORM-003
requirement). Two threads calling `list(df)` on the same DataFrame SHALL each
get correct, independent results, as long as the underlying data source is not
being mutated concurrently.

Concurrent mutations to the data source during materialization produce
undefined behavior.

### [FORM-003] Requirement: Transducer wrapping occurs at materialization time, not plan construction time

When a pipeline step containing a transducer is appended to a DataFrame via
`|`, the transducer SHALL be stored as a value in the plan. Wrapping (applying
the transducer to a reducer) SHALL occur at materialization time (`iter`,
`len`, `repr`, `collect()`).

Each materialization trigger SHALL create a fresh transducer chain with
independent state. This ensures:
- Repeated materialization of the same DataFrame produces identical results
  for deterministic pipelines
- Concurrent materialization of the same DataFrame is safe (no shared
  mutable state)
- Stateful transducers (`taking`, `dropping`, `distinct`) get fresh
  counters/sets per execution

#### Scenario: Repeated materialization with stateful transducer

- **GIVEN** `df = po.DataFrame({"x": [1,2,3,4,5]}) | po.taking(2)`
- **WHEN** `result1 = list(df)` and `result2 = list(df)` are called sequentially
- **THEN** `result1 == result2 == [{"x": 1}, {"x": 2}]`

#### Scenario: Concurrent materialization safety

- **GIVEN** `df = po.DataFrame(data) | po.taking(3)`
- **WHEN** two threads both call `list(df)` concurrently
- **THEN** both threads SHALL get correct 3-element results (independent state)

### [ARCH-007] Requirement: po.reduce accepts DataFrame or Iterable as collection

`po.reduce(reducer, collection)` SHALL accept:
- `DataFrame`: materialized via iteration, reducer applied to yielded rows
- Any `Iterable[dict[str, object]]`: reducer applied to items from the iterable

Generators and iterators are consumed on first use. Subsequent `po.reduce`
calls on the same exhausted generator/iterator SHALL produce the empty-input
result.

#### Scenario: Reduce on list of dicts

- **GIVEN** `data = [{"x": 1}, {"x": 2}]`
- **WHEN** `po.reduce(po.count, data)` is called
- **THEN** the result SHALL be `2`

#### Scenario: Reduce on exhausted generator

- **GIVEN** `gen = (row for row in [{"x": 1}])`
- **AND** `po.reduce(po.count, gen)` returns `1`
- **WHEN** `po.reduce(po.count, gen)` is called again
- **THEN** the result SHALL be `0` (generator exhausted)

### [HUM-003] Requirement: DataFrame documents re-execution behavior

Each materialization trigger (`repr`, `_repr_html_`, `iter`, `len`,
`collect()`) SHALL re-execute the entire pipeline plan from the data source.
There SHALL be no internal caching.

To avoid redundant execution, call `collect()` to obtain a materialized
DataFrame with inline data and an empty plan. Subsequent operations on the
collected DataFrame SHALL NOT re-execute the original plan.

#### Scenario: Collect avoids re-execution

- **GIVEN** `df = po.DataFrame(data) | expensive_pipeline`
- **AND** `collected = df.collect()`
- **WHEN** `repr(collected)` and `list(collected)` are called
- **THEN** the `expensive_pipeline` SHALL NOT be re-executed (data is inline
  in `collected`)

### [BIZ-007] Requirement: Empty DataFrame construction behavior matrix

| Input | Schema Provided? | Result |
|---|---|---|
| `{}` | No | Valid: 0 columns, 0 rows |
| `{}` | Yes | SchemaError: data has 0 columns but schema declares N columns |
| `[]` | No | Valid: 0 columns, 0 rows |
| `[]` | Yes | Valid: 0 rows, schema's columns with no data |
| `{"a": []}` | No | SchemaError: cannot infer type for empty column "a" |
| `{"a": []}` | Yes (with col a) | Valid: 1 column, 0 rows |
| `{"a": []}` | Yes (with cols a,b) | SchemaError: missing column "b" in data |
| Filter removes all | N/A | Valid: 0 rows, original schema preserved |
| `head(0)` | N/A | Valid: 0 rows, original schema preserved |

#### Scenario: Empty dict with schema

- **GIVEN** `@po.schema class S: a: int`
- **WHEN** `po.DataFrame({}, schema=S)` is constructed
- **THEN** the system SHALL raise a `SchemaError`: "Data has 0 columns but
  schema declares 1 column"

#### Scenario: Empty list with schema

- **GIVEN** `@po.schema class S: a: int`
- **WHEN** `po.DataFrame([], schema=S)` is constructed
- **THEN** a valid DataFrame with 0 rows and columns `["a"]` SHALL be created

### [FAIL-003] Requirement: Auto-generated schemas are structurally compared

Auto-generated schema classes (produced by `select`, `derive`, `groupby`,
`join`) are created per operation, not cached. Two auto-generated schemas with
the same columns and types are structurally equivalent but MAY be different
class objects.

Schema comparison SHALL use structural equality (same field names, same field
types, same order), not class identity (`is`). Code SHALL NOT use `isinstance`
checks with auto-generated schemas.

#### Scenario: Two selects producing same schema

- **GIVEN** `df1 = df | po.select(Person.name)` and
  `df2 = df | po.select(Person.name)`
- **WHEN** `df1.schema` and `df2.schema` are compared
- **THEN** they SHALL be structurally equivalent (same columns, same types)
- **BUT** `df1.schema` is not necessarily `df2.schema` (different class objects)

### [FAIL-004] Requirement: Pipeline execution uses iterative transducer application

Pipeline execution SHALL apply transducers iteratively (not recursively) to
avoid stack overflow on deeply composed pipelines. A pipeline of N streaming
steps wraps the inner reducer N times, but the wrapping itself SHALL be
iterative.

No fixed pipeline depth limit SHALL be imposed, but deeply composed pipelines
with many materializing steps incur proportional memory and computation costs.

### [HUM-008 / FAIL-007] Requirement: Materialization errors include pipeline context

When an error occurs during materialization (`NullValueError`,
`ZeroDivisionError`, `TypeError`, etc.), the exception SHALL include context
about which pipeline step caused the error, the step's position in the plan,
and (where available) the row index being processed.

#### Scenario: NullValueError with context

- **GIVEN** `df | po.where(Person.age > 30) | po.derive(bonus=Person.salary * 0.1)`
- **WHEN** materialization encounters a `None` salary in the derive step
- **THEN** the `NullValueError` SHALL include: "Error in pipeline step 2
  (derive) at row 5: column 'salary' is None"

### [HUM-008 / FAIL-007] Requirement: Pipeline steps validate Expr types at construction

High-level pipeline step constructors (`where`, `select`, `derive`, `sort_by`,
`distinct`, `groupby`) SHALL validate that their arguments are `Expr` instances
at construction time. Non-`Expr` arguments SHALL raise `TypeError` with
guidance.

#### Scenario: where receives bool instead of Expr

- **GIVEN** `person = Person(name="Alice", age=35)`
- **WHEN** `po.where(person.age > 30)` is called (`person.age > 30` evaluates
  to `True`, a `bool`)
- **THEN** the system SHALL raise a `TypeError`: "where() expected Expr, got
  bool. Use the schema class (Person.age) for expressions, not an instance."
