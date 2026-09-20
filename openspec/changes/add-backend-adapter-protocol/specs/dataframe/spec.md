## MODIFIED Requirements

### Requirement: DataFrame export to Python structures

The DataFrame SHALL provide methods to export data as standard Python
structures, and MAY provide methods to export to third-party dataframe
libraries when they are installed. All export methods SHALL trigger
materialization if the DataFrame has an uncollected plan.

- `df.to_dict()` SHALL return `dict[str, list]` in columnar format
- `df.to_rows()` SHALL return `list[dict]` in row format
- `df.to_pandas()` SHALL return a `pandas.DataFrame` with equivalent data and
  column order, raising `UnsupportedOperationError` if pandas is not
  installed
- `df.to_polars()` SHALL return a `polars.DataFrame` with equivalent data and
  column order, raising `UnsupportedOperationError` if polars is not
  installed

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

#### Scenario: Export to pandas

- **WHEN** `df.to_pandas()` is called on a DataFrame with `name` and `age`
  columns
- **THEN** the result SHALL be a `pandas.DataFrame` with the same column
  names, order, and values

#### Scenario: Export to pandas without pandas installed

- **GIVEN** pandas is not installed in the current environment
- **WHEN** `df.to_pandas()` is called
- **THEN** `UnsupportedOperationError` SHALL be raised naming pandas as the
  missing optional dependency

## ADDED Requirements

### Requirement: DataFrame construction accepts an optional backend

`po.DataFrame(...)` SHALL accept an optional `backend:` argument conforming
to the `Backend` protocol (see `backend/spec.md`) and an optional
`on_unsupported: Literal["raise", "fallback"] = "raise"` argument. When
`backend` is omitted, the pure-Python backend SHALL be used, and observable
behavior SHALL be identical to `add-core-architecture`'s specification with
no `backend` concept present.

#### Scenario: Default construction is backend-transparent

- **WHEN** `po.DataFrame({"name": ["Ana"], "age": [30]})` is constructed
  with no `backend` argument
- **THEN** all behavior SHALL match `add-core-architecture`'s specification
  exactly, with `df.backend` reporting the pure-Python backend

#### Scenario: Explicit backend and fallback policy

- **WHEN** `po.DataFrame(data, backend=SomeBackend(), on_unsupported="fallback")`
  is constructed
- **THEN** `df.backend` SHALL be that backend instance
- **AND** unsupported operations in the pipeline SHALL fall back to the
  pure-Python backend rather than raising, per `backend/spec.md`

### Requirement: from_pandas and from_polars construct a DataFrame

`from_pandas` and `from_polars` SHALL construct a poco `DataFrame` from an
existing pandas or polars DataFrame: `po.from_pandas(pdf,
column_map=None)` and `po.from_polars(pldf, column_map=None)` accept the
source frame, inferring the schema from the source columns' dtypes. Both SHALL apply the import boundary rules defined in
`backend/spec.md` ("Import boundary rejects unsupported dtypes and column
names").

#### Scenario: from_pandas infers schema

- **GIVEN** a pandas DataFrame with an `int64` column `"age"` and an
  `object` (string) column `"name"`
- **WHEN** `po.from_pandas(pdf)` is called
- **THEN** the resulting `DataFrame`'s inferred schema SHALL have `age: int`
  and `name: str`

#### Scenario: from_polars infers schema

- **GIVEN** a polars DataFrame with an `Int64` column `"age"` and a `Utf8`
  column `"name"`
- **WHEN** `po.from_polars(pldf)` is called
- **THEN** the resulting `DataFrame`'s inferred schema SHALL have `age: int`
  and `name: str`
