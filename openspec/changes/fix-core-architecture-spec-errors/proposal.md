# Change: Fix internal contradictions in the core-architecture and advanced-data-integrity specs

## Why

A line-by-line review of `add-core-architecture` and `add-advanced-data-integrity`
found four concrete, independently verifiable defects: one typo that changes
operator semantics, one duplicated traceability ID that breaks
requirement-to-scenario tracing, one return-type contradiction between two
spec files that both govern `po.distinct()`, and one gap where the public
exception taxonomy's own "catch everything via `PocoError`" promise is
silently violated by two intentional guardrail errors. None of these require
a design discussion; all four are corrections to bring the specs into
agreement with themselves and each other, before any implementation begins.

Note on scope: `add-core-architecture` and `add-advanced-data-integrity` are
both still open (unarchived) at the time of this proposal, so there is no
`openspec/specs/` baseline yet to diff against. This proposal expresses its
corrections as `MODIFIED Requirements` deltas against the requirement text as
it currently stands in those two pending changes, on the assumption that
either this proposal is merged into them before archival, or applied as a
follow-up delta immediately after they archive. The delta format is used
regardless, per project convention, so the exact before/after requirement
text is unambiguous.

## What Changes

- **Fix arithmetic operator typo** in `expression`: the type-inference table
  header lists `//` (floor division) where every other reference to this
  operator group in the same spec, and in `design.md`, uses `/` (true
  division). No `__floordiv__` behavior is specified or implemented anywhere
  else in the project.
- **Deduplicate traceability IDs** in `dataframe`: two unrelated requirements
  ("Materialization errors include pipeline context" and "Pipeline steps
  validate Expr types at construction") both carry the tag
  `[HUM-008 / FAIL-007]`. The second is renumbered to `[HUM-009 / FAIL-008]`,
  the first unused pair in the project's tagging sequence.
- **Introduce `InvalidExprUsageError`**, a new public exception that
  subclasses both `po.PocoError` and Python's built-in `TypeError`. It
  replaces the plain `TypeError` currently raised when an `Expr` is used in a
  boolean context (`if`, `assert`, `and`, `or`, `not`) or in a hash-requiring
  context (dict key, set member). This closes the gap where
  `errors/spec.md` promises "all documented library-specific failures SHALL
  be catchable through `except po.PocoError`," but these two intentional
  guardrails were plain, un-subclassed `TypeError`s. Existing code that
  catches plain `TypeError` continues to work unchanged, since
  `InvalidExprUsageError` **is a** `TypeError`.
- **Resolve the `distinct()` return-type contradiction** between
  `pipeline/spec.md` (unmodified: `po.distinct(*exprs)` returns a
  `PipelineStep` whose data component is a stateful transducer) and
  `add-advanced-data-integrity`'s `transducer/spec.md` delta (which states
  `po.distinct(...)` itself "SHALL return a stateful transducer"). The
  wording in the integrity delta is corrected to match the pipeline
  capability's contract, which is the one already implemented as `ADDED` in
  `add-core-architecture` and therefore authoritative.
- **BREAKING** (pre-implementation only, no running code exists yet):
  `Expr.__bool__` and `Expr.__hash__` raise `InvalidExprUsageError` instead
  of raw `TypeError`. Anyone who already wrote `except TypeError:` is
  unaffected; anyone who wrote `except po.PocoError:` and expected it to
  catch these is now correctly covered.

## Impact

- Affected specs: `expression`, `dataframe`, `errors` (all in
  `add-core-architecture`); `transducer` (in `add-advanced-data-integrity`)
- Affected code: none yet — no implementation exists (`poco/po.py` currently
  contains only two empty stub classes), so this is a zero-cost correction
  window
- No affected tests: `tests/` currently contains only import smoke tests
