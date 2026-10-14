---
id: transducer
kind: intent
statement: "WHEN po.distinct is called THE system SHALL return a PipelineStep whose data component is a stateful dedup transducer with ttl/max_seen LRU eviction"
---

# distinct returns a PipelineStep

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| fx.distinct_returns_step | invariant | `po.distinct(...)` returns a `PipelineStep`, not a bare Transducer; `ttl`/`max_seen` govern the data component's behavior only, not the factory's return type | [[transducer]] |
| fx.distinct_dedup_component | invariant | The data component is a stateful transducer passing only unique keys, evicting expired (ttl) or least-recently-seen (max_seen) keys under LRU policy | [[transducer]] |

## Model

### States

- `constructed`
- `deduplicating`
- `evicted`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_construct | constructed | deduplicating | [[transducer.fx.distinct_returns_step]] |
| t_pass_unique | deduplicating | deduplicating | [[transducer.fx.distinct_dedup_component]] |
| t_evict | deduplicating | evicted | [[transducer.fx.distinct_dedup_component]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.distinct_returns_step | unit | [[transducer.fx.distinct_returns_step]] | distinct calls with and without ttl/max_seen | the result is a PipelineStep and not a Transducer instance |
| p.distinct_dedup_component | unit | [[transducer.fx.distinct_dedup_component]] | key streams crossing ttl/max_seen thresholds | unique keys pass once; eviction follows ttl/LRU policy |

## Purpose

Correct the return-type contradiction in the distinct transducer wording so
it agrees with pipeline/spec.md's authoritative factory signature.

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

## Requirements

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

## Requirements
