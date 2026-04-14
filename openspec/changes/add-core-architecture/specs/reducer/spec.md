## ADDED Requirements

### Requirement: Three-phase reducer protocol

The system SHALL define a `Reducer` protocol with three methods:
- `init() -> Acc`
- `step(acc: Acc, item) -> Acc | Reduced[Acc]`
- `complete(acc: Acc) -> Result`

**Formal Pre/Postconditions:**
- `init()`:
  - Pre: None.
  - Post: Returns a valid initial accumulator `Acc`.
- `step(acc, item)`:
  - Pre: `acc` must be a valid `Acc` produced by `init` or a previous `step`. `item` must satisfy the row contract.
  - Post: Returns a valid `Acc` or a `Reduced[Acc]` signaling early termination.
- `complete(acc)`:
  - Pre: `acc` must be a valid `Acc` (unwrapped if from `Reduced`).
  - Post: Returns the final `Result`.

**Termination Invariant:**
- The system SHALL guarantee that `complete(acc)` is called exactly once for every reduction, regardless of whether termination occurred via end-of-stream or the `Reduced` protocol. If `step` returns `Reduced(acc)`, the `acc` SHALL be unwrapped and passed immediately to `complete`.

#### Scenario: Reducer with all three phases
...
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

#### Scenario: max_reducer on empty raises error

- **WHEN** `po.reduce(po.max_reducer, [])` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: mean on empty raises error

- **WHEN** `po.reduce(po.mean, [])` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: sum_reducer on empty returns zero

- **WHEN** `po.reduce(po.sum_reducer, [])` is called
- **THEN** the result SHALL be `0`

#### Scenario: count on empty returns zero

- **WHEN** `po.reduce(po.count, [])` is called
- **THEN** the result SHALL be `0`

#### Scenario: to_list on empty returns empty list

- **WHEN** `po.reduce(po.to_list, [])` is called
- **THEN** the result SHALL be `[]`

### Requirement: Reducer protocol state machine and violation behavior

The reducer protocol defines an implicit state machine with three states:

```
Uninitialized ──init()──► Stepping ──step()──► Stepping
                                   ──Reduced──► Terminated
                          Stepping ──complete()──► Completed
                          Terminated ──complete()──► Completed
```

State transition violations:
- Calling step() before init(): undefined behavior (implementors may assume init() was called)
- Calling step() after complete(): undefined behavior
- Calling complete() more than once: undefined behavior
- Calling init() after stepping has begun: undefined behavior

The `po.reduce()` driver guarantees correct protocol sequencing: exactly one init(), zero or more step() calls, exactly one complete(). Transducer wrappers MUST preserve this sequencing for the inner reducer.

Note: poco does not enforce state machine transitions at runtime (no ProtocolError). Correct sequencing is the responsibility of po.reduce() and transducer implementations. This is a design contract, not a runtime guard.

#### Scenario: po.reduce guarantees correct sequencing

- **WHEN** any valid reducer r and any iterable xs are given
- **THEN** `po.reduce(r, xs)` SHALL call init() exactly once, step() for each item (or until Reduced), and complete() exactly once

#### Scenario: complete called after Reduced

- **WHEN** step() returns Reduced(acc) on the third item
- **THEN** step() SHALL NOT be called for subsequent items, and complete(unwrapped_acc) SHALL be called exactly once

### Requirement: Built-in reducer empty-input behavior

Each built-in reducer has defined behavior on empty input (complete(init())):

| Reducer | Empty Input Result | Classification |
|---|---|---|
| to_list | [] | Total (always valid) |
| count | 0 | Total |
| sum_reducer | 0 | Total |
| mean | ValueError: "mean of empty sequence" | Partial (requires ≥1 item) |
| min_reducer | ValueError: "min of empty sequence" | Partial (requires ≥1 item) |
| max_reducer | ValueError: "max of empty sequence" | Partial (requires ≥1 item) |

This behavior is preserved regardless of how the empty input arises: empty DataFrame, filtering that removes all rows, head(0), or empty list.

#### Scenario: mean on filtered-to-empty DataFrame

- **WHEN** df has rows but `po.where(always_false_expr)` removes all
- **THEN** `po.reduce(po.mean, df | po.where(always_false))` SHALL raise ValueError: "mean of empty sequence"

#### Scenario: count on empty DataFrame

- **WHEN** `po.reduce(po.count, po.DataFrame([]))` is called
- **THEN** the result SHALL be `0`

#### Scenario: sum_reducer on head(0)

- **WHEN** df has rows and `po.reduce(po.sum_reducer, df.head(0))` is called
- **THEN** the result SHALL be `0`
