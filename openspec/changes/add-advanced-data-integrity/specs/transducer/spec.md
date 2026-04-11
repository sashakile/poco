## MODIFIED Requirements

### Requirement: Stateful distinct transducer

`po.distinct(*exprs, ttl=None, max_seen=None)` SHALL return a stateful
transducer that only passes through rows with unique key values.

To manage memory on infinite or massive streams, the `distinct()` transducer
SHALL accept `ttl` (Time-To-Live in seconds) and `max_seen` (maximum keys to
retain in memory). When either threshold is exceeded, old keys SHALL be
evicted from the seen-set (LRU policy).

#### Scenario: Distinct with TTL evicts old keys
- **WHEN** `po.distinct(ttl=1)` is used on a stream
- **AND** a key is seen again after 2 seconds
- **THEN** it SHALL be treated as a new unique key (passed through)

#### Scenario: Distinct with max_seen evicts old keys
- **WHEN** `po.distinct(max_seen=100)` is used and the 101st unique key arrives
- **THEN** the least-recently-seen key SHALL be evicted
