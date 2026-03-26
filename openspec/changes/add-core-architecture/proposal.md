# Change: Add core architecture — schema, expressions, transducers, DataFrame, pipeline

## Why

poxo currently has empty `Series` and `DataFrame` stubs. We need to build the
foundational architecture before any features: the schema system, expression
tree, reducer/transducer protocol, lazy DataFrame, and pipe composition.

## What Changes

- Add `@po.schema` decorator (implies `@dataclass`, field descriptors return `Expr`)
- Add expression tree (`Expr`) with operator overloading for query building
- Add three-arity reducer protocol (init/step/complete) and transducer composition
- Replace current `Series`/`DataFrame` stubs with lazy `DataFrame` + `collect()`
- Add `|` pipe operator for composing transducers and applying them to DataFrames
- Add `reduce` and `project` as the two primitive operations
- Add schema inference and `schema.to_code()` for exploration → production bridge

## Impact

- Affected specs: schema, expression, transducer, dataframe, pipeline (all new)
- Affected code: `poxo/` (full rewrite of stubs)
- **BREAKING**: Removes `Series` class. Removes empty-constructor `DataFrame`.
