## MODIFIED Requirements

### Requirement: Stateful distinct transducer

`po.distinct(*exprs, ttl=None, max_seen=None)` SHALL return a `PipelineStep`
(per `pipeline/spec.md`'s "distinct removes duplicate rows" requirement)
whose data component is a stateful transducer that only passes through rows
with unique key values. This corrects the previous wording, which stated
that `po.distinct(...)` itself returns "a stateful transducer" — a
contradiction with `pipeline/spec.md`, the authoritative source for
`po.distinct`'s public signature and return type. The `ttl` and `max_seen`
parameters govern the behavior of that data component only; they do not
change the factory's return type.

To manage memory on infinite or massive streams, the `distinct()` transducer
SHALL accept `ttl` (Time-To-Live in seconds) and `max_seen` (maximum keys to
retain in memory). When either threshold is exceeded, old keys SHALL be
evicted from the seen-set (LRU policy).

#### Scenario: distinct() returns a PipelineStep, not a bare transducer

- **WHEN** `po.distinct(Person.id, ttl=60)` is called
- **THEN** the return value SHALL be a `PipelineStep`
- **AND** `isinstance(result, Transducer)` SHALL be `False`
- **AND** the `PipelineStep`'s data component SHALL be the stateful,
  TTL-aware dedup transducer described by this requirement

#### Scenario: Distinct with TTL evicts old keys

- **WHEN** `df | po.distinct(ttl=1)` is used on a stream
- **AND** a key is seen again after 2 seconds
- **THEN** it SHALL be treated as a new unique key (passed through)

#### Scenario: Distinct with max_seen evicts old keys

- **WHEN** `df | po.distinct(max_seen=100)` is used and the 101st unique key
  arrives
- **THEN** the least-recently-seen key SHALL be evicted
