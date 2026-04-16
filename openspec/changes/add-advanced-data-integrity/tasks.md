## 1. Sequence & Integrity
- [ ] 1.1 Add `diff()` expression and `threshold` detection for time-series gaps
- [ ] 1.2 Implement `monotonicity_check` transducer
- [ ] 1.3 Add tests for gap detection (test_integrity_gaps)

## 2. Sorting & Stability
- [ ] 2.1 Update `sort_by` to be explicitly stable
- [ ] 2.2 Implement composite key tie-breaking in `sort_by`
- [ ] 2.3 Add tests for stable sorting on duplicate keys

## 3. Relational Constraints
- [ ] 3.1 Update `po.join` to accept `validate` parameter
- [ ] 3.2 Implement uniqueness checks for `1:1`, `1:N`, and `N:1` joins with `N:N` as the explicit no-check mode
- [ ] 3.3 Add `IntegrityError` for join multiplicity violations with structured diagnostic fields and clear remediation guidance

## 4. Precision & Memory
- [ ] 4.1 Update `sum_reducer` with Kahan summation
- [ ] 4.2 Add `max_seen` and `ttl` parameters to `distinct()` transducer
- [ ] 4.3 Implement LRU/TTL logic in stateful transducers to prevent memory leaks

## 5. Verification
- [ ] 5.1 Run all pathological torture tests
- [ ] 5.2 Validate performance impact of compensated summation and join validation
- [ ] 5.3 Verify memory usage on infinite streams with `distinct(ttl=...)`
- [ ] 5.4 Add regression tests and docs for non-deterministic or degraded modes (`distinct(ttl=...)`, bounded `max_seen`)
