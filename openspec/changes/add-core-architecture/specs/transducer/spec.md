---
id: transducer
kind: intent
statement: "THE system SHALL transform reducers via composable left-to-right transducers whose wrapping is fresh, reusable, law-abiding, and completes outermost-first"
---

# Transducer protocol

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| ct.transformer | invariant | A transducer is a callable transforming one reducer into another, wrapping all three phases, operating on the shared row contract in pipelines; each reduce call re-wraps freshly | [[transducer]] |
| ct.compatibility_laws | invariant | Transducers preserve init by default, propagate complete to the inner reducer, and propagate Reduced from inner step | [[transducer]] |
| ct.composition | invariant | `xf1 \| xf2` applies xf1 first (left-to-right data flow, right-to-left function composition) and composition is associative | [[transducer]] |
| ct.identity | invariant | An identity transducer is the neutral element of composition; `comp()` with no arguments returns it | [[transducer]] |
| ct.core_builtins | invariant | Core transducers are `filtering`, `mapping`, `taking`, and `dropping`; taking/dropping validate n (`ValueError` on negative) and terminate early via Reduced | [[transducer]] |
| ct.fresh_state | invariant | Each wrapping produces fresh independent closure state; transducer values are stateless and reusable across wrappings and pipelines | [[transducer]] |
| ct.complete_order | invariant | In composed transducers, complete() propagates outermost-first, each layer seeing its own accumulator state, buffering layers flushing before propagating inward | [[transducer]] |
| ct.state_independence_tested | invariant | Property-based tests verify stateful transducers (taking, dropping, distinct) produce identical results on repeated applications | [[transducer]] |

## Model

### States

- `factory`
- `wrapped`
- `stepping`
- `terminated`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_wrap | factory | wrapped | [[transducer.ct.fresh_state]] |
| t_step | wrapped | stepping | [[transducer.ct.compatibility_laws]] |
| t_compose | factory | factory | [[transducer.ct.composition]] |
| t_identity | factory | factory | [[transducer.ct.identity]] |
| t_terminate | stepping | terminated | [[transducer.ct.core_builtins]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.transformer | unit | [[transducer.ct.transformer]] | wrapping calls of filtering/mapping over to_list | only matching or transformed items accumulate; re-wrapping is fresh |
| p.compatibility_laws | law | [[transducer.ct.compatibility_laws]] | transducers over reducers | **identity:** init is preserved; **associativity:** complete/Reduced propagate through any nesting |
| p.composition | unit | [[transducer.ct.composition]] | transducer triples composed both groupings | left-to-right data flow holds and both groupings agree |
| p.identity | unit | [[transducer.ct.identity]] | compositions with and without identity | identity is neutral on both sides |
| p.core_builtins | unit | [[transducer.ct.core_builtins]] | taking/dropping over varied n and inputs | slicing semantics, zero cases, negative-n errors, and early termination hold |
| p.fresh_state | unit | [[transducer.ct.fresh_state]] | reusable transducer values applied multiple times | each wrapping tracks independent state; reuse never leaks state |
| p.complete_order | unit | [[transducer.ct.complete_order]] | composed transducers with buffered layers | complete order is outermost-first with flushing before inward propagation |
| p.state_independence_tested | unit | [[transducer.ct.state_independence_tested]] | repeated reduces of stateful transducers | repeated applications produce identical results |

## Purpose

Make row processing composable and reusable by transforming reducers instead
of materializing intermediates.

## ADDED Requirements

### Requirement: Transducer as reducer transformer

A transducer SHALL be a callable that transforms one reducer into another.
The transducer SHALL wrap all three phases (init, step, complete) of the
inner reducer as defined in `reducer/spec.md`.

In a DataFrame pipeline, transducers SHALL operate on items that satisfy the
materialized row contract defined in `row-model/spec.md`.

#### Scenario: Filtering transducer

- **WHEN** a `filtering(pred)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL only accumulate items where `pred` is true

#### Scenario: Mapping transducer

- **WHEN** a `mapping(f)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL accumulate `f(item)` for each item

#### Scenario: Reduce with transducer re-wraps on each call

- **WHEN** `po.reduce(reducer, collection, transducer=xf)` is called
- **THEN** `xf(reducer)` SHALL produce a fresh wrapped reducer for that call

### Requirement: Transducer-reducer compatibility laws

Transducers wrapping reducers SHALL satisfy the following laws:

1. **Init preservation**: `xf(r).init()` SHALL equal `r.init()` by default
2. **Complete propagation**: `xf(r).complete(s)` SHALL call `r.complete(...)` on some state
3. **Reduced propagation**: if inner `step` returns `Reduced`, outer SHALL propagate it

#### Scenario: Init preserved

- **WHEN** `filtering(pred)` wraps `to_list`
- **THEN** `filtering(pred)(to_list).init()` SHALL equal `to_list.init()`

#### Scenario: Complete propagated

- **WHEN** any transducer wraps a `mean` reducer
- **THEN** `complete` SHALL be called on the inner reducer to finalize the result

### Requirement: Transducer composition is left-to-right

Transducers SHALL compose via the `|` operator in left-to-right data flow
order: `xf1 | xf2` means apply `xf1` first, then `xf2`.

Composition SHALL be associative: `(a | b) | c` equals `a | (b | c)`.

Internally, left-to-right data flow requires right-to-left function composition:
`(xf1 | xf2)(reducer) == xf1(xf2(reducer))`.

#### Scenario: Left-to-right data flow

- **WHEN** `filtering(lambda x: x > 0) | mapping(lambda x: x * 10)` is composed
- **THEN** applying it to `[-1, 2, -3, 4]` with `to_list` SHALL produce `[20, 40]`
  (filter first: `[2, 4]`, then map: `[20, 40]`)

#### Scenario: Non-commutative order matters

- **WHEN** `mapping(lambda x: x - 3) | filtering(lambda x: x > 0)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2]` (map first: `[-2, -1, 0, 1, 2]`, then filter: `[1, 2]`)

#### Scenario: Composition is associative

- **WHEN** transducers `a`, `b`, `c` are composed as `(a | b) | c` and `a | (b | c)`
- **THEN** both SHALL produce identical results for any input

### Requirement: Identity transducer

The system SHALL provide an identity transducer that passes through the
inner reducer unchanged. `comp()` with no arguments SHALL return the identity.
The identity transducer SHALL be the neutral element of composition (monoid identity).

#### Scenario: Identity leaves reducer unchanged

- **WHEN** the identity transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL behave identically to `to_list`

#### Scenario: Identity is neutral element

- **WHEN** `identity | xf` and `xf | identity` are composed
- **THEN** both SHALL produce the same results as `xf` alone

### Requirement: Core transducers (low-level)

The system SHALL provide the following built-in transducers that work with
plain Python callables. These are the low-level building blocks:
- `filtering(predicate)` — keep items where predicate is true
- `mapping(function)` — transform each item
- `taking(n)` — take first n items (early termination via Reduced)
- `dropping(n)` — skip first n items

#### Scenario: Taking with early termination

- **WHEN** `taking(2)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2]` and items 3-5 SHALL NOT be processed

#### Scenario: Dropping skips items

- **WHEN** `dropping(2)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[3, 4, 5]`

#### Scenario: Taking with zero returns empty

- **WHEN** `taking(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[]`

#### Scenario: Taking with negative raises error

- **WHEN** `taking(-1)` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Dropping with zero is identity

- **WHEN** `dropping(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[1, 2, 3]`

#### Scenario: Dropping with negative raises error

- **WHEN** `dropping(-1)` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Dropping more than input length

- **WHEN** `dropping(100)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[]`

#### Scenario: Composed stateful transducers

- **WHEN** `taking(3) | taking(5)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2, 3]` (taking(3) emits 3 items,
  taking(5) passes all 3 through)

### Requirement: Stateful transducers SHALL produce fresh closure state per wrapping

Stateful transducers (e.g., `taking(n)`, `dropping(n)`) SHALL manage mutable
state in closure variables captured when the transducer wraps a reducer.
Each call to the transducer (i.e., each wrapping of a new reducer) SHALL
produce fresh, independent state.

#### Scenario: taking produces independent state per wrapping

- **WHEN** `taking(2)` wraps `to_list` twice (two separate calls)
- **THEN** each wrapped reducer SHALL independently track its own count
- **AND** both SHALL take exactly 2 items from their respective inputs

### Requirement: Transducer factories are stateless and reusable

Transducer factories (e.g., `filtering(pred)`, `taking(n)`, `mapping(fn)`) SHALL return transducer values that are reusable. Each application of a transducer to a reducer (wrapping) SHALL produce independent state.

- The transducer value itself is stateless and can be stored, passed around, and applied multiple times
- Each wrapping creates a fresh closure with independent mutable state
- Wrapping the same transducer twice produces two independent reducer wrappers

#### Scenario: Reusing a transducer value

- **WHEN** `xf = po.taking(2)` is created and `r1 = xf(to_list_reducer)` and `r2 = xf(to_list_reducer)` are created
- **THEN** r1 and r2 SHALL have independent counters
- **AND** reducing `[1, 2, 3, 4, 5]` through r1 SHALL yield `[1, 2]`
- **AND** reducing `[1, 2, 3, 4, 5]` through r2 SHALL also yield `[1, 2]`

#### Scenario: Transducer in reusable pipeline

- **WHEN** `pipeline = po.where(Person.age > 25) | po.taking(3)` is created
- **THEN** `df1 | pipeline` and `df2 | pipeline` each materialized SHALL get independent taking(3) state

### Requirement: Complete propagation order in transducer composition

In composed transducers `xf1 | xf2`, the complete() call SHALL propagate from outermost to innermost:

1. xf1's complete() is called first (outermost in wrapping order)
2. xf1's complete() calls xf2's complete() on appropriate state
3. xf2's complete() calls the inner reducer's complete()

Each layer's complete() sees the accumulator state it produced during step() calls. If a layer has buffered state (e.g., a batching transducer), it flushes during complete() before propagating inward.

When Reduced propagates outward during step(), the subsequent complete() call still follows this outermost-first ordering.

#### Scenario: Complete ordering with taking

- **WHEN** `xf = mapping(str.upper) | taking(2)` is applied to `to_list` reducer and reduces `["a", "b", "c"]`
- **THEN** mapping's complete() SHALL be called, which calls taking's complete(), which calls to_list's complete()
- **AND** the result SHALL be `["A", "B"]`

### Requirement: Stateful transducer state independence verified via property-based testing

Property-based tests MUST verify that stateful transducers (taking, dropping, distinct) produce identical results on repeated applications:

For any stateful transducer xf and any input sequence xs:
- `po.reduce(po.to_list, xs, transducer=xf)` called twice with the same inputs produces identical results
- Two independent wrappings of the same transducer on overlapping data produce correct independent results

#### Scenario: taking produces same result on repeated reduce

- **WHEN** `xf = po.taking(3)` and `data = [1, 2, 3, 4, 5]`
- **THEN** `po.reduce(po.to_list, data, transducer=xf)` called twice SHALL produce `[1, 2, 3]` both times

## Requirements

### Requirement: Transducer as reducer transformer

A transducer SHALL be a callable that transforms one reducer into another.
The transducer SHALL wrap all three phases (init, step, complete) of the
inner reducer as defined in `reducer/spec.md`.

In a DataFrame pipeline, transducers SHALL operate on items that satisfy the
materialized row contract defined in `row-model/spec.md`.

#### Scenario: Filtering transducer

- **WHEN** a `filtering(pred)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL only accumulate items where `pred` is true

#### Scenario: Mapping transducer

- **WHEN** a `mapping(f)` transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL accumulate `f(item)` for each item

#### Scenario: Reduce with transducer re-wraps on each call

- **WHEN** `po.reduce(reducer, collection, transducer=xf)` is called
- **THEN** `xf(reducer)` SHALL produce a fresh wrapped reducer for that call

### Requirement: Transducer-reducer compatibility laws

Transducers wrapping reducers SHALL satisfy the following laws:

1. **Init preservation**: `xf(r).init()` SHALL equal `r.init()` by default
2. **Complete propagation**: `xf(r).complete(s)` SHALL call `r.complete(...)` on some state
3. **Reduced propagation**: if inner `step` returns `Reduced`, outer SHALL propagate it

#### Scenario: Init preserved

- **WHEN** `filtering(pred)` wraps `to_list`
- **THEN** `filtering(pred)(to_list).init()` SHALL equal `to_list.init()`

#### Scenario: Complete propagated

- **WHEN** any transducer wraps a `mean` reducer
- **THEN** `complete` SHALL be called on the inner reducer to finalize the result

### Requirement: Transducer composition is left-to-right

Transducers SHALL compose via the `|` operator in left-to-right data flow
order: `xf1 | xf2` means apply `xf1` first, then `xf2`.

Composition SHALL be associative: `(a | b) | c` equals `a | (b | c)`.

Internally, left-to-right data flow requires right-to-left function composition:
`(xf1 | xf2)(reducer) == xf1(xf2(reducer))`.

#### Scenario: Left-to-right data flow

- **WHEN** `filtering(lambda x: x > 0) | mapping(lambda x: x * 10)` is composed
- **THEN** applying it to `[-1, 2, -3, 4]` with `to_list` SHALL produce `[20, 40]`
  (filter first: `[2, 4]`, then map: `[20, 40]`)

#### Scenario: Non-commutative order matters

- **WHEN** `mapping(lambda x: x - 3) | filtering(lambda x: x > 0)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2]` (map first: `[-2, -1, 0, 1, 2]`, then filter: `[1, 2]`)

#### Scenario: Composition is associative

- **WHEN** transducers `a`, `b`, `c` are composed as `(a | b) | c` and `a | (b | c)`
- **THEN** both SHALL produce identical results for any input

### Requirement: Identity transducer

The system SHALL provide an identity transducer that passes through the
inner reducer unchanged. `comp()` with no arguments SHALL return the identity.
The identity transducer SHALL be the neutral element of composition (monoid identity).

#### Scenario: Identity leaves reducer unchanged

- **WHEN** the identity transducer wraps a `to_list` reducer
- **THEN** the resulting reducer SHALL behave identically to `to_list`

#### Scenario: Identity is neutral element

- **WHEN** `identity | xf` and `xf | identity` are composed
- **THEN** both SHALL produce the same results as `xf` alone

### Requirement: Core transducers (low-level)

The system SHALL provide the following built-in transducers that work with
plain Python callables. These are the low-level building blocks:
- `filtering(predicate)` — keep items where predicate is true
- `mapping(function)` — transform each item
- `taking(n)` — take first n items (early termination via Reduced)
- `dropping(n)` — skip first n items

#### Scenario: Taking with early termination

- **WHEN** `taking(2)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2]` and items 3-5 SHALL NOT be processed

#### Scenario: Dropping skips items

- **WHEN** `dropping(2)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[3, 4, 5]`

#### Scenario: Taking with zero returns empty

- **WHEN** `taking(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[]`

#### Scenario: Taking with negative raises error

- **WHEN** `taking(-1)` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Dropping with zero is identity

- **WHEN** `dropping(0)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[1, 2, 3]`

#### Scenario: Dropping with negative raises error

- **WHEN** `dropping(-1)` is called
- **THEN** the system SHALL raise a `ValueError`

#### Scenario: Dropping more than input length

- **WHEN** `dropping(100)` is applied to `[1, 2, 3]`
- **THEN** the result SHALL be `[]`

#### Scenario: Composed stateful transducers

- **WHEN** `taking(3) | taking(5)` is applied to `[1, 2, 3, 4, 5]`
- **THEN** the result SHALL be `[1, 2, 3]` (taking(3) emits 3 items,
  taking(5) passes all 3 through)

### Requirement: Stateful transducers SHALL produce fresh closure state per wrapping

Stateful transducers (e.g., `taking(n)`, `dropping(n)`) SHALL manage mutable
state in closure variables captured when the transducer wraps a reducer.
Each call to the transducer (i.e., each wrapping of a new reducer) SHALL
produce fresh, independent state.

#### Scenario: taking produces independent state per wrapping

- **WHEN** `taking(2)` wraps `to_list` twice (two separate calls)
- **THEN** each wrapped reducer SHALL independently track its own count
- **AND** both SHALL take exactly 2 items from their respective inputs

### Requirement: Transducer factories are stateless and reusable

Transducer factories (e.g., `filtering(pred)`, `taking(n)`, `mapping(fn)`) SHALL return transducer values that are reusable. Each application of a transducer to a reducer (wrapping) SHALL produce independent state.

- The transducer value itself is stateless and can be stored, passed around, and applied multiple times
- Each wrapping creates a fresh closure with independent mutable state
- Wrapping the same transducer twice produces two independent reducer wrappers

#### Scenario: Reusing a transducer value

- **WHEN** `xf = po.taking(2)` is created and `r1 = xf(to_list_reducer)` and `r2 = xf(to_list_reducer)` are created
- **THEN** r1 and r2 SHALL have independent counters
- **AND** reducing `[1, 2, 3, 4, 5]` through r1 SHALL yield `[1, 2]`
- **AND** reducing `[1, 2, 3, 4, 5]` through r2 SHALL also yield `[1, 2]`

#### Scenario: Transducer in reusable pipeline

- **WHEN** `pipeline = po.where(Person.age > 25) | po.taking(3)` is created
- **THEN** `df1 | pipeline` and `df2 | pipeline` each materialized SHALL get independent taking(3) state

### Requirement: Complete propagation order in transducer composition

In composed transducers `xf1 | xf2`, the complete() call SHALL propagate from outermost to innermost:

1. xf1's complete() is called first (outermost in wrapping order)
2. xf1's complete() calls xf2's complete() on appropriate state
3. xf2's complete() calls the inner reducer's complete()

Each layer's complete() sees the accumulator state it produced during step() calls. If a layer has buffered state (e.g., a batching transducer), it flushes during complete() before propagating inward.

When Reduced propagates outward during step(), the subsequent complete() call still follows this outermost-first ordering.

#### Scenario: Complete ordering with taking

- **WHEN** `xf = mapping(str.upper) | taking(2)` is applied to `to_list` reducer and reduces `["a", "b", "c"]`
- **THEN** mapping's complete() SHALL be called, which calls taking's complete(), which calls to_list's complete()
- **AND** the result SHALL be `["A", "B"]`

### Requirement: Stateful transducer state independence verified via property-based testing

Property-based tests MUST verify that stateful transducers (taking, dropping, distinct) produce identical results on repeated applications:

For any stateful transducer xf and any input sequence xs:
- `po.reduce(po.to_list, xs, transducer=xf)` called twice with the same inputs produces identical results
- Two independent wrappings of the same transducer on overlapping data produce correct independent results

#### Scenario: taking produces same result on repeated reduce

- **WHEN** `xf = po.taking(3)` and `data = [1, 2, 3, 4, 5]`
- **THEN** `po.reduce(po.to_list, data, transducer=xf)` called twice SHALL produce `[1, 2, 3]` both times

## Requirements
