---
id: lean.kernel
kind: intent
statement: "THE system SHALL implement a Lean 4 reference kernel of stdlib-only total functions mirroring the poco schema, instance, expression, reducer, transducer, and materialization contracts"
---

# Lean reference kernel

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| ck.modules | invariant | The kernel modules `Po.Schema`, `Po.Instance`, `Po.Expr`, `Po.Reducer`, `Po.Transducer`, and `Po.Materialize` mirror the poco contracts: the shared row contract, schema validation, expression evaluation over rows, the three-phase reducer with `Reduced` early termination, left-to-right transducer composition, and the materialization walk over a mirror document | [[lean.kernel]] |
| ck.totality | invariant | Every kernel function is total over mirror-valid input: it returns a value or a typed finding/error constructor; the kernel raises no exceptions, performs no partial pattern matches, and never escapes its input domain silently | [[lean.kernel]] |
| ck.std_only | invariant | Kernel modules depend only on the Lean prelude and standard library; they import nothing from the Lean metaprogramming API or Mathlib, and nothing in the `poco` package depends on the kernel at runtime | [[lean.kernel]] |
| ck.named_helpers | invariant | Each law-bearing walk exposes a named function per family (per-reducer fold state, per-transducer composition step) so theorems can name the family instead of restating an anonymous body | [[lean.kernel]] |

## Model

### States

- `mirror_document`
- `built`
- `evaluated`
- `materialized`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_build | mirror_document | built | [[lean.kernel.ck.modules]] |
| t_eval | built | evaluated | [[lean.kernel.ck.totality]] |
| t_materialize | evaluated | materialized | [[lean.kernel.ck.totality]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.build_total | unit | [[lean.kernel.ck.modules]] | mirror documents, valid and invalid | build returns an instance or a typed error constructor, never a crash |
| p.fold_total | unit | [[lean.kernel.ck.totality]] | reducers, item lists, early-termination inputs | the fold returns a final result for every input; complete runs exactly once |
| p.isolation | unit | [[lean.kernel.ck.std_only]] | kernel import graph | imports stay inside prelude and std; the poco package imports nothing from the kernel |
| p.named_helpers | unit | [[lean.kernel.ck.named_helpers]] | kernel walks that would inline anonymous lambdas | each law-bearing family is a callable named helper, provable without restating a body |

## Purpose

Be the external reference semantics the proofs quantify over and the parity
oracle runs — a small total model of poco's core, readable against the specs.

## ADDED Requirements

### Requirement: Kernel modules mirror the poco contracts

The system SHALL provide `Po.Schema`, `Po.Instance`, `Po.Expr`, `Po.Reducer`,
`Po.Transducer`, and `Po.Materialize` as Lean modules mirroring the poco row
contract, schema validation, expression evaluation, three-phase reducer with
`Reduced` early termination, left-to-right transducer composition, and the
materialization walk.

#### Scenario: Three-phase fold mirrors the reducer protocol

- **WHEN** the kernel folds a reducer over a list whose third step returns
  `Reduced`
- **THEN** the fold SHALL stop at the third item and complete with the
  unwrapped accumulator, exactly as `po.reduce` does

### Requirement: Kernel totality

The system SHALL make every kernel function total over mirror-valid input,
returning a value or a typed error constructor, with no exceptions and no
silent escapes.

#### Scenario: Invalid input returns a typed error

- **WHEN** the kernel evaluates an expression referencing an unknown column
- **THEN** evaluation SHALL return a typed unknown-column error constructor
  rather than failing to terminate or crashing

### Requirement: Standard library only and runtime-decoupled

The system SHALL keep kernel modules within the Lean prelude and standard
library (no metaprogramming API, no Mathlib) and SHALL keep the `poco`
package free of any runtime dependency on the kernel.

#### Scenario: Import audit

- **WHEN** the kernel's import graph is inspected
- **THEN** every import SHALL resolve to the Lean prelude or standard library
  and no `poco/` module SHALL import the kernel

## Requirements

### Requirement: Kernel modules mirror the poco contracts

The system SHALL provide `Po.Schema`, `Po.Instance`, `Po.Expr`, `Po.Reducer`,
`Po.Transducer`, and `Po.Materialize` as Lean modules mirroring the poco row
contract, schema validation, expression evaluation, three-phase reducer with
`Reduced` early termination, left-to-right transducer composition, and the
materialization walk.

### Requirement: Kernel totality

The system SHALL make every kernel function total over mirror-valid input,
returning a value or a typed error constructor, with no exceptions and no
silent escapes.

### Requirement: Standard library only and runtime-decoupled

The system SHALL keep kernel modules within the Lean prelude and standard
library (no metaprogramming API, no Mathlib) and SHALL keep the `poco`
package free of any runtime dependency on the kernel.
