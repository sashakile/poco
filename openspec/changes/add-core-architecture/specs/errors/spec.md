---
id: spec
kind: intent
statement: "THE system SHALL raise stable, structured, actionable public exceptions rooted in PocoError, translating internal failures with cause chaining"
---

# Public error contract

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| ce.taxonomy | invariant | The public taxonomy is rooted in `PocoError` and includes SchemaError, ColumnNotFoundError, NullValueError, IntegrityError, and UnsupportedOperationError as stable API | [[spec]] |
| ce.diagnostics | invariant | Public exceptions expose `.code` (stable), `.message`, and `.details` with the minimum per-class fields (column/available_columns, operation, expected/actual, validate/side/join_keys, feature) | [[spec]] |
| ce.message_quality | invariant | Messages state what happened, where, and the corrective action, without blame or required parsing | [[spec]] |
| ce.boundary_translation | invariant | Internal container/library failures are translated into the taxonomy before crossing the API boundary; undocumented raw KeyError/IndexError never escape | [[spec]] |
| ce.passthrough_documented | invariant | Only explicitly documented raw exceptions (e.g. ZeroDivisionError from user-authored arithmetic) pass through; undocumented runtime errors are wrapped into `PocoError` preserving the cause | [[spec]] |
| ce.cause_chaining | invariant | Translation uses `raise ... from original` so `__cause__` retains the original exception | [[spec]] |
| ce.spec_backed | invariant | Every public exception path has at least one OpenSpec scenario and one regression test | [[spec]] |

## Model

### States

- `internal_failure`
- `translated`
- `passed_through`
- `reported`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_translate | internal_failure | translated | [[spec.ce.boundary_translation]] |
| t_passthrough | internal_failure | passed_through | [[spec.ce.passthrough_documented]] |
| t_chain | translated | translated | [[spec.ce.cause_chaining]] |
| t_report | translated | reported | [[spec.ce.diagnostics]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.taxonomy | unit | [[spec.ce.taxonomy]] | documented failure modes | `except po.PocoError` catches all documented failures |
| p.diagnostics | unit | [[spec.ce.diagnostics]] | raised public exceptions per class | code/message/details carry the required minimum fields |
| p.message_quality | unit | [[spec.ce.message_quality]] | error messages across classes | messages are actionable and name column/operation plus remedy |
| p.boundary_translation | unit | [[spec.ce.boundary_translation]] | internal lookup and validation failures | public APIs raise taxonomy classes, not raw containers' errors |
| p.passthrough_documented | unit | [[spec.ce.passthrough_documented]] | division by zero and undocumented runtime errors | documented cases pass through; others wrap into PocoError |
| p.cause_chaining | unit | [[spec.ce.cause_chaining]] | wrapped internal exceptions | `__cause__` exposes the original exception |
| p.spec_backed | unit | [[spec.ce.spec_backed]] | public failure paths | each has a scenario and a regression test |

## Purpose

Give callers one predictable, debuggable error surface with structured
diagnostics instead of leaking implementation details.

## ADDED Requirements

### Requirement: Public exception taxonomy

The system SHALL expose a stable public exception taxonomy rooted in
`PocoError`. Public exception classes SHALL include at least:
- `PocoError` — base class for documented library exceptions
- `SchemaError` — invalid schema declarations, schema inference failures, and
  invalid schema evolution
- `ColumnNotFoundError` — referenced column is not present in the active schema
- `NullValueError` — strict operation encountered `None` without explicit null
  handling
- `IntegrityError` — integrity or multiplicity constraint violation
- `UnsupportedOperationError` — requested operation is well-formed but outside
  the supported feature subset

The system MAY define additional subclasses, but documented callers SHALL be
able to depend on these classes as stable API.

#### Scenario: Caller catches stable base class

- **WHEN** user code wraps a pipeline in `except po.PocoError`
- **THEN** all documented library-specific failures SHALL be catchable through
  that base class

#### Scenario: Unsupported but well-formed operation

- **WHEN** a caller uses an otherwise valid operation shape that poco does not
  support yet
- **THEN** the system SHALL raise `UnsupportedOperationError`

### Requirement: Structured exception diagnostics

Public exceptions SHALL expose stable machine-readable diagnostics without
requiring callers to parse human text. Each exception SHALL include:
- `.code` — stable low-cardinality error code string
- `.message` — human-facing explanation
- `.details` — mapping with operation-specific fields

The `.details` mapping SHALL include relevant context such as `column`,
`available_columns`, `operation`, `expected`, `actual`, `join_keys`,
`validate`, or `side` when applicable.

Minimum required fields by exception class:
- `ColumnNotFoundError.details` SHALL include `column`, `available_columns`,
  and `operation`
- `SchemaError.details` SHALL include `operation` and a capability-specific
  structural explanation such as `expected` / `actual` or conflicting names
- `NullValueError.details` SHALL include `column` and `operation`
- `IntegrityError.details` SHALL include `operation` plus feature-specific
  fields such as `validate`, `side`, `join_keys`, `row_index`, or `constraint`
- `UnsupportedOperationError.details` SHALL include `operation` and the
  unsupported `feature` or predicate shape

#### Scenario: Missing column exposes structured fields

- **WHEN** an expression references a missing column
- **THEN** `ColumnNotFoundError.code` SHALL be a stable value such as
  `"column_not_found"`
- **AND** `.details` SHALL include the missing `column` and
  `available_columns`

#### Scenario: Join validation exposes structured fields

- **WHEN** join multiplicity validation fails
- **THEN** `IntegrityError.details` SHALL include `validate`, `side`, and the
  offending `join_keys`

### Requirement: Exception message quality

Human-facing exception messages SHALL be actionable and SHALL avoid requiring
source inspection. Messages SHALL include:
- what happened
- where it happened
- what the caller can do next when a correction is possible

Messages SHALL avoid blame and SHALL not require parsing for machine behavior.

#### Scenario: NullValueError suggests corrective action

- **WHEN** a strict comparison encounters `None`
- **THEN** the `NullValueError` message SHALL identify the column and operation
- **AND** it SHALL suggest using `is_null()`, `fill_null()`, or a prior
  `where(...)` filter

### Requirement: Public boundary exception translation

The system SHALL translate internal container and library failures into the
public exception taxonomy before they cross the poco API boundary, unless a
specific pass-through exception is explicitly documented.

Undocumented raw `KeyError`, `IndexError`, or similar implementation-detail
exceptions SHALL NOT escape from public APIs.

#### Scenario: Internal lookup failure is translated

- **WHEN** internal column lookup would otherwise raise `KeyError`
- **THEN** the public API SHALL raise `ColumnNotFoundError` instead

#### Scenario: Invalid schema evolution is translated

- **WHEN** pipeline-time schema validation fails due to incompatible types
- **THEN** the public API SHALL raise `SchemaError` rather than a raw Python
  exception

### Requirement: Documented pass-through exceptions

The system SHALL document the small set of raw Python exceptions that may pass
through unchanged when they arise directly from user-authored arithmetic or
comparison semantics inside expressions.

At minimum, pass-through exceptions MAY include `ZeroDivisionError` and Python
`TypeError` from unsupported operand combinations, provided the spec documents
those cases explicitly.

#### Scenario: User-authored division by zero passes through

- **WHEN** an expression performs division by zero during evaluation
- **THEN** Python's `ZeroDivisionError` MAY propagate unchanged because it is a
  documented pass-through exception

#### Scenario: Undocumented runtime error does not leak

- **WHEN** a non-documented internal runtime error would otherwise cross the
  boundary
- **THEN** the system SHALL wrap or translate it into `PocoError` and preserve
  the original cause

### Requirement: Cause chaining and provenance

The system SHALL preserve provenance through Python exception chaining when it
translates an internal exception into a public exception.
The public exception boundary SHALL retain causal linkage for debugging.

#### Scenario: Wrapped exception preserves cause

- **WHEN** schema validation wraps an internal exception
- **THEN** the raised public exception SHALL use `raise ... from original`
- **AND** callers inspecting `__cause__` SHALL be able to see the original
  exception

### Requirement: Error scenarios remain specification-backed

Every public exception path introduced by a capability spec SHALL have at least
one corresponding scenario in OpenSpec and at least one regression test during
implementation.

#### Scenario: New exception path requires spec scenario

- **WHEN** a capability introduces a new public failure mode
- **THEN** the change SHALL add or update an OpenSpec scenario covering that
  failure mode
- **AND** implementation work SHALL add a regression test before the task is
  considered complete

## Requirements

### Requirement: Public exception taxonomy

The system SHALL expose a stable public exception taxonomy rooted in
`PocoError`. Public exception classes SHALL include at least:
- `PocoError` — base class for documented library exceptions
- `SchemaError` — invalid schema declarations, schema inference failures, and
  invalid schema evolution
- `ColumnNotFoundError` — referenced column is not present in the active schema
- `NullValueError` — strict operation encountered `None` without explicit null
  handling
- `IntegrityError` — integrity or multiplicity constraint violation
- `UnsupportedOperationError` — requested operation is well-formed but outside
  the supported feature subset

The system MAY define additional subclasses, but documented callers SHALL be
able to depend on these classes as stable API.

#### Scenario: Caller catches stable base class

- **WHEN** user code wraps a pipeline in `except po.PocoError`
- **THEN** all documented library-specific failures SHALL be catchable through
  that base class

#### Scenario: Unsupported but well-formed operation

- **WHEN** a caller uses an otherwise valid operation shape that poco does not
  support yet
- **THEN** the system SHALL raise `UnsupportedOperationError`

### Requirement: Structured exception diagnostics

Public exceptions SHALL expose stable machine-readable diagnostics without
requiring callers to parse human text. Each exception SHALL include:
- `.code` — stable low-cardinality error code string
- `.message` — human-facing explanation
- `.details` — mapping with operation-specific fields

The `.details` mapping SHALL include relevant context such as `column`,
`available_columns`, `operation`, `expected`, `actual`, `join_keys`,
`validate`, or `side` when applicable.

Minimum required fields by exception class:
- `ColumnNotFoundError.details` SHALL include `column`, `available_columns`,
  and `operation`
- `SchemaError.details` SHALL include `operation` and a capability-specific
  structural explanation such as `expected` / `actual` or conflicting names
- `NullValueError.details` SHALL include `column` and `operation`
- `IntegrityError.details` SHALL include `operation` plus feature-specific
  fields such as `validate`, `side`, `join_keys`, `row_index`, or `constraint`
- `UnsupportedOperationError.details` SHALL include `operation` and the
  unsupported `feature` or predicate shape

#### Scenario: Missing column exposes structured fields

- **WHEN** an expression references a missing column
- **THEN** `ColumnNotFoundError.code` SHALL be a stable value such as
  `"column_not_found"`
- **AND** `.details` SHALL include the missing `column` and
  `available_columns`

#### Scenario: Join validation exposes structured fields

- **WHEN** join multiplicity validation fails
- **THEN** `IntegrityError.details` SHALL include `validate`, `side`, and the
  offending `join_keys`

### Requirement: Exception message quality

Human-facing exception messages SHALL be actionable and SHALL avoid requiring
source inspection. Messages SHALL include:
- what happened
- where it happened
- what the caller can do next when a correction is possible

Messages SHALL avoid blame and SHALL not require parsing for machine behavior.

#### Scenario: NullValueError suggests corrective action

- **WHEN** a strict comparison encounters `None`
- **THEN** the `NullValueError` message SHALL identify the column and operation
- **AND** it SHALL suggest using `is_null()`, `fill_null()`, or a prior
  `where(...)` filter

### Requirement: Public boundary exception translation

The system SHALL translate internal container and library failures into the
public exception taxonomy before they cross the poco API boundary, unless a
specific pass-through exception is explicitly documented.

Undocumented raw `KeyError`, `IndexError`, or similar implementation-detail
exceptions SHALL NOT escape from public APIs.

#### Scenario: Internal lookup failure is translated

- **WHEN** internal column lookup would otherwise raise `KeyError`
- **THEN** the public API SHALL raise `ColumnNotFoundError` instead

#### Scenario: Invalid schema evolution is translated

- **WHEN** pipeline-time schema validation fails due to incompatible types
- **THEN** the public API SHALL raise `SchemaError` rather than a raw Python
  exception

### Requirement: Documented pass-through exceptions

The system SHALL document the small set of raw Python exceptions that may pass
through unchanged when they arise directly from user-authored arithmetic or
comparison semantics inside expressions.

At minimum, pass-through exceptions MAY include `ZeroDivisionError` and Python
`TypeError` from unsupported operand combinations, provided the spec documents
those cases explicitly.

#### Scenario: User-authored division by zero passes through

- **WHEN** an expression performs division by zero during evaluation
- **THEN** Python's `ZeroDivisionError` MAY propagate unchanged because it is a
  documented pass-through exception

#### Scenario: Undocumented runtime error does not leak

- **WHEN** a non-documented internal runtime error would otherwise cross the
  boundary
- **THEN** the system SHALL wrap or translate it into `PocoError` and preserve
  the original cause

### Requirement: Cause chaining and provenance

The system SHALL preserve provenance through Python exception chaining when it
translates an internal exception into a public exception.
The public exception boundary SHALL retain causal linkage for debugging.

#### Scenario: Wrapped exception preserves cause

- **WHEN** schema validation wraps an internal exception
- **THEN** the raised public exception SHALL use `raise ... from original`
- **AND** callers inspecting `__cause__` SHALL be able to see the original
  exception

### Requirement: Error scenarios remain specification-backed

Every public exception path introduced by a capability spec SHALL have at least
one corresponding scenario in OpenSpec and at least one regression test during
implementation.

#### Scenario: New exception path requires spec scenario

- **WHEN** a capability introduces a new public failure mode
- **THEN** the change SHALL add or update an OpenSpec scenario covering that
  failure mode
- **AND** implementation work SHALL add a regression test before the task is
  considered complete

## Requirements
