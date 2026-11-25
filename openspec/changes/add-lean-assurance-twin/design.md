# Design: Lean assurance twin

Reference implementation of this pattern (studied, not copied blindly):
`at/catherine` `lean/` — kernel mirror ~800 lines, proofs ~2.1k lines, oracle
~1.2k lines, axiom-audit gate, divergence protocol, ledger stop gate. Its
implementation-learnings doc drives most decisions below.

## Decision 1 — The parity counterpart is the Python core, not Rust

poco has no Rust engine yet; the backend adapter change is separate and
unstarted. The oracle therefore interrogates the pure-Python core
(`python -m poco_parity --json`). When a Rust backend lands, it becomes a
second counterpart leg under the same mirror contract. This keeps the twin
decoupled from backend churn and matches the swappable-backends principle.

## Decision 2 — Standard library only, no Mathlib

Same as catherine: anything the kernel needs beyond std is a scope violation,
not a dependency. poco's laws are folds over flat lists — they need no CT
machinery. Pinned via `lean/lean-toolchain` through elan; installs are
versioned, never `latest`.

## Decision 3 — Theorem scope: the stated laws, not the adjunction triple

The theorems formalize exactly the law clauses the specs already state:
determinism, resumability, Reduced validity, empty-input validity, transducer
identity, transducer composition associativity. The Σ ⊣ Δ ⊣ Π adjunction
triple is *not* formalized in this change — it needs Mathlib-grade category
theory, no current constraint derives from it, and catherine's stop gate
showed scope discipline is what keeps a twin maintainable. It is the named
`extend` path of the stop gate.

## Decision 4 — Compare normalized semantic results, never text

Oracle equivalence is over materialized columns (ordered values with dtype
tags), inferred schema, and error-taxonomy entries compared as multisets.
Raw stdout, repr text, and message wording are never compared — they are
presentation, not semantics. Documents the Python side rejects (parse or
build) are `skipped_parse` with the first stderr line: a fact about the
parser contract, never silently counted as agreement.

## Decision 5 — Divergence protocol: never merged away

A mismatch is exactly one of: (a) a **Lean-model defect** — the twin
deviates from the normative specs, which act as referee; or (b) a
**python-defect** — the twin is right and `poco/` is wrong; file a beads
ticket, fix Python, add a regression fixture. `parity-dispositions.json`
may annotate attribution; it never suppresses. The oracle exits 1 while
any divergence exists.

## Decision 6 — Write the mirror contract before any harness code

Catherine's CLAR-001: the harness shape was corrected mid-implementation
because the data contract was sketched, not specified. Here the trusted
mirror document (fields, ordering, dtype tags, resolution rule) is a spec
capability (`lean-mirror`) and is drafted first; `Po.Mirror` and the Python
fixture format are both written against it.

## Decision 7 — Proof-friendly kernel and a frozen membership contract

Named helpers per law family (catherine lesson 6: an anonymous inlined walk
forced a proof to restate the body). The shared membership/ordering lemma
contract (`Po.Proofs.Membership`) is defined before any theorem file is
written (lesson 5: parallel proofs duplicated bridges when it wasn't).

## Decision 8 — Gates assert sets, not substrings, and are red-tested

The axiom audit follows catherine's hardened version: fail on any
`declaration uses 'sorry'` build warning; `#print axioms` every audited
theorem and assert the axiom *set* ⊆ `{propext, Classical.choice,
Quot.sound}` (a substring test for `sorryAx` accepted a proof built on a
user axiom); scan every twin source for `axiom` declarations; expose a
`--file` seam so the gate is tested against planted bad files. A gate is a
claim — give it a red test before trusting it.

## Decision 9 — The assurance outcome is a recorded decision

After the proof phase, `ledger/lean/` records extend (follow-up change, e.g.
the adjunction triple or a Rust leg), hold (maintain at landed scope), or
retire (archive the twin, keep the lessons) with cost/benefit accounting.
Assurance drift must be a decision, never silence.

## Decision 10 — CI enforcement, conditionally provisioned

The local/CI split catherine teaches is about *toolchain provisioning*, not
*enforcement exemption*: `just lean` stays out of the local `just check`
chain (a contributor without elan must not fail `just check`), but CI gains
a dedicated `lean` job that installs elan, uses the pinned
`lean/lean-toolchain`, runs `uv sync` (the parity counterpart needs the
Python env), and executes `just lean`. The job is path-filtered to
`lean/**`, `poco/**`, `fixtures/parity/**`, and
`scripts/check-lean-axioms.sh`, with a three-case existence rule: unrelated
changes skip while `lean/` is absent; twin paths touched while `lean/` is
absent fail loudly naming the missing `lean/lean-toolchain` (orphan paths
are a defect, never a silent skip); with the twin present the gates run and
planted failures go red. `lean/` lands only
after the core-architecture slices this change sequences on. One runner, no
Python matrix — the matrix is the pure-Python job's concern. Red-test the
job by planting a `sorry` and confirming the PR goes red, and by touching an
orphan twin path on a twin-absent branch and confirming the job fails.
