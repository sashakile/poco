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

### Requirement: DataFrame columnar storage and iteration

The DataFrame SHALL store data in column-primary format internally (dict of
column name to list of values). The DataFrame SHALL implement `__iter__`
(yielding rows as dicts) and `__len__` (returning the number of rows).
Both `__iter__` and `__len__` SHALL trigger materialization if the DataFrame
has an uncollected plan.

#### Scenario: Row iteration yields dicts

- **WHEN** a user iterates via `for row in df`
- **THEN** each row SHALL be a dict mapping `{column_name: value}`
- **AND** rows SHALL be yielded in insertion order

#### Scenario: Column count and row count accessible

- **WHEN** a user accesses `len(df)` and `df.columns`
- **THEN** `len(df)` SHALL return the number of rows
- **AND** `df.columns` SHALL return the list of column names

### Requirement: DataFrame display

`DataFrame.__repr__` SHALL display the data as a formatted table with column
names, types, and values. The default display limit SHALL be 10 rows.

#### Scenario: Small DataFrame display

- **WHEN** `repr(df)` is called on a DataFrame with 3 rows
- **THEN** all 3 rows SHALL be displayed with column headers and types

#### Scenario: Large DataFrame display

- **WHEN** `repr(df)` is called on a DataFrame with 1000 rows
- **THEN** the first 5 and last 5 rows SHALL be shown with a `...` truncation
  indicator and a total row count

### Requirement: No Series type

The system SHALL NOT have a `Series` type. A single column SHALL be
represented as a one-column DataFrame.

#### Scenario: Single column is a DataFrame

- **WHEN** a user selects a single column from a DataFrame
- **THEN** the result SHALL be a `DataFrame` (or `LazyFrame`), not a `Series`

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

- **WHEN** a `TypeError` is raised due to mixed types in a column
- **THEN** the message SHALL name the column, list the types found, and
  suggest declaring an explicit schema
