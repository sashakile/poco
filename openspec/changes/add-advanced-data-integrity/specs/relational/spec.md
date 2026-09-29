---
id: spec
kind: intent
statement: "WHEN a join is executed THE system SHALL support inner/left/right/outer modes with SQL-like None non-matching and optional validate modes that raise diagnostic IntegrityError"
---

# Join validation and null semantics

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| rel.join_modes | invariant | `inner`, `left`, `right`, `outer` joins are supported with `how` defaulting to `"inner"`; unsupported values raise `ValueError` listing valid options | [[spec]] |
| rel.join_null_semantics | invariant | Join keys follow SQL-like truth tables: `None` matches nothing, including another None; None-keyed rows survive only their own side in outer/left/right joins | [[spec]] |
| rel.join_validate | invariant | Optional `validate` in `{"1:1", "1:N", "N:1", "N:N"}` verifies the specified uniqueness at materialization time, raising `IntegrityError` on failure; "N:N" is the no-check default | [[spec]] |
| rel.join_validate_context | invariant | A failed validation names the mode, the violating side(s), the first duplicate key values, and a resolution suggestion | [[spec]] |

## Model

### States

- `constructed`
- `matching`
- `validated`
- `rejected`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_construct | constructed | matching | [[spec.rel.join_modes]] |
| t_match | matching | matching | [[spec.rel.join_null_semantics]] |
| t_validate | matching | validated | [[spec.rel.join_validate]] |
| t_reject | matching | rejected | [[spec.rel.join_validate_context]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.join_modes | unit | [[spec.rel.join_modes]] | join calls over each how value plus invalid ones | each mode joins correctly; invalid values raise `ValueError` |
| p.join_null_semantics | unit | [[spec.rel.join_null_semantics]] | key columns containing None on either or both sides | None never matches; outer-side preservation holds |
| p.join_validate | unit | [[spec.rel.join_validate]] | frames with and without duplicate keys under each validate mode | failures raise `IntegrityError` at materialization; N:N never checks |
| p.join_validate_context | unit | [[spec.rel.join_validate_context]] | validation failures on left/right/both sides | the error names mode, side, duplicate keys, and suggestion |

## Purpose

Make join semantics explicit at the null boundary and catch cardinality
contract violations with actionable diagnostics.

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

### Requirement: Join validate IntegrityError includes diagnostic context

When join validation fails, `IntegrityError` SHALL include:
- The validate mode that was specified (e.g., "1:1", "1:N", "N:1")
- Which side violated uniqueness (left, right, or both)
- The first duplicate key value(s) found
- Suggestion for resolution (e.g., "Use validate='N:N' or deduplicate the input")

#### Scenario: N:1 validation failure with context
- **GIVEN** right df has duplicate key value "engineering"
- **WHEN** `po.join(left, right, on=..., validate="N:1")`
- **THEN** IntegrityError: "Join validation failed (validate='N:1'): duplicate key ['engineering'] found on right side. Expected right side to have unique keys. Use validate='N:N' or deduplicate the right DataFrame."

## Requirements

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

### Requirement: Join validate IntegrityError includes diagnostic context

When join validation fails, `IntegrityError` SHALL include:
- The validate mode that was specified (e.g., "1:1", "1:N", "N:1")
- Which side violated uniqueness (left, right, or both)
- The first duplicate key value(s) found
- Suggestion for resolution (e.g., "Use validate='N:N' or deduplicate the input")

#### Scenario: N:1 validation failure with context
- **GIVEN** right df has duplicate key value "engineering"
- **WHEN** `po.join(left, right, on=..., validate="N:1")`
- **THEN** IntegrityError: "Join validation failed (validate='N:1'): duplicate key ['engineering'] found on right side. Expected right side to have unique keys. Use validate='N:N' or deduplicate the right DataFrame."

## Requirements
