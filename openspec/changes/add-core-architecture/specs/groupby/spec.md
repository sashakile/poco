## ADDED Requirements

### Requirement: Groupby creates a partitioned view

`po.groupby(*exprs)` SHALL accept one or more `Expr` objects and return a `GroupedDataFrame`. This object is a lazy representation of the data partitioned by the evaluated values of the expressions.

#### Scenario: Groupby single column
- **WHEN** `df | po.groupby(Person.department)` is called
- **THEN** it SHALL return a `GroupedDataFrame` partitioned by the `department` column

#### Scenario: Groupby multiple expressions
- **WHEN** `df | po.groupby(Person.department, Person.city)`
- **THEN** it SHALL be partitioned by the unique combinations of both expressions

### Requirement: Aggregation via Reducers (Σ)

`GroupedDataFrame.aggregate(**kwargs)` SHALL accept named arguments where keys are new column names and values are `Reducer` objects (or expressions that resolve to reducers). It SHALL return a new `DataFrame` containing the grouping keys and the aggregated results.

#### Scenario: Basic aggregation
- **WHEN** `df | po.groupby(Person.dept) | po.aggregate(total=po.sum_reducer(Person.salary))`
- **THEN** the resulting DataFrame SHALL have columns `dept` and `total`

#### Scenario: Multiple aggregations
- **WHEN** `grouped.aggregate(min_age=po.min_reducer(Person.age), max_age=po.max_reducer(Person.age))`
- **THEN** the result SHALL contain both aggregated columns

### Requirement: Lazy Groupby-Aggregate
The `groupby | aggregate` sequence SHALL be lazy. Materialization SHALL only occur when the resulting DataFrame is collected or iterated.

#### Scenario: Groupby-Aggregate is lazy
- **WHEN** `result = df | po.groupby(Person.dept) | po.aggregate(count=po.count)`
- **THEN** no computation SHALL occur until `result.collect()` or similar is called
