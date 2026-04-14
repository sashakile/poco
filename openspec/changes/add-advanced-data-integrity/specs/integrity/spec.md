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

### Requirement: diff() computes difference between consecutive values

`expr.diff()` returns an Expr that computes the difference between the current
row's value and the previous row's value for the given expression. It is a
method on Expr.

- First row: diff() evaluates to None (no previous value)
- Numeric columns (int, float): difference via subtraction (current - previous)
- Non-numeric columns: SchemaError at pipeline construction time ("diff() requires numeric column")
- None values: if current or previous value is None, diff() evaluates to None
- Result type: same as input type (int diff → int, float diff → float)

diff() is a stateful expression that requires sequential evaluation. It is only
valid within transducers or materializing steps that process rows in order.

#### Scenario: diff on numeric column
- **GIVEN** df has column ts with values [100, 200, 500]
- **WHEN** `df | po.derive(gap=Person.ts.diff())`
- **THEN** row 1: gap=None, row 2: gap=100, row 3: gap=300

#### Scenario: diff on first row
- **GIVEN** df has column ts with values [42]
- **WHEN** `df | po.derive(gap=Person.ts.diff())`
- **THEN** row 1: gap=None

#### Scenario: diff with None values
- **GIVEN** df has column ts with values [100, None, 300]
- **WHEN** `df | po.derive(gap=Person.ts.diff())`
- **THEN** row 1: gap=None, row 2: gap=None (previous=100, current=None), row 3: gap=None (previous=None)

#### Scenario: diff on non-numeric column
- **GIVEN** Person.name is str
- **WHEN** `po.derive(gap=Person.name.diff())`
- **THEN** SchemaError: "diff() requires numeric column, got str"

### Requirement: IntegrityError from integrity transducers includes pipeline context

When is_monotonic or detect_gaps raises IntegrityError during materialization,
the error includes:
- The transducer that raised the error (e.g., "is_monotonic")
- The row index (0-based) where the violation occurred
- The actual value that violated the constraint
- The expected constraint (e.g., "expected value >= 11, got 9")

#### Scenario: Monotonicity violation with context
- **GIVEN** `df | po.integrity.is_monotonic(Person.ts, increasing=True) | po.select(Person.ts)`
- **WHEN** materialization reaches row index 5 with value 9 (previous was 11)
- **THEN** IntegrityError: "Monotonicity violation in is_monotonic(increasing=True) at row 5: expected value >= 11, got 9"

### Requirement: detect_gaps first row behavior and None handling

The first row processed by detect_gaps always has `is_gap=False` (no previous
value to compare against). The first row's value becomes the baseline for
subsequent comparisons.

None handling:
- If the first value is None: IntegrityError is raised ("detect_gaps requires non-None initial value for column")
- If a subsequent value is None: the row is marked with `is_gap=True` (None cannot be compared to threshold) and the previous non-None value is preserved as baseline
- If a subsequent value is not None: normal comparison against previous non-None value

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
