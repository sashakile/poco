## ADDED Requirements

### Requirement: Transducer as reducer transformer

A transducer SHALL be a callable that transforms one reducer into another.
The transducer SHALL wrap all three phases (init, step, complete) of the
inner reducer as defined in `reducer/spec.md`.

In a DataFrame pipeline, transducers SHALL operate on items that satisfy the
materialized row contract defined in `row-model/spec.md`.

#### Scenario: Filtering transducer

- **WHEN** a `filtering(pred)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL only accumulate items where `pred` is true

#### Scenario: Mapping transducer

- **WHEN** a `mapping(f)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL accumulate `f(item)` for each item

#### Scenario: Reduce with transducer re-wraps on each call

- **WHEN** `po.reduce(reducer, collection, transducer=xf)` is called
- **THEN** `xf(reducer)` SHALL produce a fresh wrapped reducer for that call

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

### Requirement: Stateful transducers SHALL produce fresh closure state per wrapping

Stateful transducers (e.g., `taking(n)`, `dropping(n)`) SHALL manage mutable
state in closure variables captured when the transducer wraps a reducer.
Each call to the transducer (i.e., each wrapping of a new reducer) SHALL
produce fresh, independent state.

#### Scenario: taking produces independent state per wrapping

- **WHEN** `taking(2)` wraps `to_list` twice (two separate calls)
- **THEN** each wrapped reducer SHALL independently track its own count
- **AND** both SHALL take exactly 2 items from their respective inputs
