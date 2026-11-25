---
id: lean.laws
kind: intent
statement: "THE system SHALL state the poco reducer and transducer laws as Lean theorems over the reference kernel and prove every one of them sorry-free with statements reviewed against the spec prose in both directions"
---

# Lean law theorems

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| cl.formalize | invariant | The twin states as theorems over the kernel semantics the law clauses the poco specs already declare: reducer determinism, resumability (`reduce(xs ++ ys) == resume(ys, state(xs))`), Reduced validity, empty-input validity for total reducers, transducer identity, and associativity of transducer composition; the proofs are universal over arbitrary reducers, transducers, and item lists, not sampled cases | [[lean.laws]] |
| cl.sorry_free | invariant | Every law theorem compiles sorry-free: the build fails on any `sorry` warning, no theorem rests on `sorryAx`, and no new axiom declaration exists anywhere in the twin sources | [[lean.laws]] |
| cl.statement_review | invariant | Each theorem statement is reviewed against every clause of the prose it formalizes in both directions: a hypothesis set that forces one side of a claimed equality to resolve is revised before merge, so no certificate is narrower than its prose claim | [[lean.laws]] |

## Model

### States

- `stated`
- `proved`
- `revised`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_prove | stated | proved | [[lean.laws.cl.sorry_free]] |
| t_review | proved | revised | [[lean.laws.cl.statement_review]] |
| t_restate | revised | stated | [[lean.laws.cl.formalize]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.laws | law | [[lean.laws.cl.formalize]] | arbitrary reducers, transducers, and item lists at the type level | **identity:** transducer composition admits an identity element that every transducer absorbs; **associativity:** composing transducers in any bracketing yields folds that agree on every list; **determinism:** equal fold inputs give equal step results; **resumability:** folding `xs ++ ys` equals resuming from the state after `xs`; **reduced_validity:** a Reduced shortcut completes validly; **empty_input:** total reducers complete validly on the empty list |
| p.sorry_free | unit | [[lean.laws.cl.sorry_free]] | the twin build and axiom report | the build emits no sorry warning and every audited theorem's axioms stay in the allowed set |
| p.statement_review | unit | [[lean.laws.cl.statement_review]] | each theorem versus its prose clause | every prose clause is covered by a theorem direction, and no theorem hypothesis is stronger than the prose |

## Purpose

Turn the poco laws from sampled property tests into machine-checked universal
statements — the corpus samples, the theorems quantify.

## ADDED Requirements

### Requirement: Law formalization

The system SHALL state the poco laws — reducer determinism, resumability,
Reduced validity, empty-input validity for total reducers, transducer
identity, and associativity of transducer composition — as Lean theorems
over the kernel semantics, universal over arbitrary reducers, transducers,
and item lists.

#### Scenario: Resumability holds for arbitrary splits

- **WHEN** the resumability theorem is instantiated at any list split `xs`
  and `ys`
- **THEN** the fold of `xs ++ ys` SHALL equal the resumed fold without case
  sampling

#### Scenario: Composition associativity at any bracketing

- **WHEN** three transducers are composed in either bracketing
- **THEN** the theorem SHALL yield equal folds over every list

### Requirement: Sorry-free proofs

The system SHALL land every law theorem sorry-free: the build fails on any
`sorry` warning and no theorem depends on `sorryAx` or a user-declared axiom.

#### Scenario: Planted sorry fails the build

- **WHEN** a theorem body is replaced by `sorry`
- **THEN** the build SHALL emit a sorry warning and the axiom gate SHALL fail

### Requirement: Statement review in both directions

The system SHALL review every theorem statement against the prose clause it
formalizes in both directions before merge, revising any hypothesis set that
forces one side of a claimed equality to resolve.

#### Scenario: One-sided implication is revised

- **WHEN** a theorem proves a no-violation claim only for inputs where the
  left side resolves, while the prose covers both sides
- **THEN** the review SHALL flag the gap and the statement SHALL be widened
  or the prose narrowed before merge

## Requirements

### Requirement: Law formalization

The system SHALL state the poco laws — reducer determinism, resumability,
Reduced validity, empty-input validity for total reducers, transducer
identity, and associativity of transducer composition — as Lean theorems
over the kernel semantics, universal over arbitrary reducers, transducers,
and item lists.

### Requirement: Sorry-free proofs

The system SHALL land every law theorem sorry-free: the build fails on any
`sorry` warning and no theorem depends on `sorryAx` or a user-declared axiom.

### Requirement: Statement review in both directions

The system SHALL review every theorem statement against the prose clause it
formalizes in both directions before merge, revising any hypothesis set that
forces one side of a claimed equality to resolve.
