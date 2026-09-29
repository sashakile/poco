---
id: spec
kind: intent
statement: "WHEN a pipeline step constructor receives a non-Expr argument THE system SHALL raise TypeError with guidance and SHALL carry the renumbered non-colliding traceability tag"
---

# Pipeline step Expr validation

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| fx.expr_arg_validation | invariant | `where`, `select`, `derive`, `sort_by`, `distinct`, and `groupby` constructors validate that arguments are Expr instances at construction time; non-Expr arguments raise `TypeError` with guidance | [[spec]] |
| fx.tag_renumber | advisory | The requirement's tag is renumbered from the colliding `[HUM-008 / FAIL-007]` to `[HUM-009 / FAIL-008]` so tooling and cross-references distinguish it from the materialization-context requirement | [[spec]] |

## Model

### States

- `constructed`
- `rejected`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_validate | constructed | rejected | [[spec.fx.expr_arg_validation]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.expr_arg_validation | unit | [[spec.fx.expr_arg_validation]] | constructor calls with bool and other non-Expr values | `TypeError` with guidance is raised at construction |
| p.tag_renumber | unit | [[spec.fx.tag_renumber]] | traceability tag scans | `[HUM-009 / FAIL-008]` appears; `[HUM-008 / FAIL-007]` no longer collides |

## Purpose

Catch instance-vs-schema-class mistakes at construction time and remove a
tag collision that made cross-references ambiguous.

## MODIFIED Requirements

### Requirement: Pipeline steps validate Expr types at construction

High-level pipeline step constructors SHALL validate, at construction time,
that the arguments to `where`, `select`, `derive`, `sort_by`, `distinct`, and
`groupby` are `Expr` instances. Non-`Expr` arguments SHALL raise `TypeError`
with guidance.

This requirement was previously tagged `[HUM-008 / FAIL-007]`, which
collided with the unrelated "Materialization errors include pipeline
context" requirement. It is renumbered to `[HUM-009 / FAIL-008]`, the first
unused tag pair in the project's traceability sequence, so the two
requirements are distinguishable in tooling and cross-references.

#### Scenario: where receives bool instead of Expr

- **GIVEN** `person = Person(name="Alice", age=35)`
- **WHEN** `po.where(person.age > 30)` is called (`person.age > 30` evaluates
  to `True`, a `bool`)
- **THEN** the system SHALL raise a `TypeError`: "where() expected Expr, got
  bool. Use the schema class (Person.age) for expressions, not an instance."

## Requirements

### Requirement: Pipeline steps validate Expr types at construction

High-level pipeline step constructors SHALL validate, at construction time,
that the arguments to `where`, `select`, `derive`, `sort_by`, `distinct`, and
`groupby` are `Expr` instances. Non-`Expr` arguments SHALL raise `TypeError`
with guidance.

This requirement was previously tagged `[HUM-008 / FAIL-007]`, which
collided with the unrelated "Materialization errors include pipeline
context" requirement. It is renumbered to `[HUM-009 / FAIL-008]`, the first
unused tag pair in the project's traceability sequence, so the two
requirements are distinguishable in tooling and cross-references.

#### Scenario: where receives bool instead of Expr

- **GIVEN** `person = Person(name="Alice", age=35)`
- **WHEN** `po.where(person.age > 30)` is called (`person.age > 30` evaluates
  to `True`, a `bool`)
- **THEN** the system SHALL raise a `TypeError`: "where() expected Expr, got
  bool. Use the schema class (Person.age) for expressions, not an instance."

## Requirements
