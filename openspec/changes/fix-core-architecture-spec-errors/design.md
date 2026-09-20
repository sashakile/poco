## Context

`errors/spec.md` establishes a public exception taxonomy rooted in
`PocoError` and states that `except po.PocoError` SHALL catch "all documented
library-specific failures." `expression/spec.md` independently specifies two
deliberate guardrails — `Expr.__bool__` and `Expr.__hash__` — that raise raw
Python `TypeError`. Both are correct as isolated requirements; together they
contradict the taxonomy's catch-all promise. Fixing this by simply wrapping
these into a `PocoError`-only subclass would break the (currently
unspecified but reasonably assumed) expectation that misusing `Expr` in a
boolean or hash context raises something `isinstance`-compatible with
`TypeError`, since that is the native Python protocol these dunder methods
participate in.

## Goals / Non-Goals

Goals:
- Every intentionally-raised poco error is catchable via `except po.PocoError`
- Native Python protocol expectations (`TypeError` from `__bool__`/`__hash__`
  misuse) continue to hold for callers who don't know about poco's taxonomy
- No change to any requirement's observable message text or scenario outcome
  beyond the exception's type

Non-Goals:
- Auditing every other exception in the codebase for the same gap (out of
  scope for this fix; a future change should grep the full spec set for
  every place a bare Python exception is raised by poco's own guardrail code,
  as opposed to passing through from user-authored arithmetic)

## Decisions

- **Decision:** Add `InvalidExprUsageError(PocoError, TypeError)` — multiple
  inheritance, in that MRO order — as a new public exception class. Use it
  everywhere poco itself deliberately raises a `TypeError`-shaped error as a
  usage guardrail (as opposed to a pass-through from user arithmetic, which
  remains governed by "Documented pass-through exceptions" and is
  unaffected by this change).
  - Alternatives considered: (a) Leave as plain `TypeError` and narrow the
    taxonomy's catch-all claim instead — rejected, because it weakens a
    promise that's cheap to keep and the whole point of having a base
    exception class is to not need to remember which errors are "the poco
    kind" and which aren't. (b) Make it `PocoError`-only, no `TypeError`
    inheritance — rejected, because `__hash__` raising something that isn't
    a `TypeError` (or subclass) violates the hashing protocol's contract
    that unhashability is signaled via `TypeError`; some containers and
    `dataclasses.field(hash=...)` machinery specifically check for that.
- **Decision:** `Expr.__hash__` is implemented as an explicit method that
  raises `InvalidExprUsageError`, not via the `__hash__ = None` idiom the
  spec currently describes. Setting `__hash__ = None` is how you make an
  object *conventionally* unhashable and always raises a plain `TypeError`
  with a fixed, un-customizable message — it does not support subclassing
  the raised exception. An explicit `def __hash__(self): raise
  InvalidExprUsageError(...)` preserves `hash(obj)` raising a `TypeError`
  subclass while allowing the custom message and `PocoError` membership.

## Risks / Trade-offs

- Multiple inheritance from a builtin (`TypeError`) plus a library base
  (`PocoError`) means `PocoError`'s own `__init__` (per "Structured exception
  diagnostics": `.code`, `.message`, `.details`) must remain compatible with
  `TypeError.__init__`'s signature. Mitigation: `PocoError.__init__` accepts
  `*args` and forwards them to `Exception.__init__` (which `TypeError`
  inherits), so no MRO conflict arises as long as `PocoError` doesn't
  override `__new__`.

## Migration Plan

No running code exists yet (see proposal.md Impact). This is a specification
correction with no migration required. Once implemented, `except
po.PocoError` and `except TypeError` both remain valid for these two cases.

## Open Questions

- Should every other poco-raised guardrail exception (e.g., anything else
  that currently documents a raw `TypeError`/`ValueError`/`KeyError` pass-
  through that is actually poco's own code raising it, not truly passing
  through from user code) get the same dual-inheritance treatment? Flagged
  as a non-goal here; worth a dedicated audit change once the full exception
  surface exists in code and can be grepped mechanically.
