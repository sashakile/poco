## ADDED Requirements

### Requirement: Three-arity reducer protocol

The system SHALL define a `Reducer` protocol with three methods:
- `init() -> Acc` — produce initial accumulator
- `step(acc: Acc, item) -> Acc | Reduced[Acc]` — incorporate one item into accumulator
- `complete(acc: Acc) -> Result` — finalize the accumulated result

#### Scenario: Reducer with all three phases

- **WHEN** a `mean` reducer is applied to `[10, 20, 30]`
- **THEN** `init()` SHALL return `(0, 0)` (sum, count), `step` SHALL accumulate, and `complete` SHALL return `20.0`

#### Scenario: Reduce drives the protocol

- **WHEN** `po.reduce(reducer, collection)` is called
- **THEN** it SHALL call `init()`, then `step()` for each item, then `complete()`

### Requirement: Reduced sentinel for early termination

The system SHALL provide a `Reduced` wrapper type. When `step()` returns
`Reduced(acc)`, the `reduce` driver SHALL stop iteration immediately and
proceed to `complete()` with the unwrapped accumulator.

#### Scenario: Early termination via Reduced

- **WHEN** a reducer's `step` returns `Reduced(acc)` after processing 2 items
- **THEN** `reduce` SHALL NOT call `step` on remaining items
- **AND** `complete` SHALL be called with the unwrapped accumulator

#### Scenario: Reduced propagates through transducers

- **WHEN** a `taking(n)` transducer wraps a reducer and n items have been taken
- **THEN** the transducer's `step` SHALL return `Reduced(acc)`
- **AND** the outer `reduce` loop SHALL terminate

### Requirement: Transducer as reducer transformer

A transducer SHALL be a callable that transforms one reducer into another.
The transducer SHALL wrap all three phases (init, step, complete) of the
inner reducer.

#### Scenario: Filtering transducer

- **WHEN** a `filtering(pred)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL only accumulate items where `pred` is true

#### Scenario: Mapping transducer

- **WHEN** a `mapping(f)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL accumulate `f(item)` for each item

### Requirement: Transducer composition

Transducers SHALL compose via the `|` operator or a `comp` function.
Composition SHALL be associative: `(a | b) | c` equals `a | (b | c)`.

#### Scenario: Compose filter and map

- **WHEN** `filtering(is_positive) | mapping(double)` is composed
- **THEN** applying it to `[-1, 2, -3, 4]` with `to_list` SHALL produce `[4, 8]`

#### Scenario: Composition is associative

- **WHEN** transducers `a`, `b`, `c` are composed as `(a | b) | c` and `a | (b | c)`
- **THEN** both SHALL produce identical results for any input

#### Scenario: Cross-layer composition

- **WHEN** a high-level transducer (`po.where(Person.age > 25)`) is composed
  with a low-level transducer (`po.mapping(some_fn)`) via `|`
- **THEN** the composition SHALL produce a valid transducer, because both
  implement the same `Transducer` protocol (reducer -> reducer)

### Requirement: Identity transducer

The system SHALL provide an identity transducer that passes through the
inner reducer unchanged. `comp()` with no arguments SHALL return the identity
transducer. The identity transducer SHALL be the neutral element of
transducer composition (monoid identity).

#### Scenario: Identity leaves reducer unchanged

- **WHEN** the identity transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL behave identically to `to_list`

#### Scenario: comp() with no args returns identity

- **WHEN** `po.comp()` is called with no arguments
- **THEN** it SHALL return the identity transducer

### Requirement: Core transducers (low-level)

The system SHALL provide the following built-in transducers that work with
plain Python callables. These are the low-level building blocks:
- `filtering(predicate)` — keep items where predicate is true
- `mapping(function)` — transform each item
- `taking(n)` — take first n items (early termination via Reduced)
- `dropping(n)` — skip first n items

#### Scenario: Taking with early termination

- **WHEN** `taking(2)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2]` and items 3-5 SHALL NOT be processed

#### Scenario: Dropping skips items

- **WHEN** `dropping(2)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[3, 4, 5]`

### Requirement: High-level transducer constructors (Expr-based)

The system SHALL provide high-level transducer constructors that accept `Expr`
objects (see `expression/spec.md`) and produce transducers. These build on
the low-level transducers:
- `where(expr)` — builds a `filtering` transducer that evaluates the Expr per row
- `select(*exprs)` — builds a project operation from column reference Exprs

These are the primary user-facing API. The low-level `filtering`, `mapping`,
etc. are also public for advanced use and custom transducer construction.

Transducers built from `Expr` objects SHALL store `required_columns` (the set
of column names referenced by the Expr tree). This enables schema validation
at pipe time (see `pipeline/spec.md`).

#### Scenario: where wraps filtering with Expr evaluation

- **WHEN** `po.where(Person.age > 25)` is applied
- **THEN** it SHALL behave equivalently to `filtering(lambda row: row["age"] > 25)`

#### Scenario: where stores required columns

- **WHEN** `po.where(Person.age > 25)` is created
- **THEN** the transducer's `required_columns` SHALL be `{"age"}`
