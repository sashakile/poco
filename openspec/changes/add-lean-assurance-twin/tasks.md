# Tasks: add-lean-assurance-twin

Sequencing: sections 1–2 can start once the schema/reducer/transducer slices
of `add-core-architecture` land; the oracle (section 5) needs a working
Python core. Each numbered ticket follows red → green → refactor.

## 1. Provisioning and mirror contract (design D6: contract first)
- [ ] 1.1 Write tests for the trusted mirror document: round trip, dense rows, dtype tags (int ≠ float, null-only missing), canonical order
- [ ] 1.2 Write tests for named rejection: ragged rows, unknown dtype tags, missing fields each fail with first offending position
- [ ] 1.3 Draft `docs/lean-mirror-contract.md` specifying fields, ordering, dtype tags, and the resolution rule; reconcile with test expectations
- [ ] 1.4 Add `lean/` Lake project skeleton: `lakefile.lean` (lib `Po`, exe `lean-parity`), pinned `lean-toolchain`, elan provisioning note in README
- [ ] 1.5 Tidy contract doc and skeleton after tests pass

## 2. Lean reference kernel (red = kernel property tests, green = totality)
- [ ] 2.1 Write Lean tests/examples for `Po.Schema` and `Po.Instance` build over mirror documents, including typed-error constructors for invalid input
- [ ] 2.2 Implement `Po.Schema`, `Po.Mirror` (project/decode), and `Po.Instance` as total stdlib functions
- [ ] 2.3 Write examples for `Po.Expr` evaluation over rows: unknown column, type mismatch, arithmetic, null propagation
- [ ] 2.4 Implement `Po.Expr` mirroring the poco expression contract
- [ ] 2.5 Write examples for `Po.Reducer` three-phase fold: `Reduced` early termination, `Reduced(Reduced(v))` flattening, empty input per total/partial reducer
- [ ] 2.6 Implement `Po.Reducer` with named per-reducer fold helpers (design D7)
- [ ] 2.7 Write examples for `Po.Transducer` identity and left-to-right composition, and `Po.Materialize` walk over schema + instance + pipeline
- [ ] 2.8 Implement `Po.Transducer` and `Po.Materialize`; tidy kernel after examples pass

## 3. Law theorems (red = build emits sorry warnings, green = sorry-free)
- [ ] 3.1 Define `Po.Proofs.Membership` — the shared membership/ordering lemma contract — before any theorem file (design D7)
- [ ] 3.2 State and prove reducer determinism and resumability (`reduce(xs ++ ys) == resume(ys, state(xs))`)
- [ ] 3.3 State and prove Reduced validity and empty-input validity for total reducers
- [ ] 3.4 State and prove transducer identity and associativity of composition
- [ ] 3.5 Review every theorem statement against its spec prose clause in both directions; widen hypotheses that force one side to resolve (design D8 review clause / constraint cl.statement_review)
- [ ] 3.6 Tidy proof plumbing: consolidate duplicated bridges into `Po.Proofs.Membership`

## 4. Axiom audit gate (red = planted bad files, green = clean tree passes)
- [ ] 4.1 Write red tests for the gate: planted `sorry` body, planted user `axiom`, subset audit — each must turn the gate red with named output
- [ ] 4.2 Implement `scripts/check-lean-axioms.sh`: sorry-warning failure, axiom-set assertion ⊆ {propext, Classical.choice, Quot.sound}, axiom-declaration source scan, `--file` seam
- [ ] 4.3 Tidy gate output formatting after red tests pass

## 5. Python counterpart and parity oracle
- [ ] 5.1 Write tests for `poco/poco_parity.py`: mirror-JSON in, normalized result envelope out (columns as tagged cells, inferred schema, error taxonomy entries); rejection exit route for unbuildable documents
- [ ] 5.2 Implement `python -m poco_parity --json` on the pure-Python core
- [ ] 5.3 Write the fixture corpus seed: `fixtures/parity/**` covering empty inputs, early-terminated folds, type promotion, unknown columns, wording-only error variants
- [ ] 5.4 Write oracle tests: dynamic enumeration (add/remove fixture tracked), normalized comparison (wording-only difference agrees), skipped_parse route, dispositions-annotate-never-suppress
- [ ] 5.5 Implement `Po.Parity` / `Po.ParityMain` (`lake exe lean-parity`) with report fields: total, rust_checkable→`python_checkable`, `trivially_agreeing`, `findings_bearing_agreeing`, `divergences`, `skipped_parse`; zero findings-bearing is red; exit 1 while divergences exist
- [ ] 5.6 Add `parity-dispositions.json` handling (annotation only) and beads-ticket attribution protocol docs
- [ ] 5.7 Tidy harness and report rendering after tests pass

## 6. Recipes, docs, stop gate
- [ ] 6.1 Add `just lean` recipe (build + parity + axiom audit); keep it out of the local `just check` chain (elan is a separate provisioning), document the elan prerequisite
- [ ] 6.2 Write `lean/README.md`: what the twin claims, what it does not claim (no adjunction triple, no Rust leg yet — design D3), how to run, exit codes, divergence protocol
- [ ] 6.3 Record the stop-gate decision under `ledger/lean/` (extend/hold/retire) with cost/benefit accounting
- [ ] 6.4 Final validation: `openspec validate add-lean-assurance-twin --strict`, `spk lint openspec/changes/add-lean-assurance-twin/specs`, `just lean` green on a clean tree
- [ ] 6.5 Add the `lean` job to `.github/workflows/ci.yml` (design D10): install elan, respect `lean/lean-toolchain`, `uv sync`, run `just lean`; gate on paths `lean/**`, `poco/**`, `fixtures/parity/**`, `scripts/check-lean-axioms.sh`; three-case existence rule — skip unrelated paths while `lean/` is absent, fail loudly on orphan twin paths, run the gates when present; red-test by planting a `sorry` (job fails the PR) and by touching a twin path on a twin-absent branch (job fails naming the missing toolchain)
