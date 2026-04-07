## ADDED Requirements

### Requirement: Column-bound reducers

The system SHALL provide Expr-bound aggregation reducer factories that combine
a base reducer with column extraction from the shared row contract.

- `sum_of(expr)`
- `mean_of(expr)`
- `min_of(expr)`
- `max_of(expr)`
- `count_of()`

#### Scenario: sum_of extracts and sums

- **WHEN** `po.reduce(po.sum_of(Person.salary), rows)` is called
- **THEN** the result SHALL be the sum of the extracted `salary` values

#### Scenario: count_of counts rows

- **WHEN** `po.reduce(po.count_of(), rows)` is called with 3 rows
- **THEN** the result SHALL be `3`

### Requirement: Aggregations expose required columns

Expr-bound aggregation reducers SHALL expose `required_columns` naming the
columns referenced by their bound expression.

#### Scenario: Aggregation stores required columns

- **WHEN** `po.sum_of(Person.salary)` is created
- **THEN** its `required_columns` SHALL be `{"salary"}`

### Requirement: Aggregations are compatible with relational operations

Aggregations SHALL be usable by `groupby` and DataFrame-aware reduction
without redefining reducer laws in relational capabilities.

#### Scenario: Aggregation composes with groupby

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** the aggregation SHALL consume extracted `salary` values within each group

### Requirement: Aggregation empty-input behavior follows the wrapped reducer

Expr-bound aggregation reducers SHALL preserve the total/partial behavior of
their wrapped reducer on empty input.

#### Scenario: mean_of on empty input follows mean

- **WHEN** `po.reduce(po.mean_of(Person.age), [])` is called
- **THEN** the result SHALL follow the empty-input behavior of `po.mean`

#### Scenario: min_of on empty input follows min_reducer

- **WHEN** `po.reduce(po.min_of(Person.age), [])` is called
- **THEN** the system SHALL raise the same empty-input error behavior as `po.min_reducer`
