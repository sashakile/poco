## ADDED Requirements

### Requirement: Groupby as relational pipeline step

`po.groupby(*key_exprs, **aggregations)` SHALL accept one or more `Expr`
objects as group keys and named aggregation reducers. It SHALL return a
`PipelineStep`, preserving the endomorphism `DataFrame | step -> DataFrame`.

#### Scenario: Groupby single column with aggregation

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** the result SHALL be a lazy `DataFrame` with columns `dept` and `total`

#### Scenario: Groupby preserves DataFrame endomorphism

- **WHEN** `result = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** `result` SHALL be a `DataFrame`

### Requirement: Join as relational DataFrame operation

`po.join(left_df, right_df, on=expr, how="inner")` SHALL perform a relational
join and return a lazy `DataFrame` with the combined schema.

The `on` expression SHALL be:
- a single equality `left_expr == right_expr`, or
- a conjunction of equalities combined with `&`

Each equality SHALL be interpreted positionally: the left subtree is evaluated
against the left input row and the right subtree against the right input row.
This restriction enables self-joins and multi-column equi-joins without a
separate two-table expression hierarchy.

#### Scenario: Inner join with schema classes

- **WHEN** `po.join(df_emp, df_dept, on=(Emp.dept_id == Dept.id))`
- **THEN** the result SHALL contain rows where the join condition is satisfied

#### Scenario: Join is lazy

- **WHEN** `result = po.join(df_emp, df_dept, on=..., how="inner")`
- **THEN** no computation SHALL occur until materialization is triggered

### Requirement: Supported join types

The system SHALL support `inner`, `left`, `right`, and `outer` joins. The
`how` parameter SHALL default to `"inner"`.

#### Scenario: Left join preserves left rows

- **WHEN** `po.join(left, right, on=..., how="left")` is called
- **THEN** all rows from `left` SHALL be preserved
- **AND** non-matching right-side columns SHALL be `None`

#### Scenario: Right join preserves right rows

- **WHEN** `po.join(left, right, on=..., how="right")` is called
- **THEN** all rows from `right` SHALL be preserved
- **AND** non-matching left-side columns SHALL be `None`

#### Scenario: Outer join preserves all rows

- **WHEN** `po.join(left, right, on=..., how="outer")` is called
- **THEN** all rows from both sides SHALL be preserved

#### Scenario: Invalid join type raises error

- **WHEN** `po.join(left, right, on=..., how="cross")` is called
- **THEN** the system SHALL raise a `ValueError` listing the supported join types

### Requirement: Relational output schemas

Relational operations SHALL produce output schemas without requiring
materialization.

- `groupby` SHALL expose key columns plus aggregation result columns
- `join` SHALL expose join keys once, then remaining left/right columns

#### Scenario: Groupby result schema is available before collection

- **WHEN** `grouped = df | po.groupby(Person.dept, n=po.count_of())`
- **THEN** `grouped.schema` SHALL expose `dept` and `n` before collection

#### Scenario: Join result schema is available before collection

- **WHEN** `joined = po.join(df_left, df_right, on=(L.id == R.id))`
- **THEN** `joined.schema` SHALL expose the joined output columns before collection

### Requirement: Join collision handling and nullable-side promotion

Join output schemas SHALL disambiguate colliding non-key columns with suffixes.
For `left`, `right`, and `outer` joins, columns from the nullable side SHALL be
promoted to `Optional` variants.

#### Scenario: Shared columns get suffixes

- **WHEN** `po.join(df1, df2, on=...)` and both inputs contain `name`
- **THEN** the result schema SHALL disambiguate the colliding columns with suffixes

#### Scenario: Custom suffixes are supported

- **WHEN** `po.join(df1, df2, on=..., suffixes=("_emp", "_dept"))` is called
- **THEN** colliding columns SHALL use `_emp` and `_dept`

#### Scenario: Self-join supports explicit suffixes

- **WHEN** `po.join(df, df, on=(df.schema.manager_id == df.schema.id), suffixes=("", "_mgr"))`
- **THEN** the result SHALL disambiguate colliding columns using the provided suffixes

#### Scenario: Left join promotes right types to Optional

- **WHEN** `po.join(left, right, on=..., how="left")` and `right.salary` is `int`
- **THEN** the result schema SHALL expose the right-side salary column as `int | None`

### Requirement: Multi-column equi-joins

The system SHALL support multiple equality conditions combined with `&`.

#### Scenario: Join on two columns

- **WHEN** `po.join(df1, df2, on=(S1.dept == S2.dept) & (S1.region == S2.region))`
- **THEN** the join SHALL match rows only when both equality conditions are satisfied

### Requirement: Relational validation and composition

Relational operations SHALL validate referenced columns before materialization
and SHALL compose with downstream pipeline steps under the same lazy DataFrame
contract as other operations.

#### Scenario: Groupby missing column raises error at pipe time

- **WHEN** `df | po.groupby(Person.department, count=po.count_of())`
- **THEN** the system SHALL raise a `SchemaError` before collection

#### Scenario: Join missing column raises error at call time

- **WHEN** `po.join(df1, df2, on=(S1.salary == S2.salary))` and either side lacks `salary`
- **THEN** the system SHALL raise a `SchemaError` before collection

#### Scenario: Unsupported join predicate raises error at call time

- **WHEN** `po.join(df1, df2, on=(S1.salary > S2.salary))` is called
- **THEN** the system SHALL raise a `ValueError` indicating that only equi-join predicates are supported

#### Scenario: Relational result composes with downstream pipeline

- **WHEN** `joined = po.join(df1, df2, on=...)` and `joined | po.where(joined.schema.salary > 50000)`
- **THEN** the result SHALL compose as a normal lazy DataFrame pipeline
