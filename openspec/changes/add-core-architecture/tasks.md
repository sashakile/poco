## 1. Row model
- [ ] 1.1 Write tests for the shared materialized row contract (`dict[str, value]`, insertion-ordered keys, copy-on-yield)
- [ ] 1.2 Implement the row contract documentation and helpers used by expression, reducer, and DataFrame layers
- [ ] 1.3 Tidy row helpers and shared test fixtures after the contract passes

## 2. Expression system
- [ ] 2.1 Write tests for Expr node construction and operator overloading
- [ ] 2.2 Write tests for Expr evaluation against the shared row contract
- [ ] 2.3 Write tests for Expr errors and null-handling helpers
- [ ] 2.4 Implement `Expr`, node variants, evaluation, `required_columns`, and error types
- [ ] 2.5 Add property tests for evaluation homomorphism and operator laws
- [ ] 2.6 Tidy expression internals after tests pass

## 3. Schema system
- [ ] 3.1 Write tests for `@po.schema`, descriptors, inheritance, inference, and `schema.to_code()`
- [ ] 3.2 Implement `ColumnDescriptor`, `@po.schema`, schema inference, subclass validation, and `SchemaError`
- [ ] 3.3 Tidy schema validation and descriptor layering after tests pass

## 4. Reducer protocol
- [ ] 4.1 Write tests for `Reducer`, `Reduced`, built-in reducers, and reducer laws
- [ ] 4.2 Implement the three-phase reducer protocol, generic `po.reduce`, `Reduced`, and built-in reducers
- [ ] 4.3 Tidy reducer abstractions and property-test fixtures after tests pass

## 5. Transducer system
- [ ] 5.1 Write tests for `filtering`, `mapping`, `taking`, `dropping`, identity, and left-to-right composition
- [ ] 5.2 Implement the transducer protocol and core transducers on top of the reducer protocol
- [ ] 5.3 Add property tests for associativity, identity, and state isolation
- [ ] 5.4 Tidy stateful transducer wrappers after tests pass

## 6. Aggregations
- [ ] 6.1 Write tests for `sum_of`, `mean_of`, `min_of`, `max_of`, and `count_of`
- [ ] 6.2 Write tests for aggregation behavior on empty input and partial reducers
- [ ] 6.3 Implement Expr-bound aggregation reducers and their `required_columns`
- [ ] 6.4 Tidy aggregation adapters after tests pass

## 7. Pipeline algebra and operations
- [ ] 7.1 Write tests for `SchemaTransform`, `PipelineStep`, and validated step composition
- [ ] 7.2 Write tests for high-level step factories: `where`, `select`, `derive`, `sort_by`, `distinct`, and `comp`
- [ ] 7.3 Implement `SchemaTransform`, `PipelineStep`, schema-compatibility checks, and pipeline-step factories
- [ ] 7.4 Tidy pipeline algebra and validation boundaries after tests pass

## 8. DataFrame facade
- [ ] 8.1 Write tests for DataFrame construction, immutability, plan extension, materialization triggers, display, explain, export, and typing
- [ ] 8.2 Implement immutable lazy `DataFrame`, `DataFrame.__or__`, `head`, `collect`, iteration, display, exports, and `DataFrame[Schema]`
- [ ] 8.3 Implement DataFrame-aware overloads for `po.reduce(..., df)` and pipe-time schema validation
- [ ] 8.4 Remove `Series`
- [ ] 8.5 Tidy DataFrame facade boundaries after tests pass

## 9. Relational operations
- [ ] 9.1 Write tests for `groupby` as a pipeline step and `join` as a lazy DataFrame operation
- [ ] 9.2 Write tests for join types (`inner`, `left`, `right`, `outer`) and invalid `how`
- [ ] 9.3 Write tests for custom suffixes, self-join, and multi-column equi-join predicates
- [ ] 9.4 Write tests for relational output schemas, nullable-side Optional promotion, unsupported predicates, and downstream composition
- [ ] 9.5 Implement `po.groupby`, `po.join`, relational validation, and relational schema generation
- [ ] 9.6 Tidy relational planners and schema builders after tests pass

## 10. Error model and diagnostics
- [ ] 10.1 Write tests for public exception taxonomy, structured diagnostic fields, and documented pass-through exceptions
- [ ] 10.2 Implement public error classes, exception translation rules, message-quality standards, and cause chaining
- [ ] 10.3 Add regression tests for every new public exception path and document common failure modes

## 11. Integration and polish
- [ ] 11.1 Update exports and public API documentation
- [ ] 11.2 Update tests, README examples, `llm.txt`, and `openspec/project.md`
- [ ] 11.3 Validate that the capability graph remains acyclic as the implementation lands
