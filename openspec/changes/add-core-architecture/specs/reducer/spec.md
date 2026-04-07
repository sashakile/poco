## ADDED Requirements

### Requirement: Three-phase reducer protocol

The system SHALL define a `Reducer` protocol with three methods:
- `init() -> Acc`
- `step(acc: Acc, item) -> Acc | Reduced[Acc]`
- `complete(acc: Acc) -> Result`

When used in a DataFrame context, the `item` passed to `step` SHALL be a
materialized row matching the shared contract defined in `row-model/spec.md`.

#### Scenario: Reducer with all three phases

- **WHEN** a `mean` reducer is applied to `[10, 20, 30]`
- **THEN** `init()` SHALL return `(0, 0)` and `complete()` SHALL return `20.0`

### Requirement: Generic reduce drives the protocol

`po.reduce(reducer, collection)` SHALL call `init()`, then `step()` for each
item, then `complete()`.

#### Scenario: Reduce drives the protocol

- **WHEN** `po.reduce(reducer, collection)` is called
- **THEN** it SHALL call `init()`, then `step()` for each item, then `complete()`

### Requirement: Reducer laws

Reducers SHALL satisfy the following laws, verified via property-based testing:

1. **Determinism**: `step(s, a)` SHALL always return the same result for the same inputs
2. **Empty input validity**: `complete(init())` SHALL return a valid result for total reducers
3. **Resumability**: reducing `xs ++ ys` SHALL equal resuming on `ys` from the state after `xs`
4. **Reduced validity**: if `step` returns `Reduced(s)`, `complete(s)` SHALL be valid
5. **Reduced idempotence**: `Reduced(Reduced(s))` SHALL be treated as `Reduced(s)`

#### Scenario: Empty input produces valid result

- **WHEN** `po.reduce(po.count, [])` is called
- **THEN** the result SHALL be `0`

#### Scenario: Resumability

- **WHEN** `po.reduce(po.sum_reducer, [1, 2, 3, 4, 5])` is compared with a resumed fold
- **THEN** both SHALL produce the same result

### Requirement: Reduced sentinel for early termination

The system SHALL provide a `Reduced` wrapper type. When `step()` returns
`Reduced(acc)`, `po.reduce` SHALL stop iteration and call `complete()` with the
unwrapped accumulator.

#### Scenario: Early termination via Reduced

- **WHEN** a reducer returns `Reduced(acc)` after processing 2 items
- **THEN** remaining items SHALL NOT be processed

#### Scenario: Reduced flattens on construction

- **WHEN** `Reduced(Reduced(value))` is constructed
- **THEN** it SHALL behave as `Reduced(value)`

### Requirement: Built-in reducers

The system SHALL provide these built-in reducers:
- `to_list`
- `count`
- `sum_reducer`
- `min_reducer`
- `max_reducer`
- `mean`

#### Scenario: to_list collects all items

- **WHEN** `po.reduce(po.to_list, [1, 2, 3])` is called
- **THEN** the result SHALL be `[1, 2, 3]`

#### Scenario: mean computes average

- **WHEN** `po.reduce(po.mean, [10, 20, 30])` is called
- **THEN** the result SHALL be `20.0`

#### Scenario: min_reducer on empty raises error

- **WHEN** `po.reduce(po.min_reducer, [])` is called
- **THEN** the system SHALL raise a `ValueError`
