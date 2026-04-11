## MODIFIED Requirements

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

The `po.join` function SHALL also accept an optional `validate` parameter
(`"1:1"`, `"1:N"`, `"N:1"`, `"N:N"`).

- `"1:1"`: Both sides SHALL be verified for unique join keys.
- `"N:1"`: The Right side SHALL be verified for unique join keys.
- `"1:N"`: The Left side SHALL be verified for unique join keys.
- `"N:N"`: No uniqueness check (default).

If the validation fails, the system SHALL raise `IntegrityError` at materialization
time.

#### Scenario: Join validation 1:1 fails on duplicates
- **WHEN** `po.join(df1, df2, on=..., validate="1:1")` is called
- **AND** either `df1` or `df2` has duplicate join keys
- **THEN** it SHALL raise `IntegrityError` at materialization time
