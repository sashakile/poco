---
id: spec
kind: intent
statement: "THE system SHALL build deferred expression trees from a sealed Expr hierarchy with total type inference, shared-row evaluation, null-handling methods, and IEEE 754 NaN semantics"
---

# Expression model

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| ex.hierarchy | invariant | The sealed Expr hierarchy is ColumnRef, Literal, BinOp, UnaryOp; all construction produces these variants | [[spec]] |
| ex.deferred_construction | invariant | Expressions are built via column descriptors and operator overloading (comparisons, arithmetic, reversed ops, `&`/`\|`/`~`), never strings or lambdas, producing nested BinOp/UnaryOp trees | [[spec]] |
| ex.eq_unhashable | invariant | `__eq__` returns a BinOp(EQ) expression, never bool; Expr is unhashable; `.equals(other)` provides structural bool comparison; collections store column-name strings | [[spec]] |
| ex.evaluation | invariant | Exprs evaluate against the shared materialized row contract | [[spec]] |
| ex.error_semantics | invariant | Missing columns raise `ColumnNotFoundError`; None operands raise `NullValueError` with remedies; Python runtime errors (ZeroDivisionError, TypeError) propagate naturally | [[spec]] |
| ex.null_methods | invariant | `is_null()` returns a bool expression; `fill_null(default)` substitutes for None only in the expression it is applied to, never affecting other operands | [[spec]] |
| ex.required_columns | invariant | `required_columns` is the union of referenced column names; Literal contributes the empty set | [[spec]] |
| ex.type_inference | invariant | Result types follow the arithmetic/comparison/boolean decision tables with bool→int promotion, `str + str` only, `/` always float; Optional is treated as its base type; uninferable combinations raise `SchemaError` at construction | [[spec]] |
| ex.bool_context | invariant | `__bool__` raises TypeError with the `.equals()`/`po.where()` guidance message in any boolean context | [[spec]] |
| ex.no_short_circuit | invariant | `&`/`\|` build AST nodes and both operands are always evaluated at materialization; guarding is via chained where or fill_null | [[spec]] |
| ex.nan_semantics | invariant | NaN is a valid float, not None: IEEE 754 comparisons (only `!=` true), NaN arithmetic yields NaN, is_null is False, fill_null preserves NaN; sort/distinct/groupby treat NaN per their specs | [[spec]] |
| ex.fill_null_locality | invariant | In binary operations each Optional operand is handled independently; filling one side does not suppress `NullValueError` on the other | [[spec]] |

## Model

### States

- `constructed`
- `evaluating`
- `null_encountered`
- `result`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_build | constructed | constructed | [[spec.ex.deferred_construction]] |
| t_evaluate | constructed | evaluating | [[spec.ex.evaluation]] |
| t_raise_null | evaluating | null_encountered | [[spec.ex.error_semantics]] |
| t_fill | null_encountered | result | [[spec.ex.null_methods]] |
| t_nan | evaluating | result | [[spec.ex.nan_semantics]] |
| t_infer | constructed | result | [[spec.ex.type_inference]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.hierarchy | unit | [[spec.ex.hierarchy]] | expressions built via all construction paths | every node is one of the four variants |
| p.deferred_construction | unit | [[spec.ex.deferred_construction]] | operator combinations including reversed and nested forms | trees match the operator semantics; evaluation matches Python arithmetic |
| p.eq_unhashable | unit | [[spec.ex.eq_unhashable]] | equality and dict/set usage | `==` builds EQ trees; hashing raises; `.equals` returns bool |
| p.evaluation | unit | [[spec.ex.evaluation]] | expressions over row dicts | results match the computed values |
| p.error_semantics | unit | [[spec.ex.error_semantics]] | missing columns, None operands, zero division, type mismatches | each failure raises the specified error class and message |
| p.null_methods | unit | [[spec.ex.null_methods]] | is_null/fill_null over None and non-None values | truth tables and substitution semantics hold |
| p.required_columns | unit | [[spec.ex.required_columns]] | expression trees of every shape | required_columns is the correct name union |
| p.type_inference | unit | [[spec.ex.type_inference]] | cells of the arithmetic/comparison/boolean tables with Optional operands | inferred types match the tables; invalid cells raise `SchemaError` |
| p.bool_context | unit | [[spec.ex.bool_context]] | if/assert usage of Exprs | TypeError with the guidance message |
| p.no_short_circuit | unit | [[spec.ex.no_short_circuit]] | guarded operands whose right side raises | both operands evaluate; chained-where guards avoid the error |
| p.nan_semantics | unit | [[spec.ex.nan_semantics]] | NaN operands through comparisons, arithmetic, is_null, fill_null | IEEE 754 results and NaN-is-not-null behavior hold |
| p.fill_null_locality | unit | [[spec.ex.fill_null_locality]] | binary ops with partially filled Optional operands | errors surface for the unfilled side only |

## Purpose

Give filters and derivations a safe, statically typed expression language
whose null, NaN, and error behavior is fully specified.

## ADDED Requirements

### Requirement: Expr type hierarchy

The system SHALL provide a sealed `Expr` type hierarchy with the following
variants:
- `ColumnRef(name, dtype)` — reference to a named column
- `Literal(value)` — a constant value
- `BinOp(op, left, right)` — binary operation (arithmetic, comparison, boolean)
- `UnaryOp(op, operand)` — unary operation (negation)

All expression construction SHALL produce instances of these types.

#### Scenario: Constructors stay within the sealed hierarchy

- **WHEN** a user builds expressions via schema descriptors, literals, and operators
- **THEN** every resulting node SHALL be one of `ColumnRef`, `Literal`, `BinOp`,
  or `UnaryOp`

### Requirement: Expression tree for deferred computation

The system SHALL provide an `Expr` type hierarchy that represents deferred
computations. Expressions SHALL be built via column descriptors and operator
overloading, not via strings or lambdas.

#### Scenario: Column reference

- **WHEN** a user accesses `Person.age` on a `@po.schema` class
- **THEN** it SHALL produce a `ColumnRef` expression with name `"age"` and dtype `int`

#### Scenario: Comparison operators — greater than

- **WHEN** a user writes `Person.age > 30`
- **THEN** it SHALL produce a `BinOp(GT, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — less than

- **WHEN** a user writes `Person.age < 30`
- **THEN** it SHALL produce a `BinOp(LT, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — greater than or equal

- **WHEN** a user writes `Person.age >= 30`
- **THEN** it SHALL produce a `BinOp(GE, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — less than or equal

- **WHEN** a user writes `Person.age <= 30`
- **THEN** it SHALL produce a `BinOp(LE, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — not equal

- **WHEN** a user writes `Person.age != 30`
- **THEN** it SHALL produce a `BinOp(NE, ColumnRef("age"), Literal(30))` expression

#### Scenario: Arithmetic operators

- **WHEN** a user writes `Person.age + 1`
- **THEN** it SHALL produce a `BinOp(ADD, ColumnRef("age"), Literal(1))` expression

#### Scenario: Reverse arithmetic operators

- **WHEN** a user writes `1 + Person.age`
- **THEN** it SHALL produce a `BinOp(ADD, Literal(1), ColumnRef("age"))` expression
- **AND** `__radd__`, `__rsub__`, `__rmul__`, `__rtruediv__` SHALL all be implemented

#### Scenario: Boolean combinators use & and | on Expr

- **WHEN** a user writes `(Person.age > 25) & (Person.age < 50)`
- **THEN** it SHALL produce a `BinOp(AND, BinOp(GT, ...), BinOp(LT, ...))` expression

#### Scenario: Boolean OR on Expr uses |

- **WHEN** a user writes `(Person.age < 18) | (Person.age > 65)`
- **THEN** it SHALL produce a `BinOp(OR, BinOp(LT, ...), BinOp(GT, ...))` expression

#### Scenario: Negation via ~

- **WHEN** a user writes `~(Person.age > 30)`
- **THEN** it SHALL produce a `UnaryOp(NOT, BinOp(GT, ...))` expression

#### Scenario: Deeply nested expressions

- **WHEN** a user writes `((Person.age + 1) * 2 - 3) / 4 > 10`
- **THEN** it SHALL produce the corresponding nested `BinOp` tree
- **AND** evaluation against `{"age": 25}` SHALL return `True`
  (since `((25 + 1) * 2 - 3) / 4 = 12.25 > 10`)

### Requirement: Expr __eq__ returns Expr, and Expr is explicitly unhashable

`Expr.__eq__` SHALL return a `BinOp(EQ, ...)` expression (not `bool`), enabling
`Person.age == 30` as a query expression. Because `__eq__` does not return a
boolean, `Expr` instances CANNOT be safely used as keys in dictionaries or elements
in sets. Therefore, `Expr.__hash__` SHALL be explicitly set to `None`.
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
- **THEN** the system SHALL raise a `TypeError` indicating the object is unhashable

#### Scenario: .equals() for structural comparison

- **WHEN** a user calls `(Person.age > 30).equals(Person.age > 30)`
- **THEN** the result SHALL be `True` (a Python `bool`)

### Requirement: Expression evaluation against a row

The system SHALL evaluate an `Expr` against a materialized row as defined in
`row-model/spec.md` and return the computed result. All expressions SHALL
consume the shared row contract (a `dict[str, object]` mapping column names
to values).

#### Scenario: Evaluate comparison

- **WHEN** `Person.age > 30` is evaluated against `{"name": "Ana", "age": 35}`
- **THEN** the result SHALL be `True`

#### Scenario: Evaluate arithmetic

- **WHEN** `Person.age + 1` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the result SHALL be `31`

### Requirement: Expression errors

The system SHALL raise clear errors when an expression encounters invalid data.
Python runtime errors from operations (e.g., `ZeroDivisionError`, `TypeError`)
SHALL propagate naturally — the system SHALL NOT catch or wrap them.

#### Scenario: Missing column raises error

- **WHEN** `Person.salary > 1000` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the system SHALL raise a `ColumnNotFoundError` with a message naming
  the missing column and listing available columns

#### Scenario: None value raises error on comparison

- **WHEN** `Person.age > 30` is evaluated against `{"name": "Ana", "age": None}`
- **THEN** the system SHALL raise a `NullValueError` indicating which column
  contained None and the expression being evaluated
- **AND** the error message SHALL suggest filtering nulls with `po.where` or
  handling them explicitly with `is_null()` / `fill_null()`

#### Scenario: Division by zero propagates

- **WHEN** `Person.age / Literal(0)` is evaluated against `{"age": 30}`
- **THEN** Python's `ZeroDivisionError` SHALL propagate naturally

#### Scenario: Type mismatch propagates

- **WHEN** `Person.name + Literal(1)` is evaluated against `{"name": "Ana"}`
- **THEN** Python's `TypeError` SHALL propagate naturally

### Requirement: Null-handling expression methods

`Expr` SHALL provide methods for working with null (`None`) values:

- `expr.is_null()` SHALL return a `UnaryOp(IS_NULL, expr)` expression that
  evaluates to `True` when the value is `None`, `False` otherwise.
- `expr.fill_null(default)` SHALL return a `BinOp(FILL_NULL, expr, Literal(default))`
  expression that evaluates to the expression's value when non-None, or
  `default` when the value is `None`.

These methods are available on all `Expr` variants.

#### Scenario: is_null on None value

- **WHEN** `Person.age.is_null()` is evaluated against `{"name": "Ana", "age": None}`
- **THEN** the result SHALL be `True`

#### Scenario: is_null on non-None value

- **WHEN** `Person.age.is_null()` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the result SHALL be `False`

#### Scenario: fill_null replaces None with default

- **WHEN** `Person.age.fill_null(0)` is evaluated against `{"name": "Ana", "age": None}`
- **THEN** the result SHALL be `0`

#### Scenario: fill_null on non-None value is identity

- **WHEN** `Person.age.fill_null(0)` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the result SHALL be `30`

#### Scenario: is_null composes with where for null filtering

- **WHEN** `df | po.where(~Person.age.is_null())`
- **THEN** only rows where `age` is not `None` SHALL be included

#### Scenario: fill_null composes with derive

- **WHEN** `df | po.derive(age_clean=Person.age.fill_null(0))`
- **THEN** the `age_clean` column SHALL have `None` values replaced by `0`

#### Scenario: Negated is_null

- **WHEN** `~Person.age.is_null()` is constructed
- **THEN** it SHALL produce a `UnaryOp(NOT, UnaryOp(IS_NULL, ColumnRef("age")))` expression

#### Scenario: fill_null does not suppress NullValueError in other expressions

- **WHEN** `Person.age > 30` is evaluated against `{"age": None}`
- **THEN** a `NullValueError` SHALL still be raised (fill_null must be applied
  explicitly; it does not change the behavior of other operators)

### Requirement: Expression required_columns

`Expr` SHALL expose a `required_columns` property returning a `set[str]` of
column names referenced by the expression tree.

- `ColumnRef(name, dtype)` → `{name}`
- `Literal(value)` → `set()` (empty)
- `BinOp(op, left, right)` → `left.required_columns | right.required_columns`
- `UnaryOp(op, operand)` → `operand.required_columns`

#### Scenario: Single column reference

- **WHEN** `Person.age.required_columns` is accessed
- **THEN** the result SHALL be `{"age"}`

#### Scenario: Compound expression

- **WHEN** `(Person.age > 25).required_columns` is accessed
- **THEN** the result SHALL be `{"age"}`

#### Scenario: Multi-column expression

- **WHEN** `(Person.age + Person.salary).required_columns` is accessed
- **THEN** the result SHALL be `{"age", "salary"}`

#### Scenario: Literal has no required columns

- **WHEN** `Literal(42).required_columns` is accessed
- **THEN** the result SHALL be `set()` (empty)

### Requirement: Expression result type inference

`Expr` SHALL support result-type inference for use by schema-changing
operations such as `derive`. The following rules SHALL apply for supported
scalar types (`int`, `float`, `str`, `bool`):

For static result-type inference, `Optional[T]` SHALL be treated as `T`.
Nullability does not widen the inferred result type by itself. Runtime
evaluation semantics are unchanged: if an operator receives `None` at runtime
and the expression was not normalized explicitly with `fill_null()` or checked
with `is_null()`, evaluation SHALL raise `NullValueError`.

**Arithmetic operators** (`+`, `-`, `*`, `/`):
- `int op int` → `int` (except `/` which always produces `float`)
- `int op float` or `float op int` → `float`
- `float op float` → `float`
- `str + str` → `str` (concatenation)
- All other combinations → type cannot be inferred; raise `SchemaError`

**Comparison operators** (`>`, `<`, `>=`, `<=`, `==`, `!=`):
- Any supported types → `bool`

**Boolean operators** (`&`, `|`, `~`):
- `bool op bool` → `bool`

**Null-handling**:
- `expr.is_null()` → `bool`
- `expr.fill_null(default)` → same type as `expr` (non-Optional variant)

If result type cannot be statically inferred from the expression tree, the
system SHALL raise a `SchemaError` at pipeline construction time with a
message suggesting explicit type annotation.

#### Scenario: Arithmetic type promotion

- **WHEN** `Person.age + Person.salary` where `age: int` and `salary: float`
- **THEN** the inferred result type SHALL be `float`

#### Scenario: Division always produces float

- **WHEN** `Person.age / Literal(2)` where `age: int`
- **THEN** the inferred result type SHALL be `float`

#### Scenario: Comparison produces bool

- **WHEN** `Person.age > 30` where `age: int`
- **THEN** the inferred result type SHALL be `bool`

#### Scenario: fill_null strips Optional

- **WHEN** `Person.age.fill_null(0)` where `age: int | None`
- **THEN** the inferred result type SHALL be `int`

#### Scenario: Arithmetic inference ignores nullable wrapper

- **WHEN** `Person.age + Literal(1)` where `age: int | None`
- **THEN** the inferred result type SHALL be `int`

#### Scenario: Comparison inference ignores nullable wrapper

- **WHEN** `Person.age > Literal(30)` where `age: int | None`
- **THEN** the inferred result type SHALL be `bool`

### Requirement: Expr raises TypeError in boolean context

Expr SHALL define `__bool__` to raise TypeError. Using an Expr in a boolean
context (`if`, `and`, `or`, `not`, `assert`) SHALL raise TypeError with message:
"Expr cannot be used as bool. Use .equals(other) for structural comparison,
or po.where(expr) for filtering."

#### Scenario: Expr used in if statement

- **GIVEN** `Person.age` is an Expr via `@po.schema` descriptor
- **WHEN** developer writes `if Person.age == 30: ...`
- **THEN** TypeError is raised: "Expr cannot be used as bool. Use .equals(other)
  for structural comparison, or po.where(expr) for filtering."

#### Scenario: Expr used in assert

- **GIVEN** `expr = Person.age > 25`
- **WHEN** developer writes `assert expr`
- **THEN** TypeError is raised with same message

### Requirement: Unhashable Expr error includes guidance

The system SHALL treat Expr as unhashable in any hash-requiring context (dict
key, set member). Python SHALL raise TypeError: "unhashable type".
`Expr.__hash__ = None` SHALL produce this naturally. Documentation and error
 guidance SHALL note: "Expr is unhashable. Use column name strings as dict keys
or set members instead."

#### Scenario: Expr as dict key

- **GIVEN** `Person.age` is an Expr
- **WHEN** developer writes `{Person.age: "alias"}`
- **THEN** TypeError is raised (Python standard unhashable error)

### Requirement: Boolean Expr operators do not short-circuit

Boolean operators `&`, `|`, and `~` on Expr SHALL build AST nodes. Both operands
of `&` and `|` SHALL always be evaluated at materialization time. There SHALL be no
short-circuit evaluation.

This means `(Person.age > 0) & (Person.salary / Person.age > 1000)` will
raise ZeroDivisionError when age is 0, even though the left operand is
False. To guard against this, use nested `where()` steps or `fill_null()`.

#### Scenario: Division by zero despite false guard

- **GIVEN** `row = {"age": 0, "salary": 50000}`
- **WHEN** `(Person.age > 0) & (Person.salary / Person.age > 1000)` is
  evaluated against row
- **THEN** ZeroDivisionError is raised (no short-circuit)

#### Scenario: Safe guard via chained where

- **GIVEN** `row = {"age": 0, "salary": 50000}`
- **WHEN** developer writes
  `df | po.where(Person.age > 0) | po.where(Person.salary / Person.age > 1000)`
- **THEN** the first `where` filters out age=0 rows before the second `where`
  evaluates

### Requirement: NaN behavior in expression evaluation

`float("nan")` SHALL be a valid float column value (not treated as `None`). NaN
SHALL follow IEEE 754 semantics in expression evaluation:

- Comparison: NaN compared to any value (including NaN) returns False,
  except `!=` which returns True
- Arithmetic: any arithmetic involving NaN produces NaN
- `expr.is_null()` on NaN returns False (NaN is not None)
- `expr.fill_null(default)` on NaN returns NaN (NaN is not None)

NaN in specific operations (defined in respective specs):
- `sort_by`: NaN sorts after all non-NaN values (last in ascending, first
  in descending)
- `distinct`: each NaN is treated as unique (NaN != NaN per IEEE 754, no
  deduplication)
- `groupby`: each NaN key forms its own group (NaN != NaN)

#### Scenario: NaN in comparison

- **GIVEN** `row = {"age": float("nan")}`
- **WHEN** `Person.age > 30` is evaluated
- **THEN** result is False (IEEE 754)

#### Scenario: NaN equality

- **GIVEN** `row = {"age": float("nan")}`
- **WHEN** `Person.age == Person.age` is evaluated
- **THEN** result is False (NaN != NaN per IEEE 754)

#### Scenario: NaN is not null

- **GIVEN** `row = {"age": float("nan")}`
- **WHEN** `Person.age.is_null()` is evaluated
- **THEN** result is False

### Requirement: Complete expression type inference decision table

Expression result type inference SHALL cover all supported type combinations.
The following table SHALL define the result type for each operator class.
Combinations marked SchemaError SHALL be rejected at pipeline construction time.

**Arithmetic operators** (`+`, `-`, `*`, `//`):

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
explicit string operations.

**Comparison operators** (`>`, `<`, `>=`, `<=`, `==`, `!=`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | bool | bool | bool | SchemaError |
| int | bool | bool | bool | SchemaError |
| float | bool | bool | bool | SchemaError |
| str | SchemaError | SchemaError | SchemaError | bool |

Numeric types (`bool`, `int`, `float`) are mutually comparable. `str` is
only comparable to `str`. Cross-family comparisons raise SchemaError.

**Boolean operators** (`&`, `|`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | bool | SchemaError | SchemaError | SchemaError |
| int | SchemaError | SchemaError | SchemaError | SchemaError |
| float | SchemaError | SchemaError | SchemaError | SchemaError |
| str | SchemaError | SchemaError | SchemaError | SchemaError |

Boolean operators require both operands to be `bool`. `~` (unary NOT)
requires `bool` operand.

**Nullability**: `Optional[T]` SHALL be treated as `T` for type inference purposes.
Nullability SHALL NOT widen the result type. Each operand with `Optional` type
MUST be independently handled via `fill_null()` or filtered via
`where(expr.is_null())` before use in operations that would raise
`NullValueError`.

#### Scenario: Unsupported type combination raises SchemaError

- **WHEN** a developer constructs an expression combining unsupported type
  families such as `str` and `int` in arithmetic
- **THEN** the system SHALL raise `SchemaError` at pipeline construction time

### Requirement: fill_null applies per-expression in binary operations

In a binary expression with two `Optional` operands, each operand SHALL be
independently handled with `fill_null()`. `fill_null` on one side SHALL NOT
affect the other side.

#### Scenario: Both operands Optional, only one filled

- **GIVEN** `age: int | None`, `salary: int | None`
- **WHEN** `Person.age.fill_null(0) + Person.salary` is evaluated against
  `{"age": None, "salary": None}`
- **THEN** NullValueError is raised for salary (`fill_null` on age does not
  affect salary)

#### Scenario: Both operands filled

- **GIVEN** `age: int | None`, `salary: int | None`
- **WHEN** `Person.age.fill_null(0) + Person.salary.fill_null(0)` is evaluated
  against `{"age": None, "salary": None}`
- **THEN** result is `0` (both filled)

## Requirements

### Requirement: Expr type hierarchy

The system SHALL provide a sealed `Expr` type hierarchy with the following
variants:
- `ColumnRef(name, dtype)` — reference to a named column
- `Literal(value)` — a constant value
- `BinOp(op, left, right)` — binary operation (arithmetic, comparison, boolean)
- `UnaryOp(op, operand)` — unary operation (negation)

All expression construction SHALL produce instances of these types.

#### Scenario: Constructors stay within the sealed hierarchy

- **WHEN** a user builds expressions via schema descriptors, literals, and operators
- **THEN** every resulting node SHALL be one of `ColumnRef`, `Literal`, `BinOp`,
  or `UnaryOp`

### Requirement: Expression tree for deferred computation

The system SHALL provide an `Expr` type hierarchy that represents deferred
computations. Expressions SHALL be built via column descriptors and operator
overloading, not via strings or lambdas.

#### Scenario: Column reference

- **WHEN** a user accesses `Person.age` on a `@po.schema` class
- **THEN** it SHALL produce a `ColumnRef` expression with name `"age"` and dtype `int`

#### Scenario: Comparison operators — greater than

- **WHEN** a user writes `Person.age > 30`
- **THEN** it SHALL produce a `BinOp(GT, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — less than

- **WHEN** a user writes `Person.age < 30`
- **THEN** it SHALL produce a `BinOp(LT, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — greater than or equal

- **WHEN** a user writes `Person.age >= 30`
- **THEN** it SHALL produce a `BinOp(GE, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — less than or equal

- **WHEN** a user writes `Person.age <= 30`
- **THEN** it SHALL produce a `BinOp(LE, ColumnRef("age"), Literal(30))` expression

#### Scenario: Comparison operators — not equal

- **WHEN** a user writes `Person.age != 30`
- **THEN** it SHALL produce a `BinOp(NE, ColumnRef("age"), Literal(30))` expression

#### Scenario: Arithmetic operators

- **WHEN** a user writes `Person.age + 1`
- **THEN** it SHALL produce a `BinOp(ADD, ColumnRef("age"), Literal(1))` expression

#### Scenario: Reverse arithmetic operators

- **WHEN** a user writes `1 + Person.age`
- **THEN** it SHALL produce a `BinOp(ADD, Literal(1), ColumnRef("age"))` expression
- **AND** `__radd__`, `__rsub__`, `__rmul__`, `__rtruediv__` SHALL all be implemented

#### Scenario: Boolean combinators use & and | on Expr

- **WHEN** a user writes `(Person.age > 25) & (Person.age < 50)`
- **THEN** it SHALL produce a `BinOp(AND, BinOp(GT, ...), BinOp(LT, ...))` expression

#### Scenario: Boolean OR on Expr uses |

- **WHEN** a user writes `(Person.age < 18) | (Person.age > 65)`
- **THEN** it SHALL produce a `BinOp(OR, BinOp(LT, ...), BinOp(GT, ...))` expression

#### Scenario: Negation via ~

- **WHEN** a user writes `~(Person.age > 30)`
- **THEN** it SHALL produce a `UnaryOp(NOT, BinOp(GT, ...))` expression

#### Scenario: Deeply nested expressions

- **WHEN** a user writes `((Person.age + 1) * 2 - 3) / 4 > 10`
- **THEN** it SHALL produce the corresponding nested `BinOp` tree
- **AND** evaluation against `{"age": 25}` SHALL return `True`
  (since `((25 + 1) * 2 - 3) / 4 = 12.25 > 10`)

### Requirement: Expr __eq__ returns Expr, and Expr is explicitly unhashable

`Expr.__eq__` SHALL return a `BinOp(EQ, ...)` expression (not `bool`), enabling
`Person.age == 30` as a query expression. Because `__eq__` does not return a
boolean, `Expr` instances CANNOT be safely used as keys in dictionaries or elements
in sets. Therefore, `Expr.__hash__` SHALL be explicitly set to `None`.
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
- **THEN** the system SHALL raise a `TypeError` indicating the object is unhashable

#### Scenario: .equals() for structural comparison

- **WHEN** a user calls `(Person.age > 30).equals(Person.age > 30)`
- **THEN** the result SHALL be `True` (a Python `bool`)

### Requirement: Expression evaluation against a row

The system SHALL evaluate an `Expr` against a materialized row as defined in
`row-model/spec.md` and return the computed result. All expressions SHALL
consume the shared row contract (a `dict[str, object]` mapping column names
to values).

#### Scenario: Evaluate comparison

- **WHEN** `Person.age > 30` is evaluated against `{"name": "Ana", "age": 35}`
- **THEN** the result SHALL be `True`

#### Scenario: Evaluate arithmetic

- **WHEN** `Person.age + 1` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the result SHALL be `31`

### Requirement: Expression errors

The system SHALL raise clear errors when an expression encounters invalid data.
Python runtime errors from operations (e.g., `ZeroDivisionError`, `TypeError`)
SHALL propagate naturally — the system SHALL NOT catch or wrap them.

#### Scenario: Missing column raises error

- **WHEN** `Person.salary > 1000` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the system SHALL raise a `ColumnNotFoundError` with a message naming
  the missing column and listing available columns

#### Scenario: None value raises error on comparison

- **WHEN** `Person.age > 30` is evaluated against `{"name": "Ana", "age": None}`
- **THEN** the system SHALL raise a `NullValueError` indicating which column
  contained None and the expression being evaluated
- **AND** the error message SHALL suggest filtering nulls with `po.where` or
  handling them explicitly with `is_null()` / `fill_null()`

#### Scenario: Division by zero propagates

- **WHEN** `Person.age / Literal(0)` is evaluated against `{"age": 30}`
- **THEN** Python's `ZeroDivisionError` SHALL propagate naturally

#### Scenario: Type mismatch propagates

- **WHEN** `Person.name + Literal(1)` is evaluated against `{"name": "Ana"}`
- **THEN** Python's `TypeError` SHALL propagate naturally

### Requirement: Null-handling expression methods

`Expr` SHALL provide methods for working with null (`None`) values:

- `expr.is_null()` SHALL return a `UnaryOp(IS_NULL, expr)` expression that
  evaluates to `True` when the value is `None`, `False` otherwise.
- `expr.fill_null(default)` SHALL return a `BinOp(FILL_NULL, expr, Literal(default))`
  expression that evaluates to the expression's value when non-None, or
  `default` when the value is `None`.

These methods are available on all `Expr` variants.

#### Scenario: is_null on None value

- **WHEN** `Person.age.is_null()` is evaluated against `{"name": "Ana", "age": None}`
- **THEN** the result SHALL be `True`

#### Scenario: is_null on non-None value

- **WHEN** `Person.age.is_null()` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the result SHALL be `False`

#### Scenario: fill_null replaces None with default

- **WHEN** `Person.age.fill_null(0)` is evaluated against `{"name": "Ana", "age": None}`
- **THEN** the result SHALL be `0`

#### Scenario: fill_null on non-None value is identity

- **WHEN** `Person.age.fill_null(0)` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the result SHALL be `30`

#### Scenario: is_null composes with where for null filtering

- **WHEN** `df | po.where(~Person.age.is_null())`
- **THEN** only rows where `age` is not `None` SHALL be included

#### Scenario: fill_null composes with derive

- **WHEN** `df | po.derive(age_clean=Person.age.fill_null(0))`
- **THEN** the `age_clean` column SHALL have `None` values replaced by `0`

#### Scenario: Negated is_null

- **WHEN** `~Person.age.is_null()` is constructed
- **THEN** it SHALL produce a `UnaryOp(NOT, UnaryOp(IS_NULL, ColumnRef("age")))` expression

#### Scenario: fill_null does not suppress NullValueError in other expressions

- **WHEN** `Person.age > 30` is evaluated against `{"age": None}`
- **THEN** a `NullValueError` SHALL still be raised (fill_null must be applied
  explicitly; it does not change the behavior of other operators)

### Requirement: Expression required_columns

`Expr` SHALL expose a `required_columns` property returning a `set[str]` of
column names referenced by the expression tree.

- `ColumnRef(name, dtype)` → `{name}`
- `Literal(value)` → `set()` (empty)
- `BinOp(op, left, right)` → `left.required_columns | right.required_columns`
- `UnaryOp(op, operand)` → `operand.required_columns`

#### Scenario: Single column reference

- **WHEN** `Person.age.required_columns` is accessed
- **THEN** the result SHALL be `{"age"}`

#### Scenario: Compound expression

- **WHEN** `(Person.age > 25).required_columns` is accessed
- **THEN** the result SHALL be `{"age"}`

#### Scenario: Multi-column expression

- **WHEN** `(Person.age + Person.salary).required_columns` is accessed
- **THEN** the result SHALL be `{"age", "salary"}`

#### Scenario: Literal has no required columns

- **WHEN** `Literal(42).required_columns` is accessed
- **THEN** the result SHALL be `set()` (empty)

### Requirement: Expression result type inference

`Expr` SHALL support result-type inference for use by schema-changing
operations such as `derive`. The following rules SHALL apply for supported
scalar types (`int`, `float`, `str`, `bool`):

For static result-type inference, `Optional[T]` SHALL be treated as `T`.
Nullability does not widen the inferred result type by itself. Runtime
evaluation semantics are unchanged: if an operator receives `None` at runtime
and the expression was not normalized explicitly with `fill_null()` or checked
with `is_null()`, evaluation SHALL raise `NullValueError`.

**Arithmetic operators** (`+`, `-`, `*`, `/`):
- `int op int` → `int` (except `/` which always produces `float`)
- `int op float` or `float op int` → `float`
- `float op float` → `float`
- `str + str` → `str` (concatenation)
- All other combinations → type cannot be inferred; raise `SchemaError`

**Comparison operators** (`>`, `<`, `>=`, `<=`, `==`, `!=`):
- Any supported types → `bool`

**Boolean operators** (`&`, `|`, `~`):
- `bool op bool` → `bool`

**Null-handling**:
- `expr.is_null()` → `bool`
- `expr.fill_null(default)` → same type as `expr` (non-Optional variant)

If result type cannot be statically inferred from the expression tree, the
system SHALL raise a `SchemaError` at pipeline construction time with a
message suggesting explicit type annotation.

#### Scenario: Arithmetic type promotion

- **WHEN** `Person.age + Person.salary` where `age: int` and `salary: float`
- **THEN** the inferred result type SHALL be `float`

#### Scenario: Division always produces float

- **WHEN** `Person.age / Literal(2)` where `age: int`
- **THEN** the inferred result type SHALL be `float`

#### Scenario: Comparison produces bool

- **WHEN** `Person.age > 30` where `age: int`
- **THEN** the inferred result type SHALL be `bool`

#### Scenario: fill_null strips Optional

- **WHEN** `Person.age.fill_null(0)` where `age: int | None`
- **THEN** the inferred result type SHALL be `int`

#### Scenario: Arithmetic inference ignores nullable wrapper

- **WHEN** `Person.age + Literal(1)` where `age: int | None`
- **THEN** the inferred result type SHALL be `int`

#### Scenario: Comparison inference ignores nullable wrapper

- **WHEN** `Person.age > Literal(30)` where `age: int | None`
- **THEN** the inferred result type SHALL be `bool`

### Requirement: Expr raises TypeError in boolean context

Expr SHALL define `__bool__` to raise TypeError. Using an Expr in a boolean
context (`if`, `and`, `or`, `not`, `assert`) SHALL raise TypeError with message:
"Expr cannot be used as bool. Use .equals(other) for structural comparison,
or po.where(expr) for filtering."

#### Scenario: Expr used in if statement

- **GIVEN** `Person.age` is an Expr via `@po.schema` descriptor
- **WHEN** developer writes `if Person.age == 30: ...`
- **THEN** TypeError is raised: "Expr cannot be used as bool. Use .equals(other)
  for structural comparison, or po.where(expr) for filtering."

#### Scenario: Expr used in assert

- **GIVEN** `expr = Person.age > 25`
- **WHEN** developer writes `assert expr`
- **THEN** TypeError is raised with same message

### Requirement: Unhashable Expr error includes guidance

The system SHALL treat Expr as unhashable in any hash-requiring context (dict
key, set member). Python SHALL raise TypeError: "unhashable type".
`Expr.__hash__ = None` SHALL produce this naturally. Documentation and error
 guidance SHALL note: "Expr is unhashable. Use column name strings as dict keys
or set members instead."

#### Scenario: Expr as dict key

- **GIVEN** `Person.age` is an Expr
- **WHEN** developer writes `{Person.age: "alias"}`
- **THEN** TypeError is raised (Python standard unhashable error)

### Requirement: Boolean Expr operators do not short-circuit

Boolean operators `&`, `|`, and `~` on Expr SHALL build AST nodes. Both operands
of `&` and `|` SHALL always be evaluated at materialization time. There SHALL be no
short-circuit evaluation.

This means `(Person.age > 0) & (Person.salary / Person.age > 1000)` will
raise ZeroDivisionError when age is 0, even though the left operand is
False. To guard against this, use nested `where()` steps or `fill_null()`.

#### Scenario: Division by zero despite false guard

- **GIVEN** `row = {"age": 0, "salary": 50000}`
- **WHEN** `(Person.age > 0) & (Person.salary / Person.age > 1000)` is
  evaluated against row
- **THEN** ZeroDivisionError is raised (no short-circuit)

#### Scenario: Safe guard via chained where

- **GIVEN** `row = {"age": 0, "salary": 50000}`
- **WHEN** developer writes
  `df | po.where(Person.age > 0) | po.where(Person.salary / Person.age > 1000)`
- **THEN** the first `where` filters out age=0 rows before the second `where`
  evaluates

### Requirement: NaN behavior in expression evaluation

`float("nan")` SHALL be a valid float column value (not treated as `None`). NaN
SHALL follow IEEE 754 semantics in expression evaluation:

- Comparison: NaN compared to any value (including NaN) returns False,
  except `!=` which returns True
- Arithmetic: any arithmetic involving NaN produces NaN
- `expr.is_null()` on NaN returns False (NaN is not None)
- `expr.fill_null(default)` on NaN returns NaN (NaN is not None)

NaN in specific operations (defined in respective specs):
- `sort_by`: NaN sorts after all non-NaN values (last in ascending, first
  in descending)
- `distinct`: each NaN is treated as unique (NaN != NaN per IEEE 754, no
  deduplication)
- `groupby`: each NaN key forms its own group (NaN != NaN)

#### Scenario: NaN in comparison

- **GIVEN** `row = {"age": float("nan")}`
- **WHEN** `Person.age > 30` is evaluated
- **THEN** result is False (IEEE 754)

#### Scenario: NaN equality

- **GIVEN** `row = {"age": float("nan")}`
- **WHEN** `Person.age == Person.age` is evaluated
- **THEN** result is False (NaN != NaN per IEEE 754)

#### Scenario: NaN is not null

- **GIVEN** `row = {"age": float("nan")}`
- **WHEN** `Person.age.is_null()` is evaluated
- **THEN** result is False

### Requirement: Complete expression type inference decision table

Expression result type inference SHALL cover all supported type combinations.
The following table SHALL define the result type for each operator class.
Combinations marked SchemaError SHALL be rejected at pipeline construction time.

**Arithmetic operators** (`+`, `-`, `*`, `//`):

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
explicit string operations.

**Comparison operators** (`>`, `<`, `>=`, `<=`, `==`, `!=`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | bool | bool | bool | SchemaError |
| int | bool | bool | bool | SchemaError |
| float | bool | bool | bool | SchemaError |
| str | SchemaError | SchemaError | SchemaError | bool |

Numeric types (`bool`, `int`, `float`) are mutually comparable. `str` is
only comparable to `str`. Cross-family comparisons raise SchemaError.

**Boolean operators** (`&`, `|`):

| Left \\ Right | bool | int | float | str |
|---|---|---|---|---|
| bool | bool | SchemaError | SchemaError | SchemaError |
| int | SchemaError | SchemaError | SchemaError | SchemaError |
| float | SchemaError | SchemaError | SchemaError | SchemaError |
| str | SchemaError | SchemaError | SchemaError | SchemaError |

Boolean operators require both operands to be `bool`. `~` (unary NOT)
requires `bool` operand.

**Nullability**: `Optional[T]` SHALL be treated as `T` for type inference purposes.
Nullability SHALL NOT widen the result type. Each operand with `Optional` type
MUST be independently handled via `fill_null()` or filtered via
`where(expr.is_null())` before use in operations that would raise
`NullValueError`.

#### Scenario: Unsupported type combination raises SchemaError

- **WHEN** a developer constructs an expression combining unsupported type
  families such as `str` and `int` in arithmetic
- **THEN** the system SHALL raise `SchemaError` at pipeline construction time

### Requirement: fill_null applies per-expression in binary operations

In a binary expression with two `Optional` operands, each operand SHALL be
independently handled with `fill_null()`. `fill_null` on one side SHALL NOT
affect the other side.

#### Scenario: Both operands Optional, only one filled

- **GIVEN** `age: int | None`, `salary: int | None`
- **WHEN** `Person.age.fill_null(0) + Person.salary` is evaluated against
  `{"age": None, "salary": None}`
- **THEN** NullValueError is raised for salary (`fill_null` on age does not
  affect salary)

#### Scenario: Both operands filled

- **GIVEN** `age: int | None`, `salary: int | None`
- **WHEN** `Person.age.fill_null(0) + Person.salary.fill_null(0)` is evaluated
  against `{"age": None, "salary": None}`
- **THEN** result is `0` (both filled)

## Requirements
