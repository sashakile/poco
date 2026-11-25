# Change: Add Lean assurance twin — proved laws and a parity oracle for the poco core

## Why

poco's value is its algebraic laws (reducer determinism, resumability, transducer
identity and composition, empty-input behavior), but those laws are only ever
*sampled* by property tests. A property test can state "these generated cases
agree"; it cannot state "for all reducers, for all lists". The sibling project
`at/catherine` validated a cheap, high-assurance pattern for exactly this: a
Lean 4 **assurance twin** — an external reference semantics with sorry-free
theorems plus a parity oracle that cross-examines the real implementation over
a fixture corpus. This change ports that pattern to poco at smallest-viable
scope.

The oracle counterpart is the **pure-Python core** (the Rust backend, when it
lands under `add-backend-adapter-protocol`, joins as a second parity leg
without changing this contract).

## What Changes

- Add `lean/` as a standalone Lake project, standard-library only (no
  Mathlib), pinned by `lean/lean-toolchain`, with zero runtime dependency
  from the `poco` package
- Add a **trusted mirror document contract**: canonical stdlib JSON projection
  of poco data documents (schema, dense rows, dtype-tagged cells) with total
  projection/decode and named rejection of mirror-invalid documents
- Add the **Lean reference kernel**: `Po.Schema`, `Po.Instance`, `Po.Expr`,
  `Po.Reducer`, `Po.Transducer`, `Po.Materialize` — total functions mirroring
  the row contract, the three-phase reducer with `Reduced` early termination,
  left-to-right transducer composition, and the materialization walk
- Add **sorry-free theorems** for the poco laws: reducer determinism,
  resumability (`reduce(xs ++ ys) == resume(ys, state(xs))`), Reduced
  validity, empty-input validity for total reducers, transducer identity, and
  associativity of transducer composition
- Add the **lean-parity oracle** (`lake exe lean-parity`): dynamic fixture
  enumeration, Python counterpart run as a subprocess sharing no linked code,
  normalized semantic comparison (never raw bytes), a report that separates
  `trivially_agreeing` from `findings_bearing_agreeing`, a `skipped_parse`
  route for documents the Python side rejects, and a divergence protocol in
  which a mismatch is never merged away — it is attributed (lean-defect vs
  python-defect) and filed as a beads ticket
- Add an **axiom audit gate** (`scripts/check-lean-axioms.sh`): fails on any
  `sorry` warning, asserts every audited theorem's axiom set is inside
  `{propext, Classical.choice, Quot.sound}`, scans twin sources for `axiom`
  declarations, and is itself red-tested with planted bad files
- Add `just lean` (build + parity + axiom audit) as the local entry point, kept
  out of the local `just check` chain because the Lean toolchain is provisioned
  separately (elan), plus a dedicated **`lean` CI job** in
  `.github/workflows/ci.yml` that installs elan, builds under the pinned
  `lean/lean-toolchain`, runs `just lean`, and fails any pull request touching
  the twin with a `sorry` regression or a parity divergence
- Add a **stop gate**: after the proof phase, a recorded extend/hold/retire
  decision with cost/benefit accounting under `ledger/lean/`

## Impact

- Affected specs: new capabilities `lean-mirror`, `lean-kernel`, `lean-laws`,
  `lean-parity`, `lean-gates` — no existing capability is modified
- Affected code: new `lean/` tree, `scripts/check-lean-axioms.sh`,
  `poco/poco_parity.py` (subprocess counterpart CLI), `fixtures/parity/**`,
  `justfile`, `.github/workflows/ci.yml` (new `lean` job); the `poco` package
  gains no dependency on Lean
- **CI enforcement**: parity divergences and `sorry` regressions block merge —
  the gates run in CI, not only locally
- **Sequencing**: requires the schema, reducer, and transducer slices of
  `add-core-architecture` to have landed — the oracle needs a real Python core
  to interrogate. The mirror contract (design D6) may be drafted earlier
- Non-goal (deferred, see design D3): formalizing the Σ ⊣ Δ ⊣ Π adjunction
  triple; formalizing the future Rust backend
