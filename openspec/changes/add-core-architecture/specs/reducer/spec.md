---
id: spec
kind: intent
statement: "THE system SHALL define a three-phase Reducer protocol driven by po.reduce with Reduced early termination, law-compliant semantics, and defined empty-input behavior per built-in reducer"
---

# Reducer protocol

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| cr.three_phase | invariant | The Reducer protocol defines `init`, `step`, and `complete` with the specified pre/postconditions; `complete` is called exactly once per reduction, unwrapping `Reduced` immediately | [[spec]] |
| cr.reduce_driver | invariant | `po.reduce(reducer, collection)` calls init once, step per item, complete once | [[spec]] |
| cr.laws | invariant | Reducers satisfy determinism, empty-input validity for total reducers, resumability (`reduce(xs ++ ys) == resume(ys, state(xs))`), Reduced validity, and Reduced idempotence — verified by property tests | [[spec]] |
| cr.reduced_sentinel | invariant | `Reduced(acc)` from step stops iteration and completes with the unwrapped accumulator; `Reduced(Reduced(v))` flattens on construction | [[spec]] |
| cr.builtins | invariant | Built-in reducers are `to_list`, `count`, `sum_reducer`, `min_reducer`, `max_reducer`, `mean` | [[spec]] |
| cr.empty_input_table | invariant | Empty-input behavior per the table: to_list/count/sum_reducer are total; mean/min_reducer/max_reducer raise `ValueError`; behavior holds however emptiness arises | [[spec]] |
| cr.state_machine | invariant | The protocol state machine (Uninitialized→Stepping→Terminated/Completed) is a design contract enforced by the driver and transducer wrappers, not runtime guards; violations are undefined behavior | [[spec]] |

## Model

### States

- `uninitialized`
- `stepping`
- `terminated`
- `completed`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_init | uninitialized | stepping | [[spec.cr.reduce_driver]] |
| t_step | stepping | stepping | [[spec.cr.laws]] |
| t_reduce_early | stepping | terminated | [[spec.cr.reduced_sentinel]] |
| t_complete | stepping | completed | [[spec.cr.three_phase]] |
| t_complete_terminated | terminated | completed | [[spec.cr.three_phase]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.three_phase | unit | [[spec.cr.three_phase]] | reducers and item lists | complete is called exactly once; Reduced unwraps immediately |
| p.reduce_driver | unit | [[spec.cr.reduce_driver]] | arbitrary reducers and iterables | sequencing is exactly one init, n steps, one complete |
| p.laws | law | [[spec.cr.laws]] | arbitrary item lists and reducers | identity: same inputs give same step results; associativity: resumed folds equal single folds |
| p.reduced_sentinel | unit | [[spec.cr.reduced_sentinel]] | reducers returning Reduced early | later items are unprocessed; nested Reduced flattens |
| p.builtins | unit | [[spec.cr.builtins]] | each built-in reducer on sample inputs | results match the documented per-reducer behavior |
| p.empty_input_table | unit | [[spec.cr.empty_input_table]] | empty inputs via lists, empty DataFrames, filtered-to-empty, head(0) | total reducers return their zero value; partial reducers raise the named ValueError |
| p.state_machine | unit | [[spec.cr.state_machine]] | driver runs over valid reducers and iterables | sequencing is correct without any runtime ProtocolError guard |

## Purpose

Give every reduction a single lawful protocol so reducers compose across
collections, transducers, and relational operations.

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

The reducer protocol SHALL define an implicit state machine with three states:

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

Each built-in reducer SHALL have defined behavior on empty input (complete(init())):

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

## Requirements

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

The reducer protocol SHALL define an implicit state machine with three states:

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

Each built-in reducer SHALL have defined behavior on empty input (complete(init())):

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

## Requirements
