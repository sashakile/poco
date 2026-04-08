## ADDED Requirements

### Requirement: Join as relational DataFrame operation

`po.join(left_df, right_df, on=expr, how="inner")` SHALL perform a relational
join and return a lazy `DataFrame` with the combined schema.

The `on` expression SHALL be restricted to:
- a single equality of column references: `ColumnRef == ColumnRef`, or
- a conjunction of column-reference equalities combined with `&`

Computed expressions (e.g., `L.id + 1 == R.id`) SHALL NOT be accepted as
join predicates. The system SHALL raise a `TypeError` if a non-ColumnRef
expression is used in a join predicate.

**Positional Constraint:** Each equality SHALL be interpreted positionally:
the `left` operand of `BinOp(EQ, left, right)` is evaluated against the left
input DataFrame's schema, and the `right` operand is evaluated against the
right input DataFrame's schema.

**Key Preservation:** In the resulting schema, the name of the column from the
left-hand side of the equality expression SHALL be preserved as the join key.

#### Scenario: Inner join with schema classes

- **WHEN** `po.join(df_emp, df_dept, on=(Emp.dept_id == Dept.id))`
- **THEN** the result SHALL contain rows where the join condition is satisfied
- **AND** the join key column in the result SHALL be named `dept_id`

#### Scenario: Join is lazy

- **WHEN** `result = po.join(df_emp, df_dept, on=..., how="inner")`
- **THEN** no computation SHALL occur until materialization is triggered

#### Scenario: Computed join predicate raises error

- **WHEN** `po.join(df1, df2, on=(S1.id + 1 == S2.id))` is called
- **THEN** the system SHALL raise a `TypeError` indicating that join
  predicates must be column-reference equalities

### Requirement: Supported join types

The system SHALL support `inner`, `left`, `right`, and `outer` joins. The
`how` parameter SHALL default to `"inner"`. An unsupported `how` value SHALL
raise a `ValueError` listing valid options.

Join conditions involving `None` values SHALL follow explicit SQL-like truth
tables, treating `None` as an unknown value that cannot equal itself.

**Null Equality Truth Table:**
- `Value == Value` → `True` (if values are equal)
- `Value == None`  → `False` (no match)
- `None == Value`  → `False` (no match)
- `None == None`   → `False` (no match)

Therefore, rows with `None` in the join key SHALL NOT match each other in an
inner join, and SHALL be preserved only on their respective sides in outer,
left, or right joins.

#### Scenario: Left join preserves left rows

- **WHEN** `po.join(left, right, on=..., how="left")` is called
- **THEN** all rows from `left` SHALL be preserved
- **AND** non-matching right-side columns SHALL be `None`

#### Scenario: Right join preserves right rows

- **WHEN** `po.join(left, right, on=..., how="right")` is called
- **THEN** all rows from `right` SHALL be preserved
- **AND** non-matching left-side columns SHALL be `None`

#### Scenario: Outer join preserves both sides

- **WHEN** `po.join(left, right, on=..., how="outer")` is called
- **THEN** all rows from both sides SHALL be preserved
- **AND** non-matching columns on either side SHALL be `None`

#### Scenario: Join on None values does not match

- **WHEN** `po.join(left, right, on=(L.key == R.key))` is called
- **AND** both rows have `None` in the `key` column
- **THEN** these rows SHALL NOT match

#### Scenario: Invalid how raises error

- **WHEN** `po.join(left, right, on=..., how="cross")` is called
- **THEN** the system SHALL raise a `ValueError` listing valid join types

#### Scenario: Empty left DataFrame in inner join

- **WHEN** `po.join(empty_df, right, on=..., how="inner")` is materialized
- **THEN** the result SHALL be an empty DataFrame with the combined schema

#### Scenario: Empty right DataFrame in left join

- **WHEN** `po.join(left, empty_df, on=..., how="left")` is materialized
- **THEN** all left rows SHALL be preserved with right-side columns as `None`

### Requirement: Relational output schemas

Relational operations SHALL produce output schemas without requiring
materialization.

- `groupby` SHALL expose key columns plus aggregation result columns
- `join` SHALL expose join keys once (preserving left-side name), then
  remaining left/right columns

#### Scenario: Groupby result schema is available before collection

- **WHEN** `grouped = df | po.groupby(Person.dept, n=po.count_of())`
- **THEN** `grouped.schema` SHALL expose `dept` and `n` before collection

#### Scenario: Join result schema is available before collection

- **WHEN** `joined = po.join(df_left, df_right, on=(L.id == R.id))`
- **THEN** `joined.schema` SHALL expose the joined output columns before collection

### Requirement: Join collision handling and nullable-side promotion

Join output schemas SHALL disambiguate colliding non-key columns with suffixes.
Default suffixes SHALL be `("_left", "_right")`.
For `left`, `right`, and `outer` joins, columns from the nullable side SHALL be
promoted to `Optional` variants.

#### Scenario: Shared columns get suffixes

- **WHEN** `po.join(df1, df2, on=...)` and both inputs contain `name`
- **THEN** the result schema SHALL disambiguate as `name_left` and `name_right`

#### Scenario: Custom suffixes are supported

- **WHEN** `po.join(df1, df2, on=..., suffixes=("_emp", "_dept"))` is called
- **THEN** colliding columns SHALL use `_emp` and `_dept`

#### Scenario: Self-join supports explicit suffixes

- **WHEN** `po.join(df, df, on=(S.manager_id == S.id), suffixes=("", "_mgr"))`
- **THEN** the result SHALL disambiguate colliding columns using the provided suffixes

#### Scenario: Left join promotes right types to Optional

- **WHEN** `po.join(left, right, on=..., how="left")` and `right.salary` is `int`
- **THEN** the result schema SHALL expose the right-side salary column as `int | None`

#### Scenario: Right join promotes left types to Optional

- **WHEN** `po.join(left, right, on=..., how="right")` and `left.name` is `str`
- **THEN** the result schema SHALL expose the left-side name column as `str | None`

#### Scenario: Outer join promotes both sides to Optional

- **WHEN** `po.join(left, right, on=..., how="outer")`
- **THEN** non-key columns from both sides SHALL be promoted to `Optional` variants

### Requirement: Multi-column equi-joins

The system SHALL support multiple column-reference equality conditions combined
with `&`.

#### Scenario: Join on two columns

- **WHEN** `po.join(df1, df2, on=(S1.dept == S2.dept) & (S1.region == S2.region))`
- **THEN** the join SHALL match rows only when both equality conditions are satisfied

### Requirement: Groupby as relational pipeline step

`po.groupby(*key_exprs, **aggregations)` SHALL accept one or more `Expr`
objects as group keys and named aggregation reducers. It SHALL return a
`PipelineStep` (materializing), preserving the endomorphism
`DataFrame | step -> DataFrame`.

At least one aggregation keyword argument SHALL be provided. Calling
`po.groupby(Person.dept)` with no aggregations SHALL raise a `ValueError`.

Key-aggregation name collisions SHALL raise a `SchemaError` (e.g.,
`po.groupby(Person.dept, dept=po.count_of())`).

#### Scenario: Groupby single column with aggregation

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** the result SHALL be a lazy `DataFrame` with columns `dept` and `total`

#### Scenario: Groupby with multiple keys

- **WHEN** `df | po.groupby(Person.dept, Person.city, count=po.count_of())`
- **THEN** the result SHALL be partitioned by unique combinations of `dept` and `city`
- **AND** `(None, 1)` and `(None, 2)` SHALL be treated as distinct groups

#### Scenario: None group keys are treated as equal

- **WHEN** rows with `dept` as `None` are grouped by `Person.dept`
- **THEN** all `None`-keyed rows SHALL belong to the same group

#### Scenario: Groupby preserves DataFrame endomorphism

- **WHEN** `result = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** `result` SHALL be a `DataFrame`

#### Scenario: Groupby without aggregations raises error

- **WHEN** `po.groupby(Person.dept)` is called with no aggregation kwargs
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Key-aggregation name collision raises error

- **WHEN** `po.groupby(Person.dept, dept=po.count_of())` is called
- **THEN** the system SHALL raise a `SchemaError` indicating the name collision

#### Scenario: Groupby validates columns at pipe time

- **WHEN** `df | po.groupby(Person.salary, n=po.count_of())` where `df` has
  no `salary` column
- **THEN** the system SHALL raise a `SchemaError` at pipe time

### Requirement: Join and groupby validation

The system SHALL validate join and groupby operations at call time or pipe
time, before collection.

#### Scenario: Join missing column raises error at call time

- **WHEN** `po.join(df1, df2, on=(S1.salary == S2.salary))` and either side lacks `salary`
- **THEN** the system SHALL raise a `SchemaError` before collection

#### Scenario: Unsupported join predicate raises error at call time

- **WHEN** `po.join(df1, df2, on=(S1.salary > S2.salary))` is called
- **THEN** the system SHALL raise a `ValueError` indicating that only
  column-reference equalities are supported as join predicates

#### Scenario: Relational result composes with downstream pipeline

- **WHEN** `joined = po.join(df1, df2, on=...)` and `joined | po.where(joined.schema.salary > 50000)`
- **THEN** the result SHALL compose as a normal lazy DataFrame pipeline

### Requirement: Deterministic join output order

Join results SHALL produce rows in a deterministic order: for each left row
(in left-input order), all matching right rows SHALL appear in right-input
order.

#### Scenario: Join preserves input order

- **WHEN** `po.join(left, right, on=..., how="inner")` is materialized
- **THEN** result rows SHALL appear ordered by left-row position first,
  then by right-row position for each match
