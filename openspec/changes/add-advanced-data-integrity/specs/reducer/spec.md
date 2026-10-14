---
id: reducer
kind: intent
statement: "THE system SHALL provide built-in reducers including a Neumaier-compensated sum_reducer that propagates IEEE 754 special values and preserves int arithmetic"
---

# Built-in reducers with compensated summation

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| red.builtin_set | invariant | Built-in reducers are `to_list`, `count`, `sum_reducer`, `min_reducer`, `max_reducer`, and `mean` | [[reducer]] |
| red.neumaier | invariant | `sum_reducer` uses Neumaier compensated summation with O(ε) error bound instead of O(nε) naive drift | [[reducer]] |
| red.ieee_specials | invariant | NaN input yields NaN; inf yields ±inf; inf + (-inf) yields NaN; mixed int+float promotes to float with Neumaier applied | [[reducer]] |
| red.all_int_exact | invariant | All-int input uses Python's arbitrary-precision int addition, returning an int with no float conversion | [[reducer]] |

## Model

### States

- `empty`
- `accumulating`
- `completed`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_init | empty | accumulating | [[reducer.red.neumaier]] |
| t_add | accumulating | accumulating | [[reducer.red.neumaier]] |
| t_special | accumulating | accumulating | [[reducer.red.ieee_specials]] |
| t_complete | accumulating | completed | [[reducer.red.all_int_exact]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.builtin_set | unit | [[reducer.red.builtin_set]] | each built-in reducer name | the reducer exists and reduces sample inputs correctly |
| p.neumaier | unit | [[reducer.red.neumaier]] | long streams of small floats added to a large running sum | accuracy beats naive sum() and stays within O(ε) |
| p.ieee_specials | unit | [[reducer.red.ieee_specials]] | inputs containing NaN, inf, -inf, and mixed int/float | special-value results match IEEE 754 semantics |
| p.all_int_exact | unit | [[reducer.red.all_int_exact]] | all-int inputs | result is an exact int |

## Purpose

Make floating-point aggregation accurate and predictable at the extremes
without sacrificing exact integer arithmetic.

## MODIFIED Requirements

### Requirement: Built-in reducers

The system SHALL provide these built-in reducers:
- `to_list`
- `count`
- `sum_reducer` (High-precision implementation)
- `min_reducer`
- `max_reducer`
- `mean`

`sum_reducer` SHALL use a high-precision accumulation algorithm (e.g.,
Kahan summation or Neumaier summation) to minimize floating-point error
over large streams of small values.

#### Scenario: sum_reducer minimizes drift
- **WHEN** `po.reduce(po.sum_reducer, [1.0, 1e-16, 1e-16, ..., 1e-16])`
- **THEN** it SHALL return a more accurate result than naive `sum()`

### Requirement: sum_reducer uses Neumaier compensated summation with defined error bound

`sum_reducer` SHALL use the Neumaier variant of compensated summation (an improvement
over Kahan summation that handles the case where the running sum is smaller
than the new addend).

Error bound: O(ε) where ε is machine epsilon (~2.2e-16 for float64), compared
to O(nε) for naive summation. This means the accumulated error is bounded by a
small multiple of machine epsilon regardless of the number of items, rather
than growing linearly with n.

This is NOT exact arithmetic. For applications requiring exact decimal
arithmetic, use Python's `decimal.Decimal` type in a custom reducer.

#### Scenario: Neumaier summation accuracy
- **GIVEN** data = [1.0] + [1e-16] * 10000
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is closer to 1.0 + 10000 * 1e-16 than naive sum() would produce

### Requirement: sum_reducer propagates inf and NaN per IEEE 754

`sum_reducer` SHALL follow IEEE 754 for special float values:
- NaN in input: result is NaN (NaN propagates through addition)
- inf in input: result is inf (or -inf)
- inf + (-inf) in input: result is NaN
- All-int input: Kahan/Neumaier not applied; uses Python int addition (arbitrary precision). Result is int.
- Mixed int+float input: promoted to float, Neumaier applied. Result is float.

#### Scenario: NaN propagation
- **GIVEN** data = [1.0, float("nan"), 3.0]
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is NaN

#### Scenario: inf handling
- **GIVEN** data = [1.0, float("inf"), 3.0]
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is inf

#### Scenario: All-int preserves int type
- **GIVEN** data = [1, 2, 3]
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is 6 with type int (no float conversion)

## Requirements

### Requirement: Built-in reducers

The system SHALL provide these built-in reducers:
- `to_list`
- `count`
- `sum_reducer` (High-precision implementation)
- `min_reducer`
- `max_reducer`
- `mean`

`sum_reducer` SHALL use a high-precision accumulation algorithm (e.g.,
Kahan summation or Neumaier summation) to minimize floating-point error
over large streams of small values.

#### Scenario: sum_reducer minimizes drift
- **WHEN** `po.reduce(po.sum_reducer, [1.0, 1e-16, 1e-16, ..., 1e-16])`
- **THEN** it SHALL return a more accurate result than naive `sum()`

### Requirement: sum_reducer uses Neumaier compensated summation with defined error bound

`sum_reducer` SHALL use the Neumaier variant of compensated summation (an improvement
over Kahan summation that handles the case where the running sum is smaller
than the new addend).

Error bound: O(ε) where ε is machine epsilon (~2.2e-16 for float64), compared
to O(nε) for naive summation. This means the accumulated error is bounded by a
small multiple of machine epsilon regardless of the number of items, rather
than growing linearly with n.

This is NOT exact arithmetic. For applications requiring exact decimal
arithmetic, use Python's `decimal.Decimal` type in a custom reducer.

#### Scenario: Neumaier summation accuracy
- **GIVEN** data = [1.0] + [1e-16] * 10000
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is closer to 1.0 + 10000 * 1e-16 than naive sum() would produce

### Requirement: sum_reducer propagates inf and NaN per IEEE 754

`sum_reducer` SHALL follow IEEE 754 for special float values:
- NaN in input: result is NaN (NaN propagates through addition)
- inf in input: result is inf (or -inf)
- inf + (-inf) in input: result is NaN
- All-int input: Kahan/Neumaier not applied; uses Python int addition (arbitrary precision). Result is int.
- Mixed int+float input: promoted to float, Neumaier applied. Result is float.

#### Scenario: NaN propagation
- **GIVEN** data = [1.0, float("nan"), 3.0]
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is NaN

#### Scenario: inf handling
- **GIVEN** data = [1.0, float("inf"), 3.0]
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is inf

#### Scenario: All-int preserves int type
- **GIVEN** data = [1, 2, 3]
- **WHEN** `po.reduce(po.sum_reducer, data)`
- **THEN** result is 6 with type int (no float conversion)

## Requirements
