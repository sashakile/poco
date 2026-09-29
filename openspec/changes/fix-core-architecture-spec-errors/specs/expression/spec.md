---
id: spec
kind: intent
statement: "THE system SHALL make Expr equality and protocol misuse explicit so __eq__ builds expressions, boolean and hash contexts raise InvalidExprUsageError, and type inference follows the decision table"
---

# Expr protocol and type inference

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| fe.eq_returns_expr | invariant | `Expr.__eq__` returns a `BinOp(EQ, ...)` expression, never bool; `.equals(other)` provides structural bool comparison; collections like `required_columns` store column-name strings, not Exprs | [[spec]] |
| fe.unhashable_expr | invariant | `Expr.__hash__` is an explicit method raising `InvalidExprUsageError` (not `__hash__ = None`), catchable via both `TypeError` and `PocoError`, with the unhashability guidance message | [[spec]] |
| fe.bool_context | invariant | `Expr.__bool__` raises `InvalidExprUsageError` with the `.equals()`/`po.where()` guidance message in any boolean context | [[spec]] |
| fe.type_inference_table | invariant | Arithmetic and comparison result types follow the decision tables: numeric promotions with bool→int, `str + str` concatenation only, `/` always float, no floor division; invalid combinations raise `SchemaError` at construction | [[spec]] |

## Model

### States

- `expression`
- `compared`
- `misused`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_eq | expression | expression | [[spec.fe.eq_returns_expr]] |
| t_equals | expression | compared | [[spec.fe.eq_returns_expr]] |
| t_hash_misuse | expression | misused | [[spec.fe.unhashable_expr]] |
| t_bool_misuse | expression | misused | [[spec.fe.bool_context]] |
| t_infer | expression | expression | [[spec.fe.type_inference_table]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.eq_returns_expr | unit | [[spec.fe.eq_returns_expr]] | comparison expressions over schema classes | `==` builds BinOp(EQ); `.equals` returns a Python bool |
| p.unhashable_expr | unit | [[spec.fe.unhashable_expr]] | dict-key and set-member usage of Exprs | `InvalidExprUsageError` with guidance, dual-catchable |
| p.bool_context | unit | [[spec.fe.bool_context]] | if/assert usage of Exprs | `InvalidExprUsageError` with the specified message |
| p.type_inference_table | unit | [[spec.fe.type_inference_table]] | every cell of the arithmetic and comparison tables | result types match the table; invalid cells raise `SchemaError` |

## Purpose

Make Expr's deviation from Python object semantics explicit and exhaustive,
so misuse fails with guidance and type inference is a total function.

## MODIFIED Requirements

### Requirement: Expr __eq__ returns Expr, and Expr is explicitly unhashable

`Expr.__eq__` SHALL return a `BinOp(EQ, ...)` expression (not `bool`), enabling
`Person.age == 30` as a query expression. Because `__eq__` does not return a
boolean, `Expr` instances CANNOT be safely used as keys in dictionaries or elements
in sets. Therefore, `Expr.__hash__` SHALL be implemented as an explicit method
that raises `InvalidExprUsageError` (see "Unhashable Expr error includes
guidance"), not via the `__hash__ = None` idiom, so the raised exception
carries poco-specific guidance and is a member of the public exception
taxonomy while still being a `TypeError` subclass.
Any collections (like `required_columns`) MUST store column names (strings),
not `Expr` instances.

A separate `.equals(other)` method SHALL be provided for actual equality
comparison between Expr objects (returns `bool`).

#### Scenario: == builds expression, not bool

- **WHEN** a user writes `Person.age == 30`
- **THEN** the result SHALL be a `BinOp(EQ, ColumnRef("age"), Literal(30))` expression
- **AND** the result SHALL NOT be a `bool`

#### Scenario: Expr is unhashable

- **WHEN** a user attempts to use `Person.age` as a dict key or in a set
- **THEN** the system SHALL raise `InvalidExprUsageError`, catchable via both
  `except TypeError` and `except po.PocoError`

#### Scenario: .equals() for structural comparison

- **WHEN** a user calls `(Person.age > 30).equals(Person.age > 30)`
- **THEN** the result SHALL be `True` (a Python `bool`)

### Requirement: Complete expression type inference decision table

Expression result type inference SHALL cover all supported type combinations.
The following table SHALL define the result type for each operator class.
Combinations marked SchemaError SHALL be rejected at pipeline construction time.

**Arithmetic operators** (`+`, `-`, `*`, `/`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | int | int | float | SchemaError |
| int | int | int | float | SchemaError |
| float | float | float | float | SchemaError |
| str | SchemaError | SchemaError | SchemaError | SchemaError |

Exception: `str + str` → `str` (concatenation). All other str arithmetic →
SchemaError.
Exception: `/` (true division) always returns `float`, even for `int / int`.

Note: `bool` is promoted to `int` for arithmetic (Python semantics:
`True + True → 2`). `str * int` (Python repetition) is NOT supported — use
explicit string operations. Floor division (`//`) is not a supported
operator; only true division (`/`) is defined.

**Comparison operators** (`>`, `<`, `>=`, `<=`, `==`, `!=`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | bool | bool | bool | SchemaError |
| int | bool | bool | bool | SchemaError |
| float | bool | bool | bool | SchemaError |
| str | SchemaError | SchemaError | SchemaError | bool |

Numeric types (`bool`, `int`, `float`) are mutually comparable. `str` is
only comparable to `str`. Cross-family comparisons raise SchemaError.

#### Scenario: Floor division is not a supported operator

- **WHEN** a user writes `Person.age // 2`
- **THEN** the system SHALL raise `TypeError` (Python's native "unsupported
  operand type" error, since `Expr` does not define `__floordiv__`)

### Requirement: Expr raises TypeError in boolean context

`Expr` SHALL define `__bool__` to raise `InvalidExprUsageError` (a subclass
of both `po.PocoError` and Python's `TypeError`). Using an `Expr` in a
boolean context (`if`, `and`, `or`, `not`, `assert`) SHALL raise
`InvalidExprUsageError` with message: "Expr cannot be used as bool. Use
.equals(other) for structural comparison, or po.where(expr) for filtering."

Because `InvalidExprUsageError` is a `TypeError` subclass, code that catches
plain `except TypeError` continues to work unchanged. Code that catches
`except po.PocoError` now also catches this case, per the "Public exception
taxonomy" requirement in `errors/spec.md`.

#### Scenario: Expr used in if statement

- **GIVEN** `Person.age` is an Expr via `@po.schema` descriptor
- **WHEN** developer writes `if Person.age == 30: ...`
- **THEN** `InvalidExprUsageError` is raised: "Expr cannot be used as bool.
  Use .equals(other) for structural comparison, or po.where(expr) for
  filtering."
- **AND** the exception SHALL be catchable via both `except TypeError` and
  `except po.PocoError`

#### Scenario: Expr used in assert

- **GIVEN** `expr = Person.age > 25`
- **WHEN** developer writes `assert expr`
- **THEN** `InvalidExprUsageError` is raised with the same message

### Requirement: Unhashable Expr error includes guidance

The system SHALL treat `Expr` as unhashable in any hash-requiring context
(dict key, set member). `Expr.__hash__` SHALL be implemented as an explicit
method that raises `InvalidExprUsageError` (a subclass of both
`po.PocoError` and Python's `TypeError`) rather than via the `__hash__ =
None` idiom, so that the raised exception carries poco-specific guidance and
remains a member of the public exception taxonomy while still satisfying
Python's expectation that unhashability is signaled via a `TypeError`
subclass.

Message: "Expr is unhashable. Use column name strings as dict keys or set
members instead."

#### Scenario: Expr as dict key

- **GIVEN** `Person.age` is an Expr
- **WHEN** developer writes `{Person.age: "alias"}`
- **THEN** `InvalidExprUsageError` is raised with message: "Expr is
  unhashable. Use column name strings as dict keys or set members instead."
- **AND** the exception SHALL be catchable via both `except TypeError` and
  `except po.PocoError`

#### Scenario: Expr in a set

- **GIVEN** `Person.age` is an Expr
- **WHEN** developer writes `{Person.age, Person.name}` (a set literal)
- **THEN** `InvalidExprUsageError` is raised with the same message

## Requirements

### Requirement: Expr __eq__ returns Expr, and Expr is explicitly unhashable

`Expr.__eq__` SHALL return a `BinOp(EQ, ...)` expression (not `bool`), enabling
`Person.age == 30` as a query expression. Because `__eq__` does not return a
boolean, `Expr` instances CANNOT be safely used as keys in dictionaries or elements
in sets. Therefore, `Expr.__hash__` SHALL be implemented as an explicit method
that raises `InvalidExprUsageError` (see "Unhashable Expr error includes
guidance"), not via the `__hash__ = None` idiom, so the raised exception
carries poco-specific guidance and is a member of the public exception
taxonomy while still being a `TypeError` subclass.
Any collections (like `required_columns`) MUST store column names (strings),
not `Expr` instances.

A separate `.equals(other)` method SHALL be provided for actual equality
comparison between Expr objects (returns `bool`).

#### Scenario: == builds expression, not bool

- **WHEN** a user writes `Person.age == 30`
- **THEN** the result SHALL be a `BinOp(EQ, ColumnRef("age"), Literal(30))` expression
- **AND** the result SHALL NOT be a `bool`

#### Scenario: Expr is unhashable

- **WHEN** a user attempts to use `Person.age` as a dict key or in a set
- **THEN** the system SHALL raise `InvalidExprUsageError`, catchable via both
  `except TypeError` and `except po.PocoError`

#### Scenario: .equals() for structural comparison

- **WHEN** a user calls `(Person.age > 30).equals(Person.age > 30)`
- **THEN** the result SHALL be `True` (a Python `bool`)

### Requirement: Complete expression type inference decision table

Expression result type inference SHALL cover all supported type combinations.
The following table SHALL define the result type for each operator class.
Combinations marked SchemaError SHALL be rejected at pipeline construction time.

**Arithmetic operators** (`+`, `-`, `*`, `/`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | int | int | float | SchemaError |
| int | int | int | float | SchemaError |
| float | float | float | float | SchemaError |
| str | SchemaError | SchemaError | SchemaError | SchemaError |

Exception: `str + str` → `str` (concatenation). All other str arithmetic →
SchemaError.
Exception: `/` (true division) always returns `float`, even for `int / int`.

Note: `bool` is promoted to `int` for arithmetic (Python semantics:
`True + True → 2`). `str * int` (Python repetition) is NOT supported — use
explicit string operations. Floor division (`//`) is not a supported
operator; only true division (`/`) is defined.

**Comparison operators** (`>`, `<`, `>=`, `<=`, `==`, `!=`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | bool | bool | bool | SchemaError |
| int | bool | bool | bool | SchemaError |
| float | bool | bool | bool | SchemaError |
| str | SchemaError | SchemaError | SchemaError | bool |

Numeric types (`bool`, `int`, `float`) are mutually comparable. `str` is
only comparable to `str`. Cross-family comparisons raise SchemaError.

#### Scenario: Floor division is not a supported operator

- **WHEN** a user writes `Person.age // 2`
- **THEN** the system SHALL raise `TypeError` (Python's native "unsupported
  operand type" error, since `Expr` does not define `__floordiv__`)

### Requirement: Expr raises TypeError in boolean context

`Expr` SHALL define `__bool__` to raise `InvalidExprUsageError` (a subclass
of both `po.PocoError` and Python's `TypeError`). Using an `Expr` in a
boolean context (`if`, `and`, `or`, `not`, `assert`) SHALL raise
`InvalidExprUsageError` with message: "Expr cannot be used as bool. Use
.equals(other) for structural comparison, or po.where(expr) for filtering."

Because `InvalidExprUsageError` is a `TypeError` subclass, code that catches
plain `except TypeError` continues to work unchanged. Code that catches
`except po.PocoError` now also catches this case, per the "Public exception
taxonomy" requirement in `errors/spec.md`.

#### Scenario: Expr used in if statement

- **GIVEN** `Person.age` is an Expr via `@po.schema` descriptor
- **WHEN** developer writes `if Person.age == 30: ...`
- **THEN** `InvalidExprUsageError` is raised: "Expr cannot be used as bool.
  Use .equals(other) for structural comparison, or po.where(expr) for
  filtering."
- **AND** the exception SHALL be catchable via both `except TypeError` and
  `except po.PocoError`

#### Scenario: Expr used in assert

- **GIVEN** `expr = Person.age > 25`
- **WHEN** developer writes `assert expr`
- **THEN** `InvalidExprUsageError` is raised with the same message

### Requirement: Unhashable Expr error includes guidance

The system SHALL treat `Expr` as unhashable in any hash-requiring context
(dict key, set member). `Expr.__hash__` SHALL be implemented as an explicit
method that raises `InvalidExprUsageError` (a subclass of both
`po.PocoError` and Python's `TypeError`) rather than via the `__hash__ =
None` idiom, so that the raised exception carries poco-specific guidance and
remains a member of the public exception taxonomy while still satisfying
Python's expectation that unhashability is signaled via a `TypeError`
subclass.

Message: "Expr is unhashable. Use column name strings as dict keys or set
members instead."

#### Scenario: Expr as dict key

- **GIVEN** `Person.age` is an Expr
- **WHEN** developer writes `{Person.age: "alias"}`
- **THEN** `InvalidExprUsageError` is raised with message: "Expr is
  unhashable. Use column name strings as dict keys or set members instead."
- **AND** the exception SHALL be catchable via both `except TypeError` and
  `except po.PocoError`

#### Scenario: Expr in a set

- **GIVEN** `Person.age` is an Expr
- **WHEN** developer writes `{Person.age, Person.name}` (a set literal)
- **THEN** `InvalidExprUsageError` is raised with the same message

## Requirements
