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
