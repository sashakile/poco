## ADDED Requirements

### Requirement: Time-series gap detection

`po.integrity.detect_gaps(expr, threshold)` SHALL return a stateful transducer
that marks gaps where the difference between the current value of `expr` and
the previous value exceeds `threshold`.

The transducer SHALL maintain internal state for the previous value and
initialize it to the first observed value.

#### Scenario: Gap detected in seconds
- **WHEN** timestamp sequence is `[1, 2, 3, 300, 301]` and `threshold=60`
- **THEN** the row with `300` SHALL be marked with `is_gap=True`

### Requirement: Monotonicity check

`po.integrity.is_monotonic(expr, increasing=True, strict=False)` SHALL return
a stateful transducer that raises `IntegrityError` if the sequence contract is
violated.

- `increasing=True, strict=False`: $V_n \ge V_{n-1}$
- `increasing=True, strict=True`: $V_n > V_{n-1}$
- `increasing=False, strict=False`: $V_n \le V_{n-1}$
- `increasing=False, strict=True`: $V_n < V_{n-1}$

#### Scenario: Decreasing timestamp raises error
- **WHEN** `increasing=True` and sequence is `[10, 11, 9]`
- **THEN** it SHALL raise `IntegrityError` on the third row (9 < 11)

### Requirement: Stable Sorting

`po.sort_by` SHALL implement a stable sort algorithm (e.g., Timsort).
When multiple rows have equal sort keys, their relative order from the
source MUST be preserved.

#### Scenario: Simultaneous events maintain insertion order
- **WHEN** rows A and B have `timestamp=100` and A appeared before B in the input
- **THEN** A SHALL appear before B in the output after `sort_by(timestamp)`
