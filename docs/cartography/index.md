# poco — Architectural Report (spec-space cartography)

poco is specified, not built: the package is 15 lines of stubs, the
architecture is **13 capabilities / 128 requirements / 386 scenarios /
3,999 lines** of normative OpenSpec text. This report maps that corpus as
it will exist when all five pending changes are applied (the *union target
state*; nothing is archived yet).

**Regeneration:** maps are diff-able artifacts produced by the
codebase-cartography skill; re-run it after spec changes. Counts were
re-verified against fresh greps at write time.

## Map inventory

| Map | Level | Scope |
| :--- | :--- | :--- |
| [cartography-macro-spec-topology.md](cartography-macro-spec-topology.md) | macro | All 13 capabilities: inventory, dependency matrix, graph, cycles, hubs, orphans |
| [cartography-micro-pipeline-step-lifecycle.md](cartography-micro-pipeline-step-lifecycle.md) | micro | Factory → pipe → materialization → rows, hop by hop |
| [cartography-micro-selection-lifecycle.md](cartography-micro-selection-lifecycle.md) | micro | `select_rows` → `Fibers` → set algebra → `pull_back`/`restrict`/`.stats` → revisions |
| [cartography-meso-row-model.md](cartography-meso-row-model.md) | meso | The row contract (T0) |
| [cartography-meso-schema.md](cartography-meso-schema.md) | meso | Schema declaration, inference, types (T0) |
| [cartography-meso-aggregation.md](cartography-meso-aggregation.md) | meso | Column-bound reducers (T1; orphan — cross-refs now added) |
| [cartography-meso-errors.md](cartography-meso-errors.md) | meso | Exception taxonomy + guardrails (T1) |
| [cartography-meso-expression.md](cartography-meso-expression.md) | meso | Deferred `Expr` language (T1) |
| [cartography-meso-transducer.md](cartography-meso-transducer.md) | meso | Streaming algebra; `distinct` (T1) |
| [cartography-meso-reducer.md](cartography-meso-reducer.md) | meso | Reduce protocol + `unstep` (T1) |
| [cartography-meso-pipeline.md](cartography-meso-pipeline.md) | meso | `PipelineStep`, factories, composition (T2) |
| [cartography-meso-relational.md](cartography-meso-relational.md) | meso | Joins, groupby (T2) |
| [cartography-meso-integrity.md](cartography-meso-integrity.md) | meso | Time-series data quality (T2; leaf) |
| [cartography-meso-provenance.md](cartography-meso-provenance.md) | meso | RowId, Selection, Fibers (T2; fan-out hub) |
| [cartography-meso-backend.md](cartography-meso-backend.md) | meso | Backend protocol, NullPolicy (T2) |
| [cartography-meso-dataframe.md](cartography-meso-dataframe.md) | meso | The user surface (T3) |

## The architecture in five facts

1. **Four tiers, one direction.** `row-model`/`schema` define data;
   `expression`/`transducer`/`reducer` compute; `pipeline`/`relational`/
   `provenance`/`backend`/`integrity` orchestrate; `dataframe` is the user
   surface. 26 cross-capability reference edges; 4 capabilities unmodified
   by any pending change (`row-model`, `schema`, `aggregation`, `errors` is
   modified — so 3 untouched: row-model, schema, aggregation).
2. **Three deliberate co-ownership cycles.** `pipeline↔backend` (LogicalOp),
   `provenance↔relational` (groupby/Fibers), `provenance↔reducer`
   (unstep/fibers) — each pair co-specifies one contract across two
   capabilities.
3. **Lazy-until-materialization is the spine.** Specified redundantly in
   dataframe (immutability), pipeline (plan inspection), and backend
   (default-path invariance) — the corpus' most load-bearing invariant.
4. **Provenance is unconditional.** Fiber retention has no flag: bare
   `groupby` returns `Fibers`; the aggregating form exposes `.fibers`.
   Retention *is* the provenance.
5. **Errors have a constitution.** All raises funnel through `PocoError`;
   guardrails subclass native + `PocoError`; pass-throughs stay raw —
   the distinction is specified once (`errors`) and consumed everywhere.

## Defects & open questions surfaced by mapping

- **Misplaced requirement (fixed):** backend's pipeline delta originally
  declared "Plan inspection without materialization" — a requirement owned
  by `dataframe`. Moved to the backend change's dataframe delta as a proper
  `MODIFIED` of dataframe's `explain()` requirement (LogicalOp chain,
  backend, `NullPolicy`, fallback marks); all changes validate `--strict`.
- **Reference orphan (fixed):** `aggregation` was never cited by path; the
  `relational` groupby and `provenance` `.stats` requirements now cite
  `aggregation/spec.md` explicitly.
- **Archival seams:** `distinct` was touched by three changes; `diff()` is
  an expression-grammar extension specified in `integrity`; stable-sort
  guarantee for `sort_by` lives in `integrity` but governs `pipeline` —
  candidates for re-homing when changes are archived.
- Macro-level open questions (cycles, `schema → dataframe` edge): see the
  macro map's Open Questions section.
