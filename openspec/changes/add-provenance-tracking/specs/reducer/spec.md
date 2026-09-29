---
id: spec
kind: intent
statement: "THE system SHALL define a three-phase Reducer protocol with an optional invertible unstep method, guaranteed single complete() invocation, and a unstep(step()) round-trip law"
---

# Reducer protocol invertibility

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| red.three_phase | invariant | The Reducer protocol requires `init`, `step`, and `complete` with the specified pre/postconditions; `complete` is called exactly once per reduction, unwrapping `Reduced` immediately | [[spec]] |
| red.unstep_optional | invariant | `unstep(acc, item)` is optional; invertible reducers support incremental recomputation on shrinking fibers, and consumers fall back to a full re-reduce for non-invertible reducers | [[spec]] |
| red.unstep_law | invariant | For any invertible reducer, `unstep(step(acc, item), item) == acc`, verified by property-based test for every reducer implementing unstep | [[spec]] |

## Model

### States

- `empty`
- `stepping`
- `completed`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_init | empty | stepping | [[spec.red.three_phase]] |
| t_step | stepping | stepping | [[spec.red.three_phase]] |
| t_reduce | stepping | completed | [[spec.red.three_phase]] |
| t_unstep | stepping | stepping | [[spec.red.unstep_law]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.three_phase | unit | [[spec.red.three_phase]] | arbitrary item lists and reducers | complete is called exactly once; Reduced unwraps immediately |
| p.unstep_optional | unit | [[spec.red.unstep_optional]] | shrinking fibers reduced with invertible and non-invertible reducers | incremental result equals full re-reduce; fallback path matches |
| p.unstep_law | law | [[spec.red.unstep_law]] | arbitrary accumulators and previously stepped items | identity: `unstep(step(acc, item), item) == acc`; associativity: order of stepped items does not affect the unstepped accumulator |

## Purpose

Extend the reducer protocol so fibers can shrink incrementally when
invertible, without changing semantics for existing reducers.

## MODIFIED Requirements

### Requirement: Three-phase reducer protocol

The system SHALL define a `Reducer` protocol with three required methods:
- `init() -> Acc`
- `step(acc: Acc, item) -> Acc | Reduced[Acc]`
- `complete(acc: Acc) -> Result`

and one optional fourth method:
- `unstep(acc: Acc, item) -> Acc` — removes the effect of a previously
  `step`-ped item from the accumulator. A `Reducer` implementing `unstep`
  is called **invertible**. Invertible reducers support incremental
  recomputation when a fiber (see `provenance/spec.md`) shrinks by removal
  of specific items, without requiring a full re-reduction over the
  remaining items. Reducers that do not implement `unstep` remain fully
  valid; consumers SHALL fall back to a full `init`/`step*`/`complete` pass
  over the remaining items when a shrinking fiber is reduced with such a
  reducer.

**Formal Pre/Postconditions:**
- `init()`:
  - Pre: None.
  - Post: Returns a valid initial accumulator `Acc`.
- `step(acc, item)`:
  - Pre: `acc` must be a valid `Acc` produced by `init` or a previous `step`. `item` must satisfy the row contract.
  - Post: Returns a valid `Acc` or a `Reduced[Acc]` signaling early termination.
- `complete(acc)`:
  - Pre: `acc` must be a valid `Acc` (unwrapped if from `Reduced`).
  - Post: Returns the final `Result`.
- `unstep(acc, item)` (optional):
  - Pre: `acc` must be a valid `Acc` that was previously produced by
    `step(prior_acc, item)` for this exact `item` (removal of an item never
    `step`-ped into `acc` is undefined behavior).
  - Post: Returns the `Acc` equivalent to what `init`/`step*` would have
    produced had `item` never been included.

**Termination Invariant:**
- The system SHALL guarantee that `complete(acc)` is called exactly once for every reduction, regardless of whether termination occurred via end-of-stream or the `Reduced` protocol. If `step` returns `Reduced(acc)`, the `acc` SHALL be unwrapped and passed immediately to `complete`.

**Invertibility Invariant:**
- For any invertible reducer, any accumulator `acc`, and any `item`
  previously incorporated via `step`: `unstep(step(acc, item), item) ==
  acc`. This SHALL hold as a property-based test for every reducer that
  implements `unstep`.

#### Scenario: Reducer with all three required phases

- **WHEN** a `mean` reducer is applied to `[10, 20, 30]`
- **THEN** `init()` SHALL return `(0, 0)` and `complete()` SHALL return `20.0`

#### Scenario: Invertible reducer supports removal

- **GIVEN** `sum_of`'s accumulator after `step`-ping `[10, 20, 30]` is `60`
- **WHEN** `unstep(60, 20)` is called
- **THEN** the result SHALL be `40`, equivalent to having `step`-ped only
  `[10, 30]`

#### Scenario: Non-invertible reducer has no unstep

- **GIVEN** the `max_reducer`
- **WHEN** its protocol is inspected
- **THEN** it SHALL NOT implement `unstep`, since removing the current
  maximum does not determine the new maximum from the accumulator alone
- **AND** consumers SHALL fall back to a full recompute over the remaining
  items when a fiber reduced with `max_reducer` shrinks

## Requirements

### Requirement: Three-phase reducer protocol

The system SHALL define a `Reducer` protocol with three required methods:
- `init() -> Acc`
- `step(acc: Acc, item) -> Acc | Reduced[Acc]`
- `complete(acc: Acc) -> Result`

and one optional fourth method:
- `unstep(acc: Acc, item) -> Acc` — removes the effect of a previously
  `step`-ped item from the accumulator. A `Reducer` implementing `unstep`
  is called **invertible**. Invertible reducers support incremental
  recomputation when a fiber (see `provenance/spec.md`) shrinks by removal
  of specific items, without requiring a full re-reduction over the
  remaining items. Reducers that do not implement `unstep` remain fully
  valid; consumers SHALL fall back to a full `init`/`step*`/`complete` pass
  over the remaining items when a shrinking fiber is reduced with such a
  reducer.

**Formal Pre/Postconditions:**
- `init()`:
  - Pre: None.
  - Post: Returns a valid initial accumulator `Acc`.
- `step(acc, item)`:
  - Pre: `acc` must be a valid `Acc` produced by `init` or a previous `step`. `item` must satisfy the row contract.
  - Post: Returns a valid `Acc` or a `Reduced[Acc]` signaling early termination.
- `complete(acc)`:
  - Pre: `acc` must be a valid `Acc` (unwrapped if from `Reduced`).
  - Post: Returns the final `Result`.
- `unstep(acc, item)` (optional):
  - Pre: `acc` must be a valid `Acc` that was previously produced by
    `step(prior_acc, item)` for this exact `item` (removal of an item never
    `step`-ped into `acc` is undefined behavior).
  - Post: Returns the `Acc` equivalent to what `init`/`step*` would have
    produced had `item` never been included.

**Termination Invariant:**
- The system SHALL guarantee that `complete(acc)` is called exactly once for every reduction, regardless of whether termination occurred via end-of-stream or the `Reduced` protocol. If `step` returns `Reduced(acc)`, the `acc` SHALL be unwrapped and passed immediately to `complete`.

**Invertibility Invariant:**
- For any invertible reducer, any accumulator `acc`, and any `item`
  previously incorporated via `step`: `unstep(step(acc, item), item) ==
  acc`. This SHALL hold as a property-based test for every reducer that
  implements `unstep`.

#### Scenario: Reducer with all three required phases

- **WHEN** a `mean` reducer is applied to `[10, 20, 30]`
- **THEN** `init()` SHALL return `(0, 0)` and `complete()` SHALL return `20.0`

#### Scenario: Invertible reducer supports removal

- **GIVEN** `sum_of`'s accumulator after `step`-ping `[10, 20, 30]` is `60`
- **WHEN** `unstep(60, 20)` is called
- **THEN** the result SHALL be `40`, equivalent to having `step`-ped only
  `[10, 30]`

#### Scenario: Non-invertible reducer has no unstep

- **GIVEN** the `max_reducer`
- **WHEN** its protocol is inspected
- **THEN** it SHALL NOT implement `unstep`, since removing the current
  maximum does not determine the new maximum from the accumulator alone
- **AND** consumers SHALL fall back to a full recompute over the remaining
  items when a fiber reduced with `max_reducer` shrinks

## Requirements
