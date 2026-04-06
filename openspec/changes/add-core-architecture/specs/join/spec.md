## ADDED Requirements

### Requirement: Join as relational operation

`po.join(left_df, right_df, on=expr, how="inner")` SHALL perform a relational
join between two DataFrames. It SHALL return a lazy `DataFrame` with the
combined schema.

The `on` expression SHALL be an equi-join predicate:
- a single equality: `left_expr == right_expr`, or
- a conjunction of equalities combined with `&`

Each equality SHALL be interpreted positionally: the left subtree is evaluated
against the left input row, and the right subtree is evaluated against the
right input row. This restriction is what makes self-joins and multi-column
joins implementable without introducing a separate two-table expression AST.

#### Scenario: Inner join with schema classes

- **WHEN** `po.join(df_emp, df_dept, on=(Emp.dept_id == Dept.id))`
  where `Emp` and `Dept` are `@po.schema` classes
- **THEN** the result SHALL contain rows where the join condition is met
- **AND** the schema SHALL contain columns from both DataFrames

#### Scenario: Inner join with df.schema

- **WHEN** `po.join(df_emp, df_dept, on=(df_emp.schema.dept_id == df_dept.schema.id))`
- **THEN** the result SHALL be equivalent to using schema classes directly

#### Scenario: Join is lazy

- **WHEN** `result = po.join(df_emp, df_dept, on=..., how="inner")`
- **THEN** no computation SHALL occur until materialization is triggered
  (`repr`, `iter`, `len`, or `collect`)

#### Scenario: Join condition validation

- **WHEN** a join is performed with an expression involving columns not present
  in the input DataFrames
- **THEN** the system SHALL raise a `SchemaError` at call time (not at collection)

### Requirement: Supported join types

The system SHALL support `inner`, `left`, `right`, and `outer` joins. The
`how` parameter SHALL default to `"inner"`.

#### Scenario: Left join preserves left rows

- **WHEN** `po.join(left, right, on=..., how="left")` is called
- **THEN** all rows from `left` SHALL be preserved
- **AND** columns from `right` SHALL be `None` for non-matching rows

#### Scenario: Right join preserves right rows

- **WHEN** `po.join(left, right, on=..., how="right")` is called
- **THEN** all rows from `right` SHALL be preserved
- **AND** columns from `left` SHALL be `None` for non-matching rows

#### Scenario: Outer join preserves all rows

- **WHEN** `po.join(left, right, on=..., how="outer")` is called
- **THEN** all rows from both sides SHALL be preserved
- **AND** non-matching columns SHALL be `None`

#### Scenario: Invalid join type raises error

- **WHEN** `po.join(left, right, on=..., how="cross")`
- **THEN** the system SHALL raise a `ValueError` listing the supported types

### Requirement: Column name collision handling

The system SHALL disambiguate colliding non-key column names when both inputs
share them. When both DataFrames share column names (other than join key columns), the
system SHALL disambiguate by appending suffixes. The default suffixes are
`"_left"` and `"_right"`. An optional `suffixes` parameter allows customization.

#### Scenario: Shared columns get suffixes

- **WHEN** `po.join(df1, df2, on=...)` where both have a column `name`
- **THEN** the result schema SHALL have `name_left` and `name_right`

#### Scenario: Custom suffixes

- **WHEN** `po.join(df1, df2, on=..., suffixes=("_emp", "_dept"))`
- **THEN** shared columns SHALL use `_emp` and `_dept` suffixes

#### Scenario: Join key columns are not duplicated

- **WHEN** `po.join(df1, df2, on=(S1.id == S2.id))` where `id` is the join key
- **THEN** the result SHALL contain a single `id` column (not `id_left` / `id_right`)

#### Scenario: Self-join

- **WHEN** `po.join(df, df, on=(df.schema.manager_id == df.schema.id), suffixes=("", "_mgr"))`
- **THEN** the result SHALL disambiguate columns using the provided suffixes

### Requirement: Multi-column joins

The system SHALL support joining on multiple column conditions using `&`
(boolean AND) to combine equality expressions.

#### Scenario: Join on two columns

- **WHEN** `po.join(df1, df2, on=(S1.dept == S2.dept) & (S1.region == S2.region))`
- **THEN** the join SHALL match rows where both conditions are satisfied

### Requirement: Join result schema

The result schema SHALL be a dynamically created `@po.schema` class containing:
- Join key columns (single copy, not duplicated)
- Remaining columns from the left DataFrame
- Remaining columns from the right DataFrame (with suffixes if colliding)

For outer/left/right joins, columns from the nullable side SHALL have their
types promoted to `Optional` variants.

#### Scenario: Left join promotes right types to Optional

- **WHEN** `po.join(left, right, on=..., how="left")` where `right` has
  column `salary: int`
- **THEN** the result schema SHALL have `salary` as `int | None`

#### Scenario: Inner join preserves types

- **WHEN** `po.join(left, right, on=..., how="inner")` where `right` has
  column `salary: int`
- **THEN** the result schema SHALL have `salary` as `int` (not Optional)

### Requirement: Join edge cases

The system SHALL handle empty inputs and compose join results with downstream
pipeline steps using the same lazy `DataFrame` semantics as any other result.

#### Scenario: Empty left DataFrame

- **WHEN** `po.join(empty_df, right, on=..., how="inner")`
- **THEN** the result SHALL be an empty DataFrame with the combined schema

#### Scenario: Empty right DataFrame with left join

- **WHEN** `po.join(left, empty_df, on=..., how="left")`
- **THEN** the result SHALL contain all left rows with `None` for right columns

#### Scenario: Join result composes with pipeline

- **WHEN** `po.join(df1, df2, on=...) | po.where(result_schema.salary > 50000)`
- **THEN** the result SHALL compose as a normal lazy DataFrame pipeline
