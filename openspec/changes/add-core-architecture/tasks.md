## 1. Expression system
- [ ] 1.1 Write tests for Expr: ColumnRef, Literal, BinOp, UnaryOp construction
- [ ] 1.2 Write tests for operator overloading (__gt__, __lt__, __eq__, __add__, &, |, ~, __radd__, __rsub__, etc.)
- [ ] 1.3 Write tests for __eq__ returning Expr (not bool), __hash__ consistency, .equals()
- [ ] 1.4 Write tests for Expr evaluation against a row dict
- [ ] 1.5 Write tests for strict errors: ColumnNotFoundError, NullValueError
- [ ] 1.6 Write tests for evaluation homomorphism: eval(combine(e1,e2), row) == combine(eval(e1,row), eval(e2,row))
- [ ] 1.7 Implement `Expr` base class with __hash__, .equals(), operator overloading (including reverse ops)
- [ ] 1.8 Implement `ColumnRef(name, dtype)`, `Literal(value)`, `BinOp`, `UnaryOp`
- [ ] 1.9 Implement Expr evaluation (eval method against row dict)
- [ ] 1.10 Implement `ColumnNotFoundError`, `NullValueError` with helpful messages
- [ ] 1.11 Implement `required_columns` extraction from Expr tree
- [ ] 1.12 Hypothesis property tests: evaluation homomorphism, Expr operator laws

## 2. Schema system
- [ ] 2.1 Write tests for ColumnDescriptor (class access → Expr, instance access → value, instance __eq__ returns bool)
- [ ] 2.1a Write tests for schema subclassing (@po.schema class Employee(Person))
- [ ] 2.2 Write tests for @po.schema decorator (implies @dataclass, preserves dataclasses.fields())
- [ ] 2.3 Write tests for schema inference from dict and rows
- [ ] 2.4 Write tests for mixed-type column → TypeError
- [ ] 2.5 Write tests for schema.to_code() producing valid Python
- [ ] 2.6 Implement `ColumnDescriptor` with __get__, __set__, __set_name__
- [ ] 2.7 Implement `@po.schema` decorator
- [ ] 2.8 Implement schema inference (type detection from values)
- [ ] 2.9 Implement `schema.to_code()`
- [ ] 2.10 Implement `SchemaError` with helpful messages

## 3. Reducer protocol
- [ ] 3.1 Write tests for Reducer protocol (init, step, complete)
- [ ] 3.2 Write tests for Reduced sentinel (early termination, idempotence)
- [ ] 3.3 Write tests for reduce() driving the three-phase protocol
- [ ] 3.4 Write tests for basic reducers: to_list, count, sum_reducer, mean
- [ ] 3.5 Write tests for reducer laws: empty input validity, resumability
- [ ] 3.6 Implement `Reducer` protocol and `Reduced` sentinel type
- [ ] 3.7 Implement `reduce(reducer, collection)` with Reduced checking
- [ ] 3.8 Implement basic reducers: `to_list`, `to_dict`, `count`, `sum_reducer`, `mean`
- [ ] 3.9 Hypothesis PBT: reducer laws (determinism, empty input, resumability, Reduced validity)

## 4. Transducer system
- [ ] 4.1 Write tests for filtering, mapping, taking, dropping transducers
- [ ] 4.2 Write tests for taking early termination (items after n not processed)
- [ ] 4.3 Write tests for left-to-right composition order with non-commutative transducers
- [ ] 4.4 Write tests for composition associativity
- [ ] 4.5 Write tests for identity transducer (neutral element of composition)
- [ ] 4.6 Write tests for transducer-reducer compatibility laws (init, complete, Reduced propagation)
- [ ] 4.7 Write tests for cross-layer composition (high-level | low-level)
- [ ] 4.8 Implement `Transducer` protocol with __or__ for left-to-right composition
- [ ] 4.9 Implement core transducers: `filtering`, `mapping`, `taking`, `dropping`
- [ ] 4.10 Implement identity transducer and `comp(first=, second=)`
- [ ] 4.11 Hypothesis PBT: composition associativity, identity laws (with non-commutative xfs)

## 5. Pipeline steps (product category)
- [ ] 5.1 Write tests for SchemaTransform: Identity, Project
- [ ] 5.2 Write tests for SchemaTransform composition
- [ ] 5.3 Write tests for PipelineStep component-wise composition
- [ ] 5.4 Write tests for where(expr) → PipelineStep (data=filtering, schema=Identity)
- [ ] 5.5 Write tests for select(*exprs) → PipelineStep (data=column_dropper, schema=Project)
- [ ] 5.6 Write tests for required_columns on Expr-based pipeline steps
- [ ] 5.7 Implement `SchemaTransform` (Identity, Project, Extend, Rename)
- [ ] 5.8 Implement `PipelineStep` with component-wise __or__ composition
- [ ] 5.9 Implement `where(expr)` → PipelineStep
- [ ] 5.10 Implement `select(*exprs)` → PipelineStep

## 6. DataFrame (single lazy type)
- [ ] 6.1 Write tests for DataFrame construction from dict and rows
- [ ] 6.2 Write tests for empty DataFrame (0 rows, 0 columns, empty-column-no-schema → error)
- [ ] 6.3 Write tests for strict validation errors (column length, schema mismatch)
- [ ] 6.4 Write tests for DataFrame.__or__(step) → new DataFrame (endomorphism)
- [ ] 6.5 Write tests for DataFrame immutability (| does not modify original)
- [ ] 6.6 Write tests for lazy evaluation: plan preserved until materialization
- [ ] 6.7 Write tests for materialization triggers: repr, iter, len, collect()
- [ ] 6.8 Write tests for collect() caching and cache invalidation on plan extension
- [ ] 6.9 Write tests for head(n) non-mutating + early termination
- [ ] 6.10 Write tests for schema mismatch on pipe → SchemaError (Expr-based steps only)
- [ ] 6.11 Write tests for low-level transducers bypassing schema check
- [ ] 6.12 Write tests for PipelineStep.__call__(df) convenience
- [ ] 6.13 Write tests for po.reduce(reducer, df) forces collection
- [ ] 6.14 Write tests for DataFrame.__repr__ (small: all rows, large: first 5 + last 5)
- [ ] 6.15 Write tests for DataFrame._repr_html_ for Jupyter
- [ ] 6.16 Implement lazy `DataFrame` with plan, columnar storage, and caching
- [ ] 6.17 Implement DataFrame construction from dict and rows with validation
- [ ] 6.18 Implement DataFrame.__or__(step) returning new DataFrame
- [ ] 6.19 Implement materialization: collect(), __iter__, __len__, __repr__, _repr_html_
- [ ] 6.20 Implement head(n) and schema mismatch validation
- [ ] 6.21 Implement PipelineStep.__call__(df) convenience
- [ ] 6.22 Implement po.reduce(reducer, df, transducer=)
- [ ] 6.23 Remove `Series` class

## 7. Schema validation and typing
- [ ] 7.1 Write tests for DataFrame[Schema] generic typing
- [ ] 7.2 Write tests for auto-generated schema on select/project via SchemaTransform
- [ ] 7.3 Implement `DataFrame[Schema]` via __class_getitem__
- [ ] 7.4 Implement auto-generated schema from SchemaTransform chain
- [ ] 7.5 Implement optional target schema parameter for typed results

## 8. Integration and polish
- [ ] 8.1 Update `__init__.py` exports (full public API surface per design.md)
- [ ] 8.2 Update tests for new API (remove old Series/DataFrame tests)
- [ ] 8.3 Update README examples to use new API
- [ ] 8.4 Update llm.txt and openspec/project.md
