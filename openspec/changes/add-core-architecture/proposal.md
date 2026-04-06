# Change: Add core architecture — schema, expressions, transducers, DataFrame, pipeline

## Why

poxo currently has empty `Series` and `DataFrame` stubs. We need to build the
foundational architecture before any features: the schema system, expression
tree, reducer/transducer protocol, pipeline steps as product category, and a
single always-lazy DataFrame type.

## What Changes

- Add `@po.schema` decorator (implies `@dataclass`, field descriptors return `Expr`)
- Add expression tree (`Expr`) with operator overloading (including reverse ops)
- Add three-phase reducer protocol (init/step/complete) with formal algebraic laws
- Add `Reduced` sentinel for early termination
- Add built-in reducers: to_list, count, sum_reducer, mean, min_reducer, max_reducer
- Add column-bound reducers: sum_of, mean_of, min_of, max_of, count_of
- Add transducer system with left-to-right composition via `|` and `comp(first=, second=)`
- Add pipeline steps as product category: `(data: Transducer, schema: SchemaTransform)`
- Replace current `Series`/`DataFrame` stubs with single always-lazy `DataFrame`
- Add `|` pipe operator for clean endomorphic pipeline composition
- Materialization triggers: repr, iter, len, collect()
- Add schema inference with numeric type promotion and `schema.to_code()` bridge
- Add `groupby` as endomorphism-preserving pipeline step (not a separate type)
- Add equi-join with column collision handling and lazy evaluation

## Impact

- Affected specs: schema, expression, transducer, dataframe, pipeline (all new)
- Affected code: `poco/` (full rewrite of stubs)
- **BREAKING**: Removes `Series` class. Removes empty-constructor `DataFrame`.
- No `GroupedDataFrame` type — `groupby` returns a `PipelineStep` to preserve the `DataFrame | step → DataFrame` endomorphism.
