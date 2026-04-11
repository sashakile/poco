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
