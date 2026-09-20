# Micro — pipeline step lifecycle

## Cartography — micro trace: a `PipelineStep` from factory to rows
**Entry zoom level:** micro (parent: macro map; district: pipeline meso)
**Scope covered:** the union target state across `pipeline`, `dataframe`,
`transducer`, `expression`, `backend`, `provenance`

## Entry point

`po.where(Person.age > 25)` — the canonical streaming factory
(`add-core-architecture/specs/pipeline/spec.md:145`, general contract in
the validated-factories requirement,
`add-provenance-tracking/specs/pipeline/spec.md:10`).

## Call chain (spec hops, with the governing requirement at each hop)

```
 1. po.where(expr)                    pipeline:145 factory
                                      → attaches DataOp{LogicalOp.Filter, StreamingOp(transducer)}
                                        + SchemaTransform(Identity) + ProvenanceTransform(Injection)
                                        [pipeline: validated-factories req; provenance: hierarchy req]
 2. step1 | step2                     pipeline: composition reqs
                                      → LogicalOp concat in pipe order [backend delta]
                                      → ProvenanceTransform pullback [provenance: compose-by-pullback req]
                                      → schema compatibility validated at construction [pipeline]
 3. df | step                         dataframe:267 Pipe operator
                                      → NEW DataFrame, plan extended, zero data processed
 4. df.to_dict()                      dataframe: export req (modified by backend delta)
                                      → materialization trigger
 5. backend.plan(logical_ops)         backend:3 Backend protocol
                                      → default: pure-Python backend lowers each LogicalOp
                                        to its transducer [state independence: transducer reqs 6-7]
 6. transducer | transducer …         transducer:45 left-to-right composition
                                      → rows are dict[str, object] copies [row-model:3]
 7. Expr evaluation per row           expression:117 evaluation against a row
                                      → nulls: NullValueError under NullPolicy.RAISE
                                        [expression errors req; backend NullPolicy req]
 8. SchemaTransform applied per step  pipeline:204 exhaustiveness req
                                      → output rows conform to next schema
 9. ProvenanceTransform recorded      provenance: hierarchy + composition reqs
                                      → metadata only; no re-evaluation of predicates
10. rows → immutable DataFrame        dataframe:294 immutable/always-lazy req
```

## Data flow

```
Expr tree → PipelineStep (LogicalOp + lowering + schema + provenance)
          → DataFrame plan (lazy, immutable)
          → materialization trigger (export/iterate/restrict)
          → Backend.plan → transducer chain → per-row dicts
          → SchemaTransform per step → materialized DataFrame
          (parallel: ProvenanceTransform chain → Fibration/Selection maps)
```

## Structural observations

- **Where purity ends:** construction (hops 1–3) is pure and eager only in
  *metadata*; the first execution hop is the materialization trigger (hop 4)
  — lazy-until-export is the corpus' single most load-bearing invariant
  (specified in 3 capabilities: dataframe immutability, pipeline plan
  inspection, backend default-path invariance).
- **The pure-Python lowering is the only execution path by default**
  (backend req 1); a non-Python backend matches on `LogicalOp` and never
  touches the transducers.
- **Fallback seam:** if `supports(op)` is False and `on_unsupported="fallback"`,
  hop 5 routes that step to the pure-Python backend and `explain()` marks
  `[fallback: python]` (backend negotiation req).
- **Error paths en route:** non-Expr argument → `InvalidExprUsageError`/
  `TypeError` (fix change); schema mismatch at pipe → early `SchemaError`;
  null under RAISE → `NullValueError`; TTL-distinct in a provenance-
  materializing pipeline → `ValueError` (provenance RowId req).
