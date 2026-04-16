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

### Requirement: distinct with ttl is explicitly non-deterministic

`distinct(ttl=N)` SHALL depend on wall-clock time. The same input processed at
different speeds MAY produce different output. This SHALL be an intentional trade-off
for memory management on infinite/long-running streams.

Pipelines containing `distinct(ttl=...)` are NOT suitable for reproducible
results. Documentation SHALL prominently note: "TTL-based distinct produces
non-deterministic output dependent on execution timing. Do not use in pipelines
requiring reproducible results. For deterministic deduplication, use distinct()
without ttl."

#### Scenario: TTL non-determinism
- **GIVEN** pipeline = po.distinct(Person.id, ttl=1)
- **WHEN** the same data is processed slowly (each row takes 2 seconds)
- **THEN** previously-seen keys expire between rows, producing more output rows
- **AND** the result differs from fast execution of the same data

### Requirement: distinct documents memory growth and provides safeguards

`distinct()` without `ttl` or `max_seen` SHALL maintain an unbounded set of seen key
values. For high-cardinality streams, this set SHALL grow proportionally to the
number of unique keys.

Memory safeguards SHALL include:
- `max_seen=N`: limits the seen-set to N entries using LRU eviction. When the (N+1)th unique key arrives, the least-recently-seen key SHALL be evicted.
- `ttl=N`: evicts keys older than N seconds.
- Without either parameter: the seen-set SHALL be unbounded. This is acceptable for finite datasets but may cause memory exhaustion on infinite streams.

Documentation SHALL note: "For infinite or very large streams, use max_seen or
ttl to bound memory. Without these parameters, memory grows with the number of
unique keys."

#### Scenario: Unbounded distinct warns about growth

- **WHEN** a developer uses `po.distinct()` without `ttl` or `max_seen`
- **THEN** the documentation SHALL state that memory growth is unbounded with
  respect to unique key count

#### Scenario: max_seen bounds memory at the cost of exact global deduplication

- **WHEN** a developer uses `po.distinct(max_seen=100)`
- **THEN** the seen-set SHALL retain at most 100 key entries after eviction
- **AND** the documentation SHALL state that evicted keys MAY later reappear as
  distinct output rows

### Requirement: TTL-parameterized transducers are exempt from the reducer determinism law

The system SHALL treat TTL-parameterized transducers (e.g.,
`distinct(ttl=N)`) as explicitly exempt from the reducer determinism law,
because their step function depends on elapsed wall-clock time. The reducer
determinism law states: "step(s, a) always produces the same result for the
same inputs."

TTL-parameterized transducers MUST still satisfy all other transducer-reducer
compatibility laws (init preservation, complete propagation, Reduced
propagation).

Property-based tests for TTL transducers SHALL verify the
non-determinism-independent laws only.

#### Scenario: TTL distinct is exempt only from determinism

- **WHEN** `po.distinct(ttl=1)` is evaluated in tests
- **THEN** determinism SHALL NOT be asserted across different execution timings
- **AND** init preservation and complete propagation SHALL still be asserted
