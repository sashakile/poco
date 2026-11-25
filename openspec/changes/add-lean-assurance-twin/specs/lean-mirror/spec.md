---
id: lean.mirror
kind: intent
statement: "THE system SHALL define a trusted mirror document contract that projects poco data documents into canonical stdlib JSON with dtype-tagged dense cells, total projection and decode, and named rejection of mirror-invalid documents"
---

# Lean trusted mirror contract

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| cm.contract | invariant | The trusted mirror is a stdlib-JSON document with canonical field order: schema name, columns in declared order (name plus dtype), and rows as dense lists of equal length; `project` and `decode` are total over mirror-valid documents | [[lean.mirror]] |
| cm.dtype_tags | invariant | Every cell carries an unambiguous dtype tag over {int, float, str, bool, null}; int and float are distinct tags; null is the only missing-value marker and no other value may wear it | [[lean.mirror]] |
| cm.canonical_order | invariant | Projection preserves schema column order and document row order; dense row ids are assigned in row order; decoding the projection reproduces the document's semantic content exactly | [[lean.mirror]] |
| cm.rejection | invariant | Mirror-invalid documents (ragged rows, unknown dtype tags, missing or extra fields) fail projection with a named error identifying the first offending position; there is no silent coercion or truncation | [[lean.mirror]] |

## Model

### States

- `raw_document`
- `projected`
- `rejected`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_project | raw_document | projected | [[lean.mirror.cm.canonical_order]] |
| t_reject | raw_document | rejected | [[lean.mirror.cm.rejection]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.roundtrip | unit | [[lean.mirror.cm.contract]] | mirror-valid documents | decode(project(doc)) equals doc's semantic content |
| p.dtype_tags | unit | [[lean.mirror.cm.dtype_tags]] | cells of every tagged dtype | each cell round-trips under exactly one tag; int and float never merge |
| p.order | unit | [[lean.mirror.cm.canonical_order]] | documents with varied column and row orders | projection output order equals input order; row ids are dense and ascending |
| p.rejection | unit | [[lean.mirror.cm.rejection]] | ragged rows, unknown tags, missing fields | projection fails with the named error and the offending position |

## Purpose

Give the Lean twin and the Python counterpart a single written data contract
so parity compares one well-defined shape, not two ad-hoc serializations.

## ADDED Requirements

### Requirement: Trusted mirror document

The system SHALL define a trusted mirror JSON document with canonical field
order — schema name, columns (name and dtype) in declared order, rows as
dense equal-length cell lists — such that projection and decode are total
over mirror-valid documents and `decode(project(doc))` reproduces the
document's semantic content.

#### Scenario: Round trip

- **WHEN** a mirror-valid document is projected and decoded again
- **THEN** the decoded document SHALL equal the original semantic content

#### Scenario: Dense rows

- **WHEN** a document declares 3 rows of 2 cells each
- **THEN** the projection SHALL contain exactly 3 dense rows of 2 tagged cells

### Requirement: Dtype-tagged cells

The system SHALL tag every mirror cell with exactly one dtype tag from {int,
float, str, bool, null}, where int and float are distinct tags and null is
the only missing-value marker.

#### Scenario: Int and float are distinct

- **WHEN** a column holds the int cell `3` and the float cell `3.0`
- **THEN** the projection SHALL carry two distinct tags and neither SHALL
  decode as the other

### Requirement: Named rejection of mirror-invalid documents

The system SHALL fail projection with a named error identifying the first
offending position for ragged rows, unknown dtype tags, or missing fields,
without silent coercion or truncation.

#### Scenario: Ragged rows are rejected

- **WHEN** a document declares a row shorter than the schema width
- **THEN** projection SHALL fail with a named error citing the row position
  and SHALL NOT produce a truncated projection

## Requirements

### Requirement: Trusted mirror document

The system SHALL define a trusted mirror JSON document with canonical field
order — schema name, columns (name and dtype) in declared order, rows as
dense equal-length cell lists — such that projection and decode are total
over mirror-valid documents and `decode(project(doc))` reproduces the
document's semantic content.

### Requirement: Dtype-tagged cells

The system SHALL tag every mirror cell with exactly one dtype tag from {int,
float, str, bool, null}, where int and float are distinct tags and null is
the only missing-value marker.

### Requirement: Named rejection of mirror-invalid documents

The system SHALL fail projection with a named error identifying the first
offending position for ragged rows, unknown dtype tags, or missing fields,
without silent coercion or truncation.
