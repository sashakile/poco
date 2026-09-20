# Micro — Selection lifecycle

## Cartography — micro trace: life of a `Selection`
**Entry zoom level:** micro (parent: macro map; district: provenance meso)
**Scope covered:** `add-provenance-tracking/specs/provenance/spec.md`, with
anchors in `relational` and `dataframe`

## Entry point

`df.select_rows(Person.age > 30)` — the direct construction path
(`provenance/spec.md`, "Selection supports pull_back, push_forward, and
restrict" requirement, `provenance/spec.md:130`).

## Call chain

```
 1. df.select_rows(pred)              provenance:130
                                      → materializes df's plan (terminal, like to_dict)
                                      → Selection{RowId set, source lineage, revision: counter.next()}
                                        [revision req: per-source monotonic counter]
 2. fibers = df | po.groupby(k)       relational: Groupby as relational pipeline step (modified)
                                      → materializes source plan; Fibration built
                                        (forward: key→RowIds, reverse: RowId→key, O(1) lookup)
                                      → Fibers value; terminal for |
 3. cut = fibers["engineering"]       provenance:246 Fibers requirement
                                      → Selection of exactly that fiber's source rows
                                      → unknown key → KeyError; revision: counter.next()
 4. cut.intersect(other_cut)          provenance: set-algebra req
                                      → row-id intersection; NO cross-product structure
                                        [fibration-cuts req]; fresh revision
 5. grouped = df | po.groupby(k, total=po.sum_of(s))   relational (modified)
                                      → collapsed lazy DataFrame; step retains Fibration
 6. grouped.materialize().fibers      relational: Collapsed-result-exposes-fibration scenario
                                      → every aggregate row traceable
 7. grouped.pull_back(sel_out)        provenance:130
                                      → follows composed ProvenanceTransform in reverse
                                        (Span/Fibration pullback) → source-row Selection
                                      → no predicate re-evaluation
 8. target.push_forward(sel, grouped) provenance:130
                                      → cross-view highlight; shared lineage required
 9. df.restrict(sel)                  provenance:130
                                      → sub-DataFrame of exactly sel's rows
                                        (empty sel → zero-row, schema-correct DataFrame)
10. fibers.stats(sel, n=po.count_of()) provenance: Sub-statistics req
                                      → reduces the fibers touched by sel over the
                                        already-retained maps; source pipeline NOT re-executed
11. consumer applies updates          provenance: revision req
                                      → discard any update with revision ≤ last applied
```

## Data flow

```
source rows ──materialize──▶ RowId maps (parallel to rows)
     │                                    │
Expr pred ──select_rows──▶ Selection ──┐   │
groupby ──▶ Fibration (fwd+reverse) ───┤   │
     │                                 ▼   ▼
     │                     intersect / pull_back / push_forward
     │                                 │
     ▼                                 ▼
restrict → sub-DataFrame          .stats → dict (per-fiber reduce, unstep-friendly)
```

## Structural observations

- **Two creation paths, one invariant:** both `select_rows` and `fibers[key]`
  materialize lazily-built plans — Selections never exist over unmaterialized
  data; this is what makes RowId stability and revision counters coherent.
- **The revision counter is the concurrency seam:** assigned at creation
  (library-side), consumed by out-of-process UI code; poco itself implements
  no scheduling (design non-goal) — the spec defines the data contract only.
- **Aggregate rows are first-class provenance citizens:** hop 6 is the
  capability's motivating scenario — the Fibration survives the collapse, so
  `pull_back` on an *aggregated* chart row recovers member source rows
  without re-running any predicate.
- **Error paths:** cross-source `ValueError` (all algebra ops), unknown key
  `KeyError`, partial reducer on empty fiber `ValueError`, non-deterministic
  pipeline `ValueError` (RowId scoping), `Fibers` piped onward `TypeError`.
