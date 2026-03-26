## ADDED Requirements

### Requirement: Expression tree for deferred computation

The system SHALL provide an `Expr` type hierarchy that represents deferred
computations. Expressions SHALL be built via column descriptors and operator
overloading, not via strings or lambdas.

#### Scenario: Column reference

- **WHEN** a user accesses `Person.age` on a `@po.schema` class
- **THEN** it SHALL produce a `ColumnRef` expression with name `"age"` and dtype `int`

#### Scenario: Comparison operators

- **WHEN** a user writes `Person.age > 30`
- **THEN** it SHALL produce a `BinOp(GT, ColumnRef("age"), Literal(30))` expression

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

### Requirement: Expr __eq__ returns Expr, with safe hashing

`Expr.__eq__` SHALL return a `BinOp(EQ, ...)` expression (not `bool`), enabling
`Person.age == 30` as a query expression. To preserve Python dict/set behavior,
`Expr.__hash__` SHALL be implemented based on column name and dtype (for
`ColumnRef`) or structural identity (for compound expressions).

A separate `.equals(other)` method SHALL be provided for actual equality
comparison between Expr objects (returns `bool`).

#### Scenario: == builds expression, not bool

- **WHEN** a user writes `Person.age == 30`
- **THEN** the result SHALL be a `BinOp(EQ, ColumnRef("age"), Literal(30))` expression
- **AND** the result SHALL NOT be a `bool`

#### Scenario: Expr is hashable

- **WHEN** a user uses `Person.age` as a dict key or in a set
- **THEN** it SHALL work correctly via `__hash__`
- **AND** two `ColumnRef("age", int)` instances SHALL have the same hash

#### Scenario: .equals() for structural comparison

- **WHEN** a user calls `(Person.age > 30).equals(Person.age > 30)`
- **THEN** the result SHALL be `True` (a Python `bool`)

### Requirement: Expression evaluation against a row

The system SHALL evaluate an `Expr` against a row (dict-like mapping of column
names to values, as defined in `dataframe/spec.md`) and return the computed result.

#### Scenario: Evaluate comparison

- **WHEN** `Person.age > 30` is evaluated against `{"name": "Ana", "age": 35}`
- **THEN** the result SHALL be `True`

#### Scenario: Evaluate arithmetic

- **WHEN** `Person.age + 1` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the result SHALL be `31`

### Requirement: Strict expression errors

The system SHALL raise clear errors when an expression encounters invalid data.

#### Scenario: Missing column raises error

- **WHEN** `Person.salary > 1000` is evaluated against `{"name": "Ana", "age": 30}`
- **THEN** the system SHALL raise a `ColumnNotFoundError` with a message naming
  the missing column and listing available columns

#### Scenario: None value raises error on comparison

- **WHEN** `Person.age > 30` is evaluated against `{"name": "Ana", "age": None}`
- **THEN** the system SHALL raise a `NullValueError` indicating which column
  contained None and in which row
- **AND** the error message SHALL suggest filtering nulls with `po.where` or
  declaring the column as nullable in the schema
