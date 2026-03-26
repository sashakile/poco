## ADDED Requirements

### Requirement: Join as Right Kan Extension (Π)

`po.join(left_df, right_df, on=expr, how="inner")` SHALL perform a relational join between two DataFrames. It SHALL return a lazy `DataFrame` with the combined schema.

#### Scenario: Inner join
- **WHEN** `po.join(df_emp, df_dept, on=df_emp.dept_id == df_dept.id)`
- **THEN** the result SHALL contain rows where the join condition is met
- **AND** the schema SHALL contain columns from both DataFrames

#### Scenario: Join condition validation
- **WHEN** a join is performed with an expression involving columns not present in the input DataFrames
- **THEN** the system SHALL raise a `SchemaError` at pipe/call time

### Requirement: Supported Join Types
The system SHALL support `inner`, `left`, `right`, and `outer` joins.

#### Scenario: Left join preserves left rows
- **WHEN** `po.join(left, right, on=..., how="left")` is called
- **THEN** all rows from `left` SHALL be preserved, with `None` for missing `right` values
