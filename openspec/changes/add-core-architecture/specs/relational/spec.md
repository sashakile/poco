## ADDED Requirements

### Requirement: Join as relational DataFrame operation

`po.join(left_df, right_df, on=expr, how="inner")` SHALL perform a relational
join and return a lazy `DataFrame` with the combined schema.

The `on` expression SHALL be:
- a single equality `left_expr == right_expr`, or
- a conjunction of equalities combined with `&`

**Positional Constraint:** Each equality SHALL be interpreted positionally based on the expression tree's structural properties: the `left` operand of the `BinOp(EQ, left, right)` node is evaluated against the left input DataFrame's schema, and the `right` operand is evaluated against the right input DataFrame's schema. If the schema of the `left` operand does not match the left DataFrame, or the schema of the `right` operand does not match the right DataFrame, the join SHALL fail with a `SchemaError`.

**Key Preservation:** In the resulting schema, the name of the column from the
left-hand side of the equality expression SHALL be preserved as the join key.

#### Scenario: Inner join with schema classes

- **WHEN** `po.join(df_emp, df_dept, on=(Emp.dept_id == Dept.id))`
- **THEN** the result SHALL contain rows where the join condition is satisfied
- **AND** the join key column in the result SHALL be named `dept_id`

#### Scenario: Join is lazy

- **WHEN** `result = po.join(df_emp, df_dept, on=..., how="inner")`
- **THEN** no computation SHALL occur until materialization is triggered

### Requirement: Supported join types

The system SHALL support `inner`, `left`, `right`, and `outer` joins. The
`how` parameter SHALL default to `"inner"`. Join conditions involving `None`
values SHALL follow explicit SQL-like truth tables, treating `None` as an unknown
value that cannot equal itself.

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

#### Scenario: Join on None values does not match

- **WHEN** `po.join(left, right, on=(L.key == R.key))` is called
- **AND** both rows have `None` in the `key` column
- **THEN** these rows SHALL NOT match

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

### Requirement: Groupby as relational pipeline step

`po.groupby(*key_exprs, **aggregations)` SHALL accept one or more `Expr`
objects as group keys and named aggregation reducers. It SHALL return a
`PipelineStep`, preserving the endomorphism `DataFrame | step -> DataFrame`.

#### Scenario: Groupby single column with aggregation

- **WHEN** `df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** the result SHALL be a lazy `DataFrame` with columns `dept` and `total`

#### Scenario: Groupby with multiple keys

- **WHEN** `df | po.groupby(Person.dept, Person.city, count=po.count_of())`
- **THEN** the result SHALL be partitioned by unique combinations of `dept` and `city`
- **AND** `(None, 1)` and `(None, 2)` SHALL be treated as distinct groups

#### Scenario: Groupby preserves DataFrame endomorphism

- **WHEN** `result = df | po.groupby(Person.dept, total=po.sum_of(Person.salary))`
- **THEN** `result` SHALL be a `DataFrame`

### Requirement: Relational adjunction properties (Σ ⊣ Δ ⊣ Π)

Relational operations SHALL satisfy the following properties, following Spivak's functorial data migration:

1.  **Δ Pullback (Select/Project/Rename):** Pullback along a schema mapping `f: B → A` SHALL map a DataFrame over schema `A` to a DataFrame over schema `B`. `df | po.select(...)` and `df | po.where(...)` SHALL correspond to this pullback mapping.
2.  **Σ Left Kan Extension (Groupby/Aggregate):** Grouping and aggregation SHALL correspond to the left adjoint `Σ` of the pullback `Δ`. It SHALL map data over schema `B` to schema `A` by aggregating along the fiber.
3.  **Π Right Kan Extension (Join/Normalize):** Relational join SHALL correspond to the right adjoint `Π` of the pullback `Δ`. It SHALL preserve the cartesian product of schemas and represent universal properties of the combined state.

#### Scenario: Pullback-Aggregation (Σ ⊣ Δ) Round-trip Property
- **WHEN** data is migrated via `Δ` (projected) and then aggregated via `Σ` (left Kan extension)
- **THEN** the round-trip result SHALL satisfy the universal property of the adjunction Σ ⊣ Δ.

#### Scenario: Join-Pullback (Δ ⊣ Π) Round-trip Property
- **WHEN** two DataFrames are joined via `Π` (right Kan extension) and then projected via `Δ`
- **THEN** the result SHALL correctly pull back data according to the join predicate mapping.

#### Scenario: Commutative laws for relational operators
- **WHEN** relational operators are composed (e.g., filter before or after a project)
- **THEN** the result SHALL follow the functorial laws (structure-preserving maps).
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
