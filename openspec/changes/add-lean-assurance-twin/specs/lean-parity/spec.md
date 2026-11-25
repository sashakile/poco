---
id: lean.parity
kind: intent
statement: "THE system SHALL provide a lean-parity oracle that dynamically enumerates a fixture corpus, runs the Lean kernel and the Python poco core as subprocess counterparts sharing no linked code, compares normalized semantic results, and treats every divergence as an attributed, never-suppressed defect"
---

# Lean parity oracle

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| cp.enumeration | invariant | The oracle enumerates the fixture corpus dynamically at run time from the fixtures directory tree; no expected count, fixture list, or skip list is hardcoded | [[lean.parity]] |
| cp.counterpart | invariant | The oracle runs the Python poco core as a subprocess (`python -m poco_parity --json`) and the Lean kernel in-process; the two implementations share no linked code at run time | [[lean.parity]] |
| cp.normalized | invariant | Comparison is over normalized semantic results — materialized columns as ordered tagged cells, inferred schema, and error-taxonomy entries compared as multisets — never raw stdout bytes, repr text, or message wording | [[lean.parity]] |
| cp.report | invariant | The report separates `trivially_agreeing` (both sides empty) from `findings_bearing_agreeing` (equal and non-empty); a zero findings-bearing count is a red result, not a pass, and rejected documents are surfaced as `skipped_parse` with their first stderr line rather than filtered away | [[lean.parity]] |
| cp.divergence | invariant | A divergence is never merged away or suppressed: it is attributed to a lean-model defect or a python-core defect, filed as a beads ticket, and the oracle exits 1 while any divergence remains; a dispositions file may annotate attribution but never silence a finding | [[lean.parity]] |

## Model

### States

- `enumerated`
- `agreeing`
- `diverged`
- `skipped`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_agree | enumerated | agreeing | [[lean.parity.cp.normalized]] |
| t_diverge | enumerated | diverged | [[lean.parity.cp.divergence]] |
| t_skip | enumerated | skipped | [[lean.parity.cp.report]] |
| t_attribute | diverged | enumerated | [[lean.parity.cp.divergence]] |
| t_reject | skipped | enumerated | [[lean.parity.cp.enumeration]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.enumeration | unit | [[lean.parity.cp.enumeration]] | fixtures added and removed from the corpus | the oracle's document count tracks the tree with no list edits |
| p.counterpart | unit | [[lean.parity.cp.counterpart]] | oracle run | the Python side runs as a subprocess over the mirror JSON; no shared linked code |
| p.normalized | unit | [[lean.parity.cp.normalized]] | outputs differing only in message wording or formatting | such outputs compare equal; semantic differences never compare equal |
| p.report | unit | [[lean.parity.cp.report]] | corpora of empty and non-empty results | the report splits trivially from findings-bearing agreement; zero findings-bearing is red |
| p.skipped | unit | [[lean.parity.cp.report]] | documents the Python side rejects | each is recorded as skipped_parse with its first stderr line |
| p.divergence | unit | [[lean.parity.cp.divergence]] | injected semantic mismatches | exit 1 with attribution; dispositions annotate but never suppress |

## Purpose

Make Lean semantics and the shipped Python core answer for each other on a
shared corpus, so drift between them is a loud attributed event instead of a
silent fork.

## ADDED Requirements

### Requirement: Dynamic enumeration with subprocess counterpart

The oracle SHALL enumerate the fixture corpus dynamically at run time and
run the Python poco core as a subprocess over the trusted mirror, sharing no
linked code with the Lean kernel.

#### Scenario: Corpus growth is tracked without edits

- **WHEN** a new fixture document is added to the corpus tree
- **THEN** the next oracle run SHALL enumerate and compare it with no
  configuration change

### Requirement: Normalized semantic comparison

The oracle SHALL compare materialized columns, inferred schema, and error
taxonomy entries as normalized multisets, never raw bytes or presentation
text.

#### Scenario: Wording-only difference agrees

- **WHEN** the two sides return semantically identical results with different
  error message wording
- **THEN** the oracle SHALL record agreement

### Requirement: Report separates trivial from findings-bearing agreement

The oracle SHALL report `trivially_agreeing` and `findings_bearing_agreeing`
separately and SHALL treat a zero findings-bearing count as a red result.

#### Scenario: All-empty corpus is red

- **WHEN** every compared document produces empty results on both sides
- **THEN** the report SHALL show zero findings-bearing agreement and the run
  SHALL NOT be presented as a passing parity signal

### Requirement: Skipped parse route

Documents the Python side rejects SHALL be recorded as `skipped_parse` with
their first stderr line, never as agreement or divergence.

#### Scenario: Malformed fixture is skipped, not agreed

- **WHEN** the Python counterpart rejects a fixture's mirror projection
- **THEN** the oracle SHALL record it under skipped_parse and SHALL NOT count
  it as an agreement

### Requirement: Never-suppressed divergence protocol

Every divergence SHALL be attributed to a lean-model defect or a
python-core defect, filed as a beads ticket, and SHALL keep the oracle exit
code at 1 until the semantic mismatch is gone; a dispositions file may
annotate attribution but never suppress a divergence.

#### Scenario: Annotated divergence stays red

- **WHEN** a divergence exists and the dispositions file maps it to an
  attribution and ticket
- **THEN** the oracle SHALL exit 1 while the divergence remains

## Requirements

### Requirement: Dynamic enumeration with subprocess counterpart

The oracle SHALL enumerate the fixture corpus dynamically at run time and
run the Python poco core as a subprocess over the trusted mirror, sharing no
linked code with the Lean kernel.

### Requirement: Normalized semantic comparison

The oracle SHALL compare materialized columns, inferred schema, and error
taxonomy entries as normalized multisets, never raw bytes or presentation
text.

### Requirement: Report separates trivial from findings-bearing agreement

The oracle SHALL report `trivially_agreeing` and `findings_bearing_agreeing`
separately and SHALL treat a zero findings-bearing count as a red result.

### Requirement: Skipped parse route

Documents the Python side rejects SHALL be recorded as `skipped_parse` with
their first stderr line, never as agreement or divergence.

### Requirement: Never-suppressed divergence protocol

Every divergence SHALL be attributed to a lean-model defect or a
python-core defect, filed as a beads ticket, and SHALL keep the oracle exit
code at 1 until the semantic mismatch is gone; a dispositions file may
annotate attribution but never suppress a divergence.
