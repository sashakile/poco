# Project Context

## Purpose

poxo (poco) is a pure Python DataFrame library designed for small exploratory
and teaching examples. It is **not** a pandas clone — it aims to identify the
true abstract interfaces needed for data operations, grounded in category theory.

Goals:
- Clean, ergonomic API that is simpler to understand than pandas
- Algebraic structure for composability and parallelizability
- Swappable computation/storage backends via adapters (pure Python default)
- Lazy-first evaluation ("poco is a lazy panda")
- Learn from dataframes.jl, Clojure transducers, and Spivak's functorial data migration

## Tech Stack

- Python (pure, no required dependencies)
- Package manager: uv
- Build system: hatchling
- Testing: pytest + hypothesis (property-based)
- Linting: pylint
- CI: GitHub Actions (Python 3.10–3.12)

## Project Conventions

### Code Style

- Strict error handling: raise early on bad column names, type mismatches. No silent coercion.
- Symbolic column accessors (`_.col`), no string-based column references
- Pipe composition via `|` operator for clean data pipelines
- Bilingual documentation (Spanish and English), pure markdown

### Architecture Patterns

**CT foundations (Spivak's framework):**
- Schema = category (column names + types as objects, relationships as morphisms)
- DataFrame instance = functor from schema to Set
- Operations follow the adjoint triple Σ ⊣ Δ ⊣ Π:
  - Δ (pullback) → select, project, rename
  - Σ (left Kan extension) → groupby-combine, aggregate
  - Π (right Kan extension) → join, normalize

**Lazy Pipeline IR:**
- Operations build a high-level `PipelineStep` tree, not immediate results
- Each step contains a `DataTransform` (transducer) and a `SchemaTransform`
- Materialization occurs fresh on each trigger (iteration, repr, collect)
- Enables backend-agnostic optimization (predicate pushdown, fusion)

**Row Model Contract:**
- A single shared contract for materialized rows: `dict[str, object]`
- Keys are insertion-ordered and correspond to the schema order
- Used across expression evaluation, reducers, and transducers

**Three-Phase Reducer Protocol:**
- `init()`: Produce initial accumulator
- `step(acc, item)`: Incorporate item, supports early termination via `Reduced(acc)`
- `complete(acc)`: Finalize result (e.g., divide sum by count for mean)
- Reducers drive the physical execution of all DataFrame operations

**Transducers:**
- Composable transformations decoupled from input/output (Clojure-inspired)
- Natural transformations between fold functors
- Stateful transducers (e.g., `taking`, `distinct`) manage isolated closure state

### Testing Strategy

- Example-based tests (pytest) for concrete behavior
- Property-based tests (hypothesis) to verify algebraic laws hold
  (functor laws, monoid associativity, adjunction round-trips)
- TDD: write failing test first, make it pass, then tidy

### Git Workflow

- Main branch: `main`
- Pre-commit hooks via prek (trailing whitespace, EOF, yaml, typos, beads)
- Commits should be atomic and well-described

## Domain Context

Key CT concepts used in this project:
- **Functor**: structure-preserving map (column transforms preserve DataFrame shape)
- **Natural transformation**: morphism between functors (pipeline step)
- **Adjunction**: pair of functors with universal property (lazy/eager, groupby/combine)
- **Monoid**: associative binary operation with identity (DataFrame concat)
- **Free monad**: expression tree that defers interpretation (lazy IR)
- **Transducer**: reducer transformer, polymorphic in accumulator type

Reference implementations to study:
- AlgebraicJulia ACSets.jl — functorial data migration in Julia
- ibis — lazy IR + multi-backend in Python
- siuba — symbolic column refs + pipe in Python

## Important Constraints

- Pure Python: no required dependencies (numpy etc. are optional adapters)
- Must work for small examples without heavyweight infrastructure
- API ergonomics over feature parity with pandas
- Every operation should have a clear algebraic justification

## External Dependencies

None required. Optional adapters:
- numpy (compute/storage backend)
- pyrsistent / immutables (persistent data structures)
- hypothesis (property-based testing, dev only)
