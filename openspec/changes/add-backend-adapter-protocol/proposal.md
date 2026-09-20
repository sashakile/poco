# Change: Add a backend adapter protocol for swappable Storage/Compute engines

## Why

`project.md` and the README advertise "swappable Storage and Compute
backends" as a core design principle. `add-core-architecture`'s `design.md`
defers this twice ("via protocols (future change, not in this proposal)")
and no capability, protocol, or spec currently exists for it. Worse, two
decisions already locked into `add-core-architecture` make the deferred
adapter layer expensive to retrofit later:

1. `pipeline/spec.md` requires `PipelineStep`'s data component to be a
   `DataOp` — `StreamingOp` or `MaterializingOp` — both backed directly by
   opaque Python transducer closures. Once a pipeline is built, there is
   nothing left to inspect: the operational intent (a filter, a projection)
   has already been fused into a function. A polars or numpy backend cannot
   push a `where()` down into a native filter, because there is no
   declarative node describing it anymore, only a closure.
2. `expression/spec.md` and `relational/spec.md` hardcode a single strictness
   policy (null comparisons raise, `mean` of empty raises, `&`/`|` never
   short-circuit) as an unconditional invariant. No other dataframe engine
   implements this behavior — pandas and polars both propagate nulls. A
   backend cannot be both fast (native execution) and spec-compliant (raise
   on null) at the same time under the current wording.

This proposal reifies the pipeline as an inspectable logical plan, makes
strictness a named, swappable policy instead of a hardcoded invariant, and
defines the minimal `Backend` protocol and capability-negotiation contract
that a future numpy/pandas/polars adapter would implement against — without
implementing any such adapter yet, per `design.md`'s existing non-goals.

## What Changes

- **ADD `backend` capability**: a `Backend` protocol (`plan(logical_plan) ->
  materialized rows`), a `NullPolicy` enum (`RAISE` default, `PROPAGATE`)
  that *scopes* — rather than replaces — the null-strictness requirements
  already stated in `expression` and `relational` (those requirements hold
  in full under the default `RAISE` policy and are superseded by native
  null semantics only under an explicitly opted-in `PROPAGATE` backend),
  explicit capability negotiation (`Backend.supports(op) -> bool`), and a
  hard rule that unsupported operations either raise
  `UnsupportedOperationError` or fall back to the pure-Python backend
  **only** when the caller has explicitly opted in — never silently.
- **ADD import/export boundary**: `from_pandas`/`to_pandas`,
  `from_polars`/`to_polars`, with a documented, explicit policy for dtypes
  outside poco's supported set (`int | float | str | bool` + Optional) and
  column names that aren't valid Python identifiers.
- **MODIFY `pipeline`**: every `PipelineStep`'s data component SHALL carry a
  `LogicalOp` — a sealed, backend-neutral node (`Filter`, `Project`,
  `Extend`, `Sort`, `Distinct`, `GroupBy`, `Join`, `Identity`) describing
  *what* the step does — in addition to (not instead of) its pure-Python
  transducer lowering. The transducer becomes the pure-Python backend's
  lowering of the `LogicalOp`, not the definition of the operation itself.
  **BREAKING** relative to `add-core-architecture`'s current internal
  representation, though not to any public API surface (`where()`,
  `select()`, etc. keep their signatures).
- **MODIFY `dataframe`**: `explain()` reflects the reified `LogicalOp` chain
  (not just schema transforms); `DataFrame` construction accepts an optional
  `backend=` parameter defaulting to the pure-Python backend.

## Impact

- Affected specs: `pipeline`, `dataframe` (both in `add-core-architecture`,
  MODIFIED); new `backend` capability (ADDED)
- Affected code: none yet (no implementation exists)
- Depends on: this proposal does not require `fix-core-architecture-spec-errors`
  or `add-provenance-tracking`, but `add-provenance-tracking`'s selection
  algebra is easier to specify once `LogicalOp` exists, since provenance
  spans are naturally attached per `LogicalOp` node rather than per opaque
  transducer. Recommended order: this proposal before
  `add-provenance-tracking`.
- Non-goals (unchanged from `add-core-architecture`): no adapter
  implementation (numpy, pandas, polars) ships as part of this change; no
  query optimizer (pushdown/fusion) is implemented, only made possible
