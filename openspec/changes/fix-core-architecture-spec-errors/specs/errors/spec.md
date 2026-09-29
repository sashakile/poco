---
id: spec
kind: intent
statement: "THE system SHALL expose a stable exception taxonomy rooted in PocoError that distinguishes dual-based guardrail exceptions from unchanged pass-through exceptions"
---

# Guardrail and pass-through exceptions

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| fe.public_taxonomy | invariant | Public exceptions are rooted in `PocoError` and include SchemaError, ColumnNotFoundError, NullValueError, IntegrityError, UnsupportedOperationError, and InvalidExprUsageError as stable API | [[spec]] |
| fe.dual_catchable | invariant | `InvalidExprUsageError` subclasses both `PocoError` and built-in `TypeError`, so `except PocoError` and `except TypeError` both catch it | [[spec]] |
| fe.guardrail_category | invariant | Guardrail exceptions — poco's own code preventing protocol misuse (`Expr.__bool__`, `Expr.__hash__`) — subclass the relevant native exception and `PocoError` | [[spec]] |
| fe.passthrough_category | invariant | Pass-through exceptions arising from user-authored expression semantics (e.g. `ZeroDivisionError`) propagate unchanged and are not guardrail exceptions | [[spec]] |

## Model

### States

- `evaluating`
- `guardrail_raised`
- `passed_through`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_guardrail | evaluating | guardrail_raised | [[spec.fe.guardrail_category]] |
| t_passthrough | evaluating | passed_through | [[spec.fe.passthrough_category]] |
| t_catch_either | guardrail_raised | guardrail_raised | [[spec.fe.dual_catchable]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.public_taxonomy | unit | [[spec.fe.public_taxonomy]] | `except po.PocoError` wrappers around documented failures | all documented failures are catchable via the base class |
| p.dual_catchable | unit | [[spec.fe.dual_catchable]] | InvalidExprUsageError raised in boolean and hash contexts | both `except TypeError` and `except po.PocoError` catch it |
| p.guardrail_category | unit | [[spec.fe.guardrail_category]] | protocol misuse via Expr | the raised class satisfies the native protocol and the taxonomy simultaneously |
| p.passthrough_category | unit | [[spec.fe.passthrough_category]] | expressions dividing by zero | `ZeroDivisionError` propagates unchanged |

## Purpose

Keep the public exception contract stable while classifying raw-exception
failures so protocol guardrails never escape the documented taxonomy.

## MODIFIED Requirements

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
- `InvalidExprUsageError` — an `Expr` was used in a context it does not
  support (boolean context, hash-requiring context). This class SHALL
  subclass both `PocoError` and Python's built-in `TypeError`, so that code
  catching either base class catches it.

The system MAY define additional subclasses, but documented callers SHALL be
able to depend on these classes as stable API.

#### Scenario: Caller catches stable base class

- **WHEN** user code wraps a pipeline in `except po.PocoError`
- **THEN** all documented library-specific failures SHALL be catchable through
  that base class, including `InvalidExprUsageError`

#### Scenario: Unsupported but well-formed operation

- **WHEN** a caller uses an otherwise valid operation shape that poco does not
  support yet
- **THEN** the system SHALL raise `UnsupportedOperationError`

#### Scenario: InvalidExprUsageError is dual-catchable

- **WHEN** an `Expr` is used in a boolean context or as a dict/set key
- **THEN** the system SHALL raise `InvalidExprUsageError`
- **AND** the exception SHALL be catchable via `except po.PocoError`
- **AND** the exception SHALL also be catchable via `except TypeError`,
  unchanged from prior behavior, since `InvalidExprUsageError` is a
  `TypeError` subclass

## ADDED Requirements

### Requirement: Guardrail exceptions distinguished from pass-through exceptions

The system SHALL distinguish two categories of raw-Python-exception-shaped
failures at the API boundary:

- **Pass-through exceptions**: raw Python exceptions (e.g.
  `ZeroDivisionError`) that arise directly from user-authored arithmetic or
  comparison semantics inside expressions, governed by "Documented
  pass-through exceptions." These are not poco's own code raising an error;
  they propagate unchanged.
- **Guardrail exceptions**: cases where poco's own code deliberately raises
  an error to prevent misuse of a Python protocol (e.g. `Expr.__bool__`,
  `Expr.__hash__`). These SHALL be raised as a class that subclasses both the
  relevant native Python exception type (so protocol expectations are met)
  and `PocoError` (so the public taxonomy's catch-all promise holds).
  `InvalidExprUsageError` is the first member of this category.

#### Scenario: Guardrail exception satisfies both protocols

- **GIVEN** `hash(Person.age)` is called
- **WHEN** the hashing protocol requires a `TypeError` (or subclass) on
  failure
- **THEN** `InvalidExprUsageError` SHALL be raised, satisfying both the
  native hashing protocol and the `PocoError` taxonomy simultaneously

#### Scenario: Pass-through exceptions remain unaffected

- **GIVEN** an expression divides by a column value of `0`
- **WHEN** materialization evaluates that expression
- **THEN** `ZeroDivisionError` SHALL propagate unchanged, as before this
  change — pass-through exceptions are not guardrail exceptions and are not
  affected by this requirement

## Requirements

### Requirement: Guardrail exceptions distinguished from pass-through exceptions

The system SHALL distinguish two categories of raw-Python-exception-shaped
failures at the API boundary:

- **Pass-through exceptions**: raw Python exceptions (e.g.
  `ZeroDivisionError`) that arise directly from user-authored arithmetic or
  comparison semantics inside expressions, governed by "Documented
  pass-through exceptions." These are not poco's own code raising an error;
  they propagate unchanged.
- **Guardrail exceptions**: cases where poco's own code deliberately raises
  an error to prevent misuse of a Python protocol (e.g. `Expr.__bool__`,
  `Expr.__hash__`). These SHALL be raised as a class that subclasses both the
  relevant native Python exception type (so protocol expectations are met)
  and `PocoError` (so the public taxonomy's catch-all promise holds).
  `InvalidExprUsageError` is the first member of this category.

#### Scenario: Guardrail exception satisfies both protocols

- **GIVEN** `hash(Person.age)` is called
- **WHEN** the hashing protocol requires a `TypeError` (or subclass) on
  failure
- **THEN** `InvalidExprUsageError` SHALL be raised, satisfying both the
  native hashing protocol and the `PocoError` taxonomy simultaneously

#### Scenario: Pass-through exceptions remain unaffected

- **GIVEN** an expression divides by a column value of `0`
- **WHEN** materialization evaluates that expression
- **THEN** `ZeroDivisionError` SHALL propagate unchanged, as before this
  change — pass-through exceptions are not guardrail exceptions and are not
  affected by this requirement

## Requirements
