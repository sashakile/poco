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
