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

#### Scenario: Reduce with transducer re-wraps on each call

- **WHEN** `po.reduce(reducer, collection, transducer=xf)` is called
- **THEN** `reduce` SHALL call `xf(reducer)` to produce a fresh wrapped reducer
- **AND** the wrapped reducer SHALL be used only for this single reduce call
  (no reuse of prior wrapped state)

### Requirement: Reducer laws

Reducers SHALL satisfy the following laws, verified via property-based testing:

1. **Determinism**: `step(s, a)` SHALL always return the same result for same `s` and `a`
2. **Empty input validity**: `complete(init())` SHALL return a valid, well-defined result
3. **Resumability**: reducing `xs ++ ys` SHALL equal resuming the fold of `ys`
   from the accumulated state after `xs` (when no `Reduced` is returned)
4. **Reduced validity**: if `step` returns `Reduced(s)`, `complete(s)` SHALL be valid
5. **Reduced idempotence**: `Reduced(Reduced(s))` SHALL be treated as `Reduced(s)`

#### Scenario: Empty input produces valid result

- **WHEN** `po.reduce(po.count, [])` is called
- **THEN** `complete(init())` SHALL return `0`

#### Scenario: Resumability

- **WHEN** `po.reduce(po.sum_reducer, [1, 2, 3, 4, 5])` is called
- **THEN** the result SHALL equal reducing `[1, 2]` to get intermediate state,
  then reducing `[3, 4, 5]` from that state

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

### Requirement: Transducer-reducer compatibility laws

Transducers wrapping reducers SHALL satisfy the following laws:

1. **Init preservation**: `xf(r).init()` SHALL equal `r.init()` by default
2. **Complete propagation**: `xf(r).complete(s)` SHALL call `r.complete(...)` on some state
3. **Reduced propagation**: if inner `step` returns `Reduced`, outer SHALL propagate it

#### Scenario: Init preserved

- **WHEN** `filtering(pred)` wraps `to_list`
- **THEN** `filtering(pred)(to_list).init()` SHALL equal `to_list.init()`

#### Scenario: Complete propagated

- **WHEN** any transducer wraps a `mean` reducer
- **THEN** `complete` SHALL be called on the inner reducer to finalize the result

### Requirement: Transducer composition is left-to-right

Transducers SHALL compose via the `|` operator in left-to-right data flow
order: `xf1 | xf2` means apply `xf1` first, then `xf2`.

Composition SHALL be associative: `(a | b) | c` equals `a | (b | c)`.

Internally, left-to-right data flow requires right-to-left function composition:
`(xf1 | xf2)(reducer) == xf1(xf2(reducer))`.

#### Scenario: Left-to-right data flow

- **WHEN** `filtering(lambda x: x > 0) | mapping(lambda x: x * 10)` is composed
- **THEN** applying it to `[-1, 2, -3, 4]` with `to_list` SHALL produce `[20, 40]`
  (filter first: `[2, 4]`, then map: `[20, 40]`)

#### Scenario: Non-commutative order matters

- **WHEN** `mapping(lambda x: x - 3) | filtering(lambda x: x > 0)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2]` (map first: `[-2, -1, 0, 1, 2]`, then filter: `[1, 2]`)

#### Scenario: Composition is associative

- **WHEN** transducers `a`, `b`, `c` are composed as `(a | b) | c` and `a | (b | c)`
- **THEN** both SHALL produce identical results for any input

#### Scenario: Cross-layer composition

- **WHEN** a high-level pipeline step (`po.where(Person.age > 25)`) is composed
  with a low-level transducer (`po.mapping(some_fn)`) via `|`
- **THEN** the bare transducer SHALL be lifted into a pipeline step with
  `Identity` schema transform
- **AND** the composition SHALL produce a valid pipeline step with component-wise
  composition of both data and schema parts

### Requirement: Identity transducer

The system SHALL provide an identity transducer that passes through the
inner reducer unchanged. `comp()` with no arguments SHALL return the identity.
The identity transducer SHALL be the neutral element of composition (monoid identity).

#### Scenario: Identity leaves reducer unchanged

- **WHEN** the identity transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL behave identically to `to_list`

#### Scenario: Identity is neutral element

- **WHEN** `identity | xf` and `xf | identity` are composed
- **THEN** both SHALL produce the same results as `xf` alone

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

### Requirement: Built-in reducers

The system SHALL provide the following built-in reducers implementing the
three-arity protocol:
- `to_list` — accumulates items into a list; `complete` returns the list
- `count` — counts items; `complete(init())` returns `0`
- `sum_reducer` — sums numeric items; `complete(init())` returns `0`
- `mean` — computes arithmetic mean; `init` returns `(0, 0)`, `complete`
  divides sum by count; `complete(init())` SHALL raise `ZeroDivisionError`
  or return `float('nan')` (implementation may choose)

#### Scenario: to_list collects all items

- **WHEN** `po.reduce(po.to_list, [1, 2, 3])` is called
- **THEN** the result SHALL be `[1, 2, 3]`

#### Scenario: count on empty input

- **WHEN** `po.reduce(po.count, [])` is called
- **THEN** the result SHALL be `0`

#### Scenario: mean computes average

- **WHEN** `po.reduce(po.mean, [10, 20, 30])` is called
- **THEN** the result SHALL be `20.0`

### Requirement: Stateful transducers SHALL produce fresh closure state per wrapping

Stateful transducers (e.g., `taking(n)`, `dropping(n)`) SHALL manage mutable
state in closure variables captured when the transducer wraps a reducer.
Each call to the transducer (i.e., each wrapping of a new reducer) SHALL
produce fresh, independent state.

#### Scenario: taking produces independent state per wrapping

- **WHEN** `taking(2)` wraps `to_list` twice (two separate calls)
- **THEN** each wrapped reducer SHALL independently track its own count
- **AND** both SHALL take exactly 2 items from their respective inputs

### Requirement: High-level pipeline step constructors (Expr-based)

The system SHALL provide high-level constructors that accept `Expr` objects
(see `expression/spec.md`) and produce pipeline steps. These build on the
low-level transducers and add schema transforms:

- `where(expr)` — data: filtering transducer evaluating Expr per row; schema: Identity
- `select(*exprs)` — data: column dropper; schema: Project(selected columns)

These are the primary user-facing API. The low-level `filtering`, `mapping`,
etc. are also public for advanced use and custom transducer construction.

Pipeline steps built from `Expr` objects SHALL store `required_columns` (the
set of column names referenced by the Expr tree). This enables schema
validation at pipe time (see `pipeline/spec.md`).

#### Scenario: where wraps filtering with Expr evaluation

- **WHEN** `po.where(Person.age > 25)` is applied
- **THEN** it SHALL behave equivalently to `filtering(lambda row: row["age"] > 25)`
  with schema transform `Identity`

#### Scenario: where stores required columns

- **WHEN** `po.where(Person.age > 25)` is created
- **THEN** the pipeline step's `required_columns` SHALL be `{"age"}`

#### Scenario: select produces project schema transform

- **WHEN** `po.select(Person.name, Person.age)` is created
- **THEN** the schema transform SHALL be `Project(["name", "age"])`
