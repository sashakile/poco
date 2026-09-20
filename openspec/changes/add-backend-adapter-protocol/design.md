## Context

poco's `Expr` hierarchy (`row-model` → `expression`) is already a sealed,
four-variant tree (`ColumnRef`, `Literal`, `BinOp`, `UnaryOp`) with no
lambdas and no strings — a genuinely translatable IR. `SchemaTransform` is
likewise a sealed, data-only ADT computed without touching row data. Neither
of these blocks a multi-backend future. The blocker is one layer up: the
`DataOp` half of `PipelineStep` collapses straight to a Python closure at
construction time (`transducer/spec.md`'s composition law:
`(xf1 | xf2)(reducer) == xf1(xf2(reducer))`), so by the time a plan exists to
execute, there is no declarative structure left for a backend to inspect,
translate, or optimize.

Separately, poco's strictness (raise on null, no short-circuit, raise on
empty aggregate) is a deliberate pedagogical choice — and also, unmodified,
a portability wall. No mainstream engine implements it. Backend authors
would either have to emulate it row-by-row in Python (destroying the reason
to use the engine) or silently diverge from spec (destroying trust that
`po.where(...)` means the same thing regardless of which backend is loaded).

## Goals / Non-Goals

Goals:
- A pipeline's operational intent SHALL be inspectable and translatable
  without touching row data, mirroring what `SchemaTransform` already
  achieves for schema
- Strictness policy SHALL be a named, explicit setting, not a hardcoded
  invariant, so a backend can declare which policy it supports
- A `Backend` MAY decline to support an operation; the caller SHALL always
  know explicitly whether an operation ran natively or fell back to pure
  Python
- The pure-Python backend remains the default, requires zero configuration,
  and is unaffected in observable behavior under `NullPolicy.RAISE`

Non-Goals:
- Shipping a numpy, pandas, or polars adapter in this change
- A query optimizer (predicate pushdown, operator fusion) — this proposal
  makes optimization *possible* by reifying the plan; it does not implement
  one
- Arrow as an in-memory representation for the pure-Python backend — Arrow
  is discussed only as an interchange format at the import/export boundary
- Incremental/streaming execution across backends

## Decisions

- **Decision: `LogicalOp` is additive, not a replacement for the
  transducer.** Every `PipelineStep`'s data component carries both a
  `LogicalOp` (declarative, backend-neutral) and its pure-Python lowering
  (the existing `StreamingOp`/`MaterializingOp` transducer). The pure-Python
  backend executes the lowering directly, unchanged from
  `add-core-architecture`. A non-Python backend executes by pattern-matching
  on `LogicalOp` and ignores the pure-Python lowering entirely.
  - Alternatives considered: replacing the transducer with only a
    `LogicalOp` and lowering to a transducer lazily at execution time for
    the pure-Python backend — rejected as unnecessary churn to the already-
    approved `transducer` capability; keeping both means
    `add-core-architecture`'s pure-Python execution semantics are
    unaffected by this change.
- **Decision: `NullPolicy` is a property of the `Backend`, not of individual
  operations.** A backend declares one policy (`RAISE` or `PROPAGATE`) for
  its whole execution; mixing policies mid-pipeline would make output
  depend on which steps happen to touch nulls, which is worse than either
  policy alone. The pure-Python backend's default is `RAISE`, preserving
  `add-core-architecture`'s current behavior exactly when no backend is
  specified.
  - Alternatives considered: per-expression policy via a `null_policy=`
    kwarg on `where`/`derive` — rejected; this multiplies the API surface
    and still doesn't resolve what happens when a `PROPAGATE`-policy
    expression feeds a `RAISE`-policy downstream step.
- **Decision: fallback to pure Python is opt-in via an explicit
  `on_unsupported="fallback"` argument at `DataFrame` construction (default:
  `"raise"`).** Silent fallback is the failure mode most likely to surprise
  a user relying on backend performance (e.g. materializing a large polars
  frame into per-row Python dicts without warning). Raising
  `UnsupportedOperationError` by default forces the decision into the open.
  - Alternatives considered: silent fallback with a logged warning —
    rejected; warnings are easy to miss in notebook output, which is exactly
    where this failure mode is most costly.
- **Decision: import/export dtype policy is reject-by-default,
  rename-on-request for columns.** `from_pandas(df)` raises `SchemaError`
  naming the first unsupported dtype column found (e.g. `datetime64`)
  rather than silently dropping or stringifying it. Non-identifier column
  names raise `SchemaError` unless `column_map={}` is supplied to rename
  them explicitly. This matches poco's existing "strict, no silent
  coercion" principle (`project.md`) rather than introducing a new,
  import-specific leniency.
  - Alternatives considered: auto-rename non-identifier columns (e.g.
    `"first name"` → `first_name`) — rejected as a silent transformation
    that could collide with an existing column or confuse round-tripping;
    requiring an explicit map keeps the decision visible and reversible.

## Risks / Trade-offs

- Reifying `LogicalOp` adds a second representation that must stay
  consistent with its transducer lowering for every factory
  (`where`, `select`, `derive`, `sort_by`, `distinct`, `groupby`, `join`).
  Mitigation: the exhaustiveness discipline `pipeline/spec.md` already
  requires for `SchemaTransform` (sealed hierarchy, explicit unreachable
  default branch, `typing.assert_never()`, runtime exhaustiveness test)
  applies identically to `LogicalOp`.
- A `Backend` declaring `NullPolicy.PROPAGATE` changes pipeline *results*
  compared to the pure-Python default, not just performance. Mitigation:
  `DataFrame.explain()` and `.backend` SHALL surface which policy is active
  so this is never a silent difference between two runs of the same code
  under different backends.

## Migration Plan

No running code exists yet. This is additive to the pending
`add-core-architecture` proposal's internal representation before it
archives; the public API (`where()`, `select()`, `derive()`, etc.) is
unchanged. No consumer migration is required.

## Open Questions

- Should `LogicalOp.Join` carry the same "equi-join only" restriction as
  `relational/spec.md`, or should backends be allowed to advertise support
  for a richer predicate language via capability negotiation, with poco's
  pure-Python backend remaining restricted? Leaning toward: the *public*
  `po.join()` factory keeps the equi-join-only restriction for all backends
  (consistency of meaning matters more than exploiting one backend's extra
  power), revisit only if a concrete backend proposal needs it.
- Should Arrow (not pandas or polars specifically) be the required
  interchange format for `from_backend`/`to_backend` conversions, given it's
  the format both pandas (via `pyarrow`) and polars are built on? Deferred
  to whichever adapter proposal ships first.
