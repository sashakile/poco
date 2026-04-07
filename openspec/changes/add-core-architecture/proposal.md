# Change: Add core architecture — row model, schema, expressions, reducers, pipeline, DataFrame, relational ops

## Why

poxo currently has empty `Series` and `DataFrame` stubs. We need to build the
foundational architecture before any features: a shared row model, schema
system, expression tree, reducer/transducer protocol, pipeline algebra, a
single always-lazy DataFrame type, and relational operations.

## What Changes

- Add shared row contract for expression, reducer, and pipeline evaluation
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
- Add relational operations: `groupby` as an endomorphism-preserving pipeline
  step and `join` as a lazy DataFrame-producing function
- Separate capability boundaries so the spec graph is a DAG rather than a
  cycle between DataFrame, pipeline, and expression contracts

## Impact

- Affected specs: row-model, schema, expression, reducer, transducer,
  aggregation, pipeline, dataframe, relational
- Affected code: `poco/` (full rewrite of stubs)
- **BREAKING**: Removes `Series` class. Removes empty-constructor `DataFrame`.
- No `GroupedDataFrame` type — `groupby` returns a `PipelineStep` to preserve the `DataFrame | step → DataFrame` endomorphism.
