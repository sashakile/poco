---
id: lean.gates
kind: intent
statement: "THE system SHALL gate the assurance twin with a set-asserting axiom audit script, a pinned Lean toolchain, a just lean recipe kept out of the local check chain, a dedicated lean CI job that runs the same gates on every pull request touching the twin, and a recorded extend, hold, or retire stop-gate decision with cost and benefit accounting"
---

# Lean assurance gates

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| cg.axiom_audit | invariant | `scripts/check-lean-axioms.sh` fails the build on any `declaration uses 'sorry'` warning, asserts every audited theorem's axiom set is inside {propext, Classical.choice, Quot.sound} reporting any unexpected axiom by name, scans every twin source file for `axiom` declarations, and exposes a `--file` seam so the gate is red-tested against planted bad files | [[lean.gates]] |
| cg.pinning | invariant | The twin builds under the Lean toolchain pinned by `lean/lean-toolchain` provisioned through elan; no step installs an unpinned or rolling toolchain version | [[lean.gates]] |
| cg.just_recipe | invariant | `just lean` runs the Lake build, the parity oracle, and the axiom audit in one command and stays out of the local `just check` chain because the Lean toolchain is provisioned independently of the Python toolchain; this is a local-provisioning separation, not a CI exemption | [[lean.gates]] |
| cg.ci_enforcement | invariant | `.github/workflows/ci.yml` carries a dedicated `lean` job that installs elan, builds under the toolchain pinned by `lean/lean-toolchain`, syncs the Python environment, and runs `just lean`; the job is triggered by changes under `lean/`, `poco/`, `fixtures/parity/`, or `scripts/check-lean-axioms.sh`; while `lean/lean-toolchain` does not exist the job skips unrelated paths and fails loudly naming the missing pinned toolchain when twin paths are touched anyway (orphan paths); with the twin present a `sorry` regression or parity divergence fails the pull request | [[lean.gates]] |
| cg.stop_gate | invariant | After the proof phase a stop-gate decision — extend, hold, or retire — is recorded under `ledger/lean/` with cost/benefit accounting covering what the proofs bought versus what fixture parity already pinned; absence of a decision is drift, not neutrality | [[lean.gates]] |

## Model

### States

- `unchecked`
- `green`
- `red`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_pass | unchecked | green | [[lean.gates.cg.axiom_audit]] |
| t_fail | unchecked | red | [[lean.gates.cg.axiom_audit]] |
| t_recheck | red | unchecked | [[lean.gates.cg.axiom_audit]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.audit_red_tests | unit | [[lean.gates.cg.axiom_audit]] | planted bad files: a sorry body, a user axiom, a subset audit | each planted case turns the gate red with a named report |
| p.pinning | unit | [[lean.gates.cg.pinning]] | fresh clones | the build resolves exactly the pinned toolchain via elan |
| p.recipe | unit | [[lean.gates.cg.just_recipe]] | `just lean` on a clean and a dirty tree | one command runs build, parity, and audit; exit codes propagate |
| p.stop_gate | unit | [[lean.gates.cg.stop_gate]] | the post-proof phase | a ledger record exists naming the outcome with cost and benefit accounting |
| p.ci_enforcement | unit | [[lean.gates.cg.ci_enforcement]] | pull requests with planted `sorry` bodies or injected divergences, unrelated changes, and orphan twin paths, across twin-present and twin-absent trees | planted failures are red with the twin present; unrelated changes skip while the twin is absent; orphan twin paths fail loudly either way |

## Purpose

Make the twin's claims self-enforcing: proof claims cannot rest on hidden
axioms, the environment cannot drift, and the assurance outcome must be a
recorded decision rather than silence.

## ADDED Requirements

### Requirement: Set-asserting axiom audit

The system SHALL provide `scripts/check-lean-axioms.sh` which fails on any
sorry warning, asserts each audited theorem's axiom set is inside {propext,
Classical.choice, Quot.sound} reporting unexpected axioms by name, scans all
twin sources for `axiom` declarations, and is itself red-tested via a
planted-bad-file seam.

#### Scenario: Planted user axiom is caught by name

- **WHEN** a planted source file declares an `axiom` and a theorem cites it
- **THEN** the audit SHALL fail reporting the axiom and the affected theorem
  by name, not merely an unspecified failure

### Requirement: Pinned toolchain provisioning

The system SHALL pin the twin's Lean toolchain in `lean/lean-toolchain`,
provisioned through elan, with no unpinned or rolling installs anywhere in
the twin's workflow.

#### Scenario: Fresh clone reproduces the environment

- **WHEN** the twin is built from a fresh clone with elan installed
- **THEN** the build SHALL use exactly the pinned toolchain version

### Requirement: Just lean recipe and stop-gate record

The system SHALL provide `just lean` running build, parity oracle, and axiom
audit, kept out of the local `just check` chain, and SHALL record an extend,
hold, or retire stop-gate decision with cost/benefit accounting under
`ledger/lean/` after the proof phase.

#### Scenario: Stop gate records a decision

- **WHEN** the proof phase completes
- **THEN** `ledger/lean/` SHALL contain a decision record naming the outcome
  and its cost/benefit accounting

### Requirement: Continuous-integration enforcement of the gates

The system SHALL run the twin's gates in CI through a dedicated `lean` job
that installs elan, builds under the pinned `lean/lean-toolchain`, and runs
`just lean`, triggered by changes to the twin or the Python core, skipped
for unrelated changes while the twin is absent, and failing loudly when the
twin is touched while absent, so that a `sorry` regression, a parity
divergence, or orphan twin paths fail the pull request.

#### Scenario: Planted sorry blocks the pull request

- **WHEN** a pull request touching `lean/` plants a `sorry` in a theorem
- **THEN** the `lean` CI job SHALL fail and the pull request SHALL NOT be
  mergeable while it is red

#### Scenario: Unrelated changes skip the job

- **WHEN** a pull request touches only files outside `lean/`, `poco/`,
  `fixtures/parity/`, and `scripts/check-lean-axioms.sh`
- **THEN** the `lean` CI job SHALL be skipped

#### Scenario: Orphan twin paths fail loudly

- **WHEN** a pull request touches `lean/**` paths while `lean/lean-toolchain`
  does not exist
- **THEN** the `lean` CI job SHALL fail naming the missing pinned toolchain
  rather than silently skipping

## Requirements

### Requirement: Set-asserting axiom audit

The system SHALL provide `scripts/check-lean-axioms.sh` which fails on any
sorry warning, asserts each audited theorem's axiom set is inside {propext,
Classical.choice, Quot.sound} reporting unexpected axioms by name, scans all
twin sources for `axiom` declarations, and is itself red-tested via a
planted-bad-file seam.

### Requirement: Pinned toolchain provisioning

The system SHALL pin the twin's Lean toolchain in `lean/lean-toolchain`,
provisioned through elan, with no unpinned or rolling installs anywhere in
the twin's workflow.

### Requirement: Just lean recipe and stop-gate record

The system SHALL provide `just lean` running build, parity oracle, and axiom
audit, kept out of the local `just check` chain, and SHALL record an extend,
hold, or retire stop-gate decision with cost/benefit accounting under
`ledger/lean/` after the proof phase.

### Requirement: Continuous-integration enforcement of the gates

The system SHALL run the twin's gates in CI through a dedicated `lean` job
that installs elan, builds under the pinned `lean/lean-toolchain`, and runs
`just lean`, triggered by changes to the twin or the Python core, skipped
for unrelated changes while the twin is absent, and failing loudly when the
twin is touched while absent, so that a `sorry` regression, a parity
divergence, or orphan twin paths fail the pull request.
