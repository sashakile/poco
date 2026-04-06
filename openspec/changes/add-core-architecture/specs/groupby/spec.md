## ADDED Requirements

### Requirement: Groupby as pipeline step (Sigma / left Kan extension)

`po.groupby(*key_exprs, **aggregations)` SHALL accept one or more `Expr`
objects as group key expressions and named `ColumnReducer` arguments as
aggregations. It SHALL return a `PipelineStep`, preserving the DataFrame
endomorphism: `df | po.groupby(...) → DataFrame`.

The pipeline step SHALL have:
- data transform: groups rows by key expression evaluation, applies column
  reducers per group, emits one result row per group
- schema transform: `GroupBy(keys=[key_col_names], aggregations={name: dtype})`

#### Scenario: Groupby single column with aggregation

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** the result SHALL be a lazy `DataFrame` with columns `dept` and `total`
- **AND** each row SHALL represent one group with the summed salary

#### Scenario: Groupby multiple keys

- **WHEN** `df | po.groupby(Person.dept, Person.city, count=po.count_of())`
- **THEN** the result SHALL be partitioned by unique combinations of `dept` and `city`
- **AND** the result schema SHALL have columns `dept`, `city`, and `count`

#### Scenario: Groupby preserves DataFrame endomorphism

- **WHEN** `result = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** `result` SHALL be a `DataFrame` (not a `GroupedDataFrame` or other type)
- **AND** further pipeline operations SHALL compose: `result | po.where(result.schema.total > 100)`

#### Scenario: Groupby with no aggregations raises error

- **WHEN** `po.groupby(Person.dept)` is called with no aggregation keyword arguments
- **THEN** the system SHALL raise a `ValueError` indicating that at least one
  aggregation is required

### Requirement: Column-bound reducers in groupby

Aggregation arguments to `groupby` SHALL be column-bound reducers (see
`transducer/spec.md`). These extract a column value from each row via Expr
evaluation before applying the base reducer.

#### Scenario: Multiple aggregations

- **WHEN** `df | po.groupby(Person.dept, min_age=po.min_of(Person.age), max_age=po.max_of(Person.age))`
- **THEN** the result SHALL have columns `dept`, `min_age`, and `max_age`

#### Scenario: count_of needs no column

- **WHEN** `df | po.groupby(Person.dept, n=po.count_of())`
- **THEN** the `n` column SHALL contain the number of rows in each group

### Requirement: Lazy groupby

The `groupby` pipeline step SHALL be lazy. Materialization SHALL only occur
when the resulting DataFrame is collected, iterated, or displayed — following
the same materialization triggers as all other pipeline steps (see
`pipeline/spec.md`).

#### Scenario: Groupby is lazy

- **WHEN** `result = df | po.groupby(Person.dept, count=po.count_of())`
- **THEN** no computation SHALL occur until `result.collect()`, `repr(result)`,
  `for row in result`, or `len(result)` is called

### Requirement: Groupby schema validation

`po.groupby` SHALL validate that the key expressions and aggregation
expressions reference columns available in the input schema. Validation
SHALL occur at pipe time (when `|` is evaluated), not at collection time.

#### Scenario: Missing key column raises error on pipe

- **WHEN** `df | po.groupby(Person.department, count=po.count_of())`
  where `df` has no `department` column
- **THEN** the system SHALL raise a `SchemaError` at pipe time

#### Scenario: Missing aggregation column raises error on pipe

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
  where `df` has no `salary` column
- **THEN** the system SHALL raise a `SchemaError` at pipe time

### Requirement: Groupby edge cases

The system SHALL handle empty inputs, nullable keys, and downstream
composition for `groupby` results without breaking the lazy `DataFrame`
endomorphism.

#### Scenario: Nullable group key

- **WHEN** `df | po.groupby(Person.dept, count=po.count_of())`
  where some rows have `dept` as `None`
- **THEN** rows with `None` as the key SHALL form their own group
- **AND** the group key value SHALL be `None`

#### Scenario: Empty DataFrame groupby

- **WHEN** `df | po.groupby(Person.dept, count=po.count_of())`
  where `df` has 0 rows
- **THEN** the result SHALL be a DataFrame with 0 rows and the expected
  schema (`dept`, `count`)

#### Scenario: Single-row groups

- **WHEN** every row has a unique group key value
- **THEN** each group SHALL contain exactly one row
- **AND** aggregations SHALL operate on single-element inputs

#### Scenario: Groupby composes with downstream steps

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary)) | po.where(S.total > 100)`
  where `S` is the result schema
- **THEN** the pipeline SHALL compose correctly: group, aggregate, then filter
