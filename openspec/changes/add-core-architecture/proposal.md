# Change: Add core architecture — schema, expressions, transducers, DataFrame, pipeline

## Why

poxo currently has empty `Series` and `DataFrame` stubs. We need to build the
foundational architecture before any features: the schema system, expression
tree, reducer/transducer protocol, pipeline steps as product category, and a
single always-lazy DataFrame type.

## What Changes

- Add `@po.schema` decorator (implies `@dataclass`, field descriptors return `Expr`)
- Add expression tree (`Expr`) with operator overloading (including reverse ops)
- Add three-arity reducer protocol (init/step/complete) with formal algebraic laws
- Add `Reduced` sentinel for early termination
- Add transducer system with left-to-right composition via `|` and `comp(first=, second=)`
- Add pipeline steps as product category: `(data: Transducer, schema: SchemaTransform)`
- Replace current `Series`/`DataFrame` stubs with single always-lazy `DataFrame`
- Add `|` pipe operator for clean endomorphic pipeline composition
- Materialization triggers: repr, iter, len, collect()
- Add schema inference and `schema.to_code()` for exploration → production bridge

## Impact

- Affected specs: schema, expression, transducer, dataframe, pipeline (all new)
- Affected code: `poxo/` (full rewrite of stubs)
- **BREAKING**: Removes `Series` class. Removes empty-constructor `DataFrame`.
