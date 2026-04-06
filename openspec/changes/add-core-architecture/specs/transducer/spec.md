## ADDED Requirements

### Requirement: Three-phase reducer protocol

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
2. **Empty input validity**: `complete(init())` SHALL return a valid, well-defined
   result for total reducers (count, sum, mean, to_list). Partial reducers
   (min_reducer, max_reducer) MAY raise `ValueError` on empty input when no
   identity element exists.
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

#### Scenario: Reduced flattens on construction

- **WHEN** `Reduced(Reduced(value))` is constructed
- **THEN** it SHALL be equivalent to `Reduced(value)` — the constructor
  SHALL unwrap any inner `Reduced` automatically, enforcing the idempotence
  law at construction rather than requiring callers to handle nesting

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

#### Scenario: Taking with zero returns empty

- **WHEN** `taking(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[]`

#### Scenario: Taking with negative raises error

- **WHEN** `taking(-1)` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Dropping with zero is identity

- **WHEN** `dropping(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[1, 2, 3]`

#### Scenario: Dropping with negative raises error

- **WHEN** `dropping(-1)` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Dropping more than input length

- **WHEN** `dropping(100)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[]`

#### Scenario: Composed stateful transducers

- **WHEN** `taking(3) | taking(5)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2, 3]` (taking(3) emits 3 items,
  taking(5) passes all 3 through)

### Requirement: Built-in reducers

The system SHALL provide the following built-in reducers implementing the
three-phase protocol:
- `to_list` — accumulates items into a list; `complete` returns the list
- `count` — counts items; `complete(init())` returns `0`
- `sum_reducer` — sums numeric items; `complete(init())` returns `0`
- `min_reducer` — tracks minimum value; `complete(init())` SHALL raise
  `ValueError` (partial reducer: no minimum of empty sequence)
- `max_reducer` — tracks maximum value; `complete(init())` SHALL raise
  `ValueError` (partial reducer: no maximum of empty sequence)
- `mean` — computes arithmetic mean; `init` returns `(0, 0)`, `complete`
  divides sum by count; `complete(init())` SHALL return `float('nan')`
  (0/0 is mathematically undefined; NaN satisfies the empty input law)

#### Scenario: to_list collects all items

- **WHEN** `po.reduce(po.to_list, [1, 2, 3])` is called
- **THEN** the result SHALL be `[1, 2, 3]`

#### Scenario: count on empty input

- **WHEN** `po.reduce(po.count, [])` is called
- **THEN** the result SHALL be `0`

#### Scenario: mean computes average

- **WHEN** `po.reduce(po.mean, [10, 20, 30])` is called
- **THEN** the result SHALL be `20.0`

#### Scenario: min_reducer finds minimum

- **WHEN** `po.reduce(po.min_reducer, [3, 1, 4, 1, 5])` is called
- **THEN** the result SHALL be `1`

#### Scenario: max_reducer finds maximum

- **WHEN** `po.reduce(po.max_reducer, [3, 1, 4, 1, 5])` is called
- **THEN** the result SHALL be `5`

#### Scenario: min_reducer on empty raises error

- **WHEN** `po.reduce(po.min_reducer, [])` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: max_reducer on empty raises error

- **WHEN** `po.reduce(po.max_reducer, [])` is called
- **THEN** the system SHALL raise a `ValueError`

### Requirement: Stateful transducers SHALL produce fresh closure state per wrapping

Stateful transducers (e.g., `taking(n)`, `dropping(n)`) SHALL manage mutable
state in closure variables captured when the transducer wraps a reducer.
Each call to the transducer (i.e., each wrapping of a new reducer) SHALL
produce fresh, independent state.

#### Scenario: taking produces independent state per wrapping

- **WHEN** `taking(2)` wraps `to_list` twice (two separate calls)
- **THEN** each wrapped reducer SHALL independently track its own count
- **AND** both SHALL take exactly 2 items from their respective inputs

### Requirement: Column-bound reducers

The system SHALL provide column-bound reducer factories that combine a base
reducer with an `Expr` for column extraction. These create reducers that
extract a column value from each row (via Expr evaluation) before applying
the base reducer.

- `sum_of(expr)` — extract column, sum values
- `mean_of(expr)` — extract column, compute mean
- `min_of(expr)` — extract column, find minimum
- `max_of(expr)` — extract column, find maximum
- `count_of()` — count rows (no column extraction needed)

Column-bound reducers SHALL expose `required_columns` (the set of column
names referenced by the bound Expr).

#### Scenario: sum_of extracts and sums

- **WHEN** `po.reduce(po.sum_of(Person.salary), rows)` is called
  where rows are `[{"name": "Ana", "salary": 50}, {"name": "Luis", "salary": 70}]`
- **THEN** the result SHALL be `120`

#### Scenario: mean_of extracts and averages

- **WHEN** `po.reduce(po.mean_of(Person.age), rows)` is called
  where rows are `[{"name": "Ana", "age": 30}, {"name": "Luis", "age": 20}]`
- **THEN** the result SHALL be `25.0`

#### Scenario: count_of counts rows

- **WHEN** `po.reduce(po.count_of(), rows)` is called with 3 rows
- **THEN** the result SHALL be `3`

#### Scenario: Column-bound reducer stores required columns

- **WHEN** `po.sum_of(Person.salary)` is created
- **THEN** the column-bound reducer SHALL expose `required_columns` as `{"salary"}`
