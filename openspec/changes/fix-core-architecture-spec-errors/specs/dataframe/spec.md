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
