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

### Requirement: Null semantics divergence between groupby and join is intentional [BIZ-002]

groupby and join treat `None` differently by design:

- **groupby**: `None` keys are treated as equal — all rows with `None` for a
  key column are placed in the same group. Rationale: groupby answers "what are
  the groups?", and "unknown" is a valid group. This follows pandas convention.
- **join**: `None == None` evaluates to `False` — rows with `None` join keys
  never match. Rationale: join answers "which rows correspond?", and two unknown
  values should not be assumed to correspond. This follows SQL convention.

This divergence is intentional and documented. Both specs cross-reference
each other.

#### Scenario: Developer observes different null behavior

- **GIVEN** `df` has rows with `dept=None`
- **WHEN** `df | po.groupby(Person.dept, n=po.count_of())` is called
- **THEN** all `None`-dept rows SHALL be in one group with count > 1
- **BUT** `po.join(df, df2, on=Person.dept == S2.dept)` where both have
  `dept=None`
- **THEN** no match SHALL be produced (`None != None` in join)

### Requirement: Self-join uses positional parsing of on-expression [BIZ-003]

Self-join (`po.join(df, df, on=...)`) is supported. The `on` expression's
positional structure determines left vs right mapping:

- In `on=ColumnRef_A == ColumnRef_B`, the left operand of `==` is evaluated
  against the left DataFrame's schema, the right operand against the right
  DataFrame's schema
- For self-join where both schemas are identical, position is the only
  differentiator
- `po.join(df, df, on=Person.id == Person.id)` is valid: left `Person.id`
  from left df, right `Person.id` from right df

Self-join requires explicit suffixes when non-key columns collide (which they
always will for true self-joins).

#### Scenario: Self-join with suffixes

- **GIVEN** `df` uses schema `Person(id: int, name: str)`
- **WHEN** `po.join(df, df, on=Person.id == Person.id, suffixes=("_1", "_2"))`
- **THEN** result SHALL have columns: `[id, name_1, name_2]`

#### Scenario: Self-join without suffixes when columns collide

- **GIVEN** `df` uses schema `Person(id: int, name: str)`
- **WHEN** `po.join(df, df, on=Person.id == Person.id)` (default suffixes)
- **THEN** result SHALL have columns: `[id, name_left, name_right]`

### Requirement: groupby accepts arbitrary Expr as keys, not only ColumnRef [BIZ-004]

groupby key arguments can be any `Expr`, not just `ColumnRef`. For computed key
expressions, the output column name cannot be automatically determined.

- ColumnRef keys: output column named after the column (e.g., `Person.dept` →
  `"dept"`)
- Computed Expr keys: SHALL raise `ValueError` if used as positional arguments,
  because the output column name cannot be automatically determined

To use a computed key, the developer should first derive the key column, then
group by it:
`df | po.derive(band=Person.salary // 10000) | po.groupby(schema.band, total=po.sum_of(Person.salary))`

#### Scenario: ColumnRef as groupby key

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** result SHALL have columns `[dept, total]`

#### Scenario: Computed expression as positional groupby key

- **WHEN** `df | po.groupby(Person.salary // 10000, total=po.sum_of(Person.salary))`
- **THEN** the system SHALL raise a `ValueError`: "Computed expression used as
  groupby key. Cannot infer output column name. Use po.derive() to create a
  named column first, then group by it."

### Requirement: Join key uses left-side column name; right-side key column is dropped [BIZ-005]

When join key columns have different names (`on=L.emp_id == R.employee_id`),
the result schema uses the left-side column name (`"emp_id"`). The right-side
key column (`"employee_id"`) is not included in the output — it is redundant
with the join key.

#### Scenario: Asymmetric key names

- **GIVEN** left has columns `[emp_id, name]`, right has columns
  `[employee_id, salary]`
- **WHEN** `po.join(left, right, on=L.emp_id == R.employee_id)`
- **THEN** result columns SHALL be `[emp_id, name, salary]` (no `"employee_id"`)

### Requirement: Join output column order is deterministic [MATH-009]

Join output columns SHALL be ordered as follows:

1. Join key columns (using left-side names), in order of appearance in the
   `on` expression
2. Remaining left-side columns (excluding keys), in left schema field order
3. Remaining right-side columns (excluding keys), in right schema field order

Non-key columns with name collisions SHALL have suffixes applied before ordering.

#### Scenario: Join column ordering

- **GIVEN** left schema: `[id, name, dept]`, right schema: `[id, salary, dept]`
- **AND** `on=L.id == R.id` (single key)
- **AND** suffix collision on `"dept"` → `dept_left`, `dept_right`
- **WHEN** join result schema is computed
- **THEN** column order SHALL be `[id, name, dept_left, salary, dept_right]`

### Requirement: groupby with all-None key values produces single group [MATH-010]

When all rows have `None` for the groupby key column, they are treated as
equal and form a single group. The result is one row with the key column value
as `None` and the aggregated values.

#### Scenario: All-None groupby key

- **GIVEN** `df` has 5 rows, all with `dept=None`
- **WHEN** `df | po.groupby(Person.dept, n=po.count_of())`
- **THEN** result SHALL be 1 row: `{dept: None, n: 5}`

### Requirement: Join suffixes apply only to colliding non-key columns [MATH-013]

Suffixes SHALL be applied only to non-key columns that have the same name in
both the left and right schemas. Non-colliding columns SHALL retain their
original names.

#### Scenario: Suffixes on colliding columns only

- **GIVEN** left schema: `[id, name, dept]`, right schema: `[id, salary, dept]`
- **AND** join on `id`, suffixes `("_left", "_right")`
- **WHEN** result schema is computed
- **THEN** columns SHALL be `[id, name, dept_left, salary, dept_right]`
- **AND** `"name"` and `"salary"` SHALL NOT be suffixed (no collision)

#### Scenario: No collisions, no suffixes

- **GIVEN** left schema: `[id, name]`, right schema: `[id, salary]`
- **AND** join on `id`
- **WHEN** result schema is computed
- **THEN** columns SHALL be `[id, name, salary]` (no suffixes applied)

### Requirement: SchemaError if suffixes do not resolve all column name collisions [ARCH-010]

After applying suffixes to colliding non-key columns, if any column names
still collide, `SchemaError` SHALL be raised at join construction time.

#### Scenario: Suffixes that don't resolve collision

- **GIVEN** left schema: `[id, name_left]`, right schema: `[id, name]`
- **AND** suffixes `("_left", "_right")`
- **WHEN** left's `"name_left"` does not collide, but right's `"name"` becomes
  `"name_right"`
- **THEN** no collision — valid

#### Scenario: Identical suffixes cause post-suffix collision

- **GIVEN** left schema: `[id, name]`, right schema: `[id, name]`
- **AND** suffixes `("_x", "_x")`
- **WHEN** suffixes are applied: left `"name_x"`, right `"name_x"`
- **THEN** the system SHALL raise a `SchemaError`: "Suffix application did not
  resolve column name collision: 'name_x'. Use distinct suffixes."

### Requirement: IntegrityError from join validate includes key values and source [BIZ-012]

When join validation (`validate="1:1"`, `"1:N"`, `"N:1"`) fails, the
`IntegrityError` SHALL include:

- Which side violated uniqueness (left, right, or both)
- The duplicate key value(s) that caused the violation
- The validate mode that was specified

#### Scenario: 1:1 validation failure

- **GIVEN** left df has duplicate key value `42`
- **WHEN** `po.join(left, right, on=..., validate="1:1")`
- **THEN** at materialization, the system SHALL raise an `IntegrityError`:
  "Join validation failed (validate='1:1'): duplicate key [42] found on
  left side"
