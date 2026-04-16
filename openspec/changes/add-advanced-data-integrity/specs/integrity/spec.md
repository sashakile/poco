## ADDED Requirements

### Requirement: Time-series gap detection

`po.integrity.detect_gaps(expr, threshold)` SHALL return a materializing
`PipelineStep` that extends each output row with a boolean `is_gap` column.
The step SHALL preserve all input columns and SHALL add `is_gap: bool` through
an `Extend({"is_gap": bool})` schema transform.

Gap detection SHALL compare the current value of `expr` with the previous value
in the current row order, and `is_gap` SHALL be `True` when that difference
exceeds `threshold`.

The step SHALL maintain internal state for the previous value and initialize it
from the first observed value in the current evaluation order.

#### Scenario: Gap detected in seconds
- **WHEN** timestamp sequence is `[1, 2, 3, 300, 301]` and `threshold=60`
- **THEN** the row with `300` SHALL be emitted with `is_gap=True`
- **AND** the result schema SHALL include all original columns plus `is_gap`

### Requirement: Monotonicity check

`po.integrity.is_monotonic(expr, increasing=True, strict=False)` SHALL return
a stateful transducer that raises `IntegrityError` if the sequence contract is
violated.

Integrity operations SHALL follow the public error contract in `errors/spec.md`:
constraint violations SHALL raise `IntegrityError`, schema-shape mistakes SHALL
raise `SchemaError`, and undocumented raw Python exceptions SHALL NOT escape
across the public API boundary.

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

### Requirement: diff() computes difference between consecutive values in ordered materializing steps

`expr.diff()` SHALL return an ordered expression fragment that computes the
difference between the current row's value and the previous row's value for the
given expression. It SHALL only be valid inside materializing, order-aware
pipeline steps that explicitly support ordered expressions, such as
`po.integrity.detect_gaps(...)`. Plain `po.derive(...)` SHALL NOT accept
`diff()` expressions.

- First row: `diff()` evaluates to `None` (no previous value)
- Numeric columns (`int`, `float`): difference via subtraction (`current - previous`)
- Non-numeric columns: `SchemaError` at pipeline construction time
  ("diff() requires numeric column")
- `None` values: if current or previous value is `None`, `diff()` evaluates to `None`
- Result type: same as input type (`int` diff → `int`, `float` diff → `float`)

`diff()` SHALL operate on the current materialization order. For time-series
semantics, callers SHALL establish that order explicitly, typically with
`po.sort_by(...)`, before applying an integrity step that uses `diff()`.

#### Scenario: diff used inside detect_gaps
- **GIVEN** df has column `ts` with values `[100, 200, 500]`
- **WHEN** `df | po.integrity.detect_gaps(Person.ts, threshold=150)`
- **THEN** the underlying ordered comparison SHALL behave as if `Person.ts.diff()`
  produced `[None, 100, 300]`

#### Scenario: diff on first row
- **GIVEN** df has column `ts` with values `[42]`
- **WHEN** an ordered integrity step evaluates `Person.ts.diff()`
- **THEN** row 1 SHALL observe `diff() = None`

#### Scenario: diff with None values
- **GIVEN** df has column `ts` with values `[100, None, 300]`
- **WHEN** an ordered integrity step evaluates `Person.ts.diff()`
- **THEN** row 1 SHALL observe `None`, row 2 SHALL observe `None`, and row 3 SHALL observe `None`

#### Scenario: diff on non-numeric column
- **GIVEN** `Person.name` is `str`
- **WHEN** an integrity step attempts to evaluate `Person.name.diff()`
- **THEN** the system SHALL raise `SchemaError`: "diff() requires numeric column, got str"

#### Scenario: diff rejected in plain derive
- **WHEN** `po.derive(gap=Person.ts.diff())` is constructed
- **THEN** the system SHALL raise `UnsupportedOperationError` indicating that
  `diff()` requires an ordered materializing integrity or window-style step

#### Scenario: diff after explicit ordering
- **GIVEN** rows are not initially ordered by timestamp
- **WHEN** `df | po.sort_by(Person.ts) | po.integrity.detect_gaps(Person.ts, threshold=60)`
- **THEN** gap detection SHALL use the sorted row order

### Requirement: IntegrityError from integrity transducers includes pipeline context

The system SHALL include pipeline context when `is_monotonic` or `detect_gaps`
raises `IntegrityError` during materialization. The error SHALL include:
- The operation that raised the error (e.g., `"is_monotonic"`)
- The row index (0-based) where the violation occurred
- The actual value that violated the constraint
- The expected constraint (e.g., `"expected value >= 11, got 9"`)

These integrity failures SHALL use the public `IntegrityError` contract from
`errors/spec.md`, including machine-readable `.details` fields for `operation`,
`row_index`, `actual`, and `constraint`.

#### Scenario: Monotonicity violation with context
- **GIVEN** `df | po.integrity.is_monotonic(Person.ts, increasing=True) | po.select(Person.ts)`
- **WHEN** materialization reaches row index 5 with value 9 (previous was 11)
- **THEN** IntegrityError: "Monotonicity violation in is_monotonic(increasing=True) at row 5: expected value >= 11, got 9"

### Requirement: detect_gaps first row behavior and None handling

The first row processed by `detect_gaps` SHALL always have `is_gap=False` (no previous
value to compare against). The first row's value SHALL become the baseline for
subsequent comparisons.

None handling SHALL follow these rules:
- If the first value is `None`: the system SHALL raise `IntegrityError` ("detect_gaps requires non-None initial value for column")
- If a subsequent value is `None`: the row SHALL be emitted with `is_gap=True` (None cannot be compared to threshold) and the previous non-None value SHALL be preserved as baseline
- If a subsequent value is not `None`: the system SHALL perform normal comparison against the previous non-None value

#### Scenario: First row is baseline
- **GIVEN** df has column ts with values [100, 200, 500] and threshold=60
- **WHEN** detect_gaps processes the first row
- **THEN** is_gap=False, and 100 becomes baseline

#### Scenario: First value is None
- **GIVEN** df has column ts with values [None, 200, 300] and threshold=60
- **WHEN** detect_gaps processes the first row
- **THEN** IntegrityError: "detect_gaps requires non-None initial value for column 'ts'"

#### Scenario: None in subsequent row
- **GIVEN** df has column ts with values [100, None, 200] and threshold=60
- **WHEN** detect_gaps processes the rows
- **THEN** row 1: is_gap=False, row 2: is_gap=True (None), row 3: compared against 100 (last non-None)
