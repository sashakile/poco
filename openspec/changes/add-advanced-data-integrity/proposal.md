# Change: Add advanced data integrity — time-series gaps, stable sorting, join multiplicity, precision reducers

## Why

Real-world data is messy. It contains missing intervals (gaps), simultaneous events (ties), floating-point accumulation errors, and silent data duplication (multiplicity). While the core architecture provides basic data structures, it must also provide the **System of Defenses** required to detect and mitigate these pathologies before they corrupt analysis results.

## What Changes

- Add **Integrity Checking** capability for sequence-based data:
  - Time-series gap detection via `diff()` and `threshold`
  - Monotonicity checks (asserting that values only increase, e.g., timestamps)
- Add **Stable Sorting** requirement for `sort_by`:
  - Ensuring deterministic tie-breaking for simultaneous events
  - Support for composite keys (`sort_by(ts, id)`)
- Add **Join Multiplicity Constraints**:
  - Optional `validate="1:1" | "1:N" | "N:1"` parameter to `po.join`
  - Raising `IntegrityError` if the Right side join keys are not unique (for N:1/1:1)
- Add **High-Precision Reducers**:
  - Implement Kahan summation or equivalent in `sum_reducer` to mitigate floating-point drift
- Add **Stateful Memory Management** for transducers:
  - Add optional `max_seen` and `ttl` to `distinct()` to prevent OOM on infinite streams
- Add **Bitemporal Awareness** (Inquiry/Initial Spec):
  - Support for `event_time` vs `processing_time` tagging (logical model)

## Impact

- **Affected Specs**: `integrity` (New), `relational`, `reducer`, `transducer`
- **Affected Code**: `poco/po.py` (implementation of join validation, sorting stability, and precision logic)
- **BREAKING**: None (Extends existing API)
