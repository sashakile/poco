## 1. Expression system
- [ ] 1.1 Write tests for Expr: ColumnRef, Literal, BinOp, UnaryOp construction
- [ ] 1.2 Write tests for operator overloading (__gt__, __lt__, __eq__, __add__, &, |, ~, __radd__, __rsub__, etc.)
- [ ] 1.3 Write tests for __eq__ returning Expr (not bool), __hash__ consistency, .equals()
- [ ] 1.4 Write tests for Expr evaluation against a row dict
- [ ] 1.5 Write tests for strict errors: ColumnNotFoundError, NullValueError
- [ ] 1.6 Implement `Expr` base class with __hash__, .equals(), operator overloading
- [ ] 1.7 Implement `ColumnRef(name, dtype)`, `Literal(value)`, `BinOp`, `UnaryOp`
- [ ] 1.8 Implement Expr evaluation (eval method against row dict)
- [ ] 1.9 Implement `ColumnNotFoundError`, `NullValueError` with helpful messages
- [ ] 1.10 Hypothesis property tests: Expr operator laws

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
- [ ] 3.2 Write tests for Reduced sentinel (early termination)
- [ ] 3.3 Write tests for reduce() driving the three-phase protocol
- [ ] 3.4 Write tests for basic reducers: to_list, count, sum_reducer, mean
- [ ] 3.5 Implement `Reducer` protocol and `Reduced` sentinel type
- [ ] 3.6 Implement `reduce(reducer, collection)` with Reduced checking
- [ ] 3.7 Implement basic reducers: `to_list`, `to_dict`, `count`, `sum_reducer`, `mean`
- [ ] 3.8 Hypothesis property tests: reducer laws (identity, associativity)

## 4. Transducer system
- [ ] 4.1 Write tests for filtering, mapping, taking, dropping transducers
- [ ] 4.2 Write tests for taking early termination (items after n not processed)
- [ ] 4.3 Write tests for transducer composition (|) and associativity
- [ ] 4.4 Write tests for identity transducer and comp() with no args
- [ ] 4.5 Write tests for where(expr) and select(*exprs) high-level constructors
- [ ] 4.5a Write tests for required_columns on Expr-based transducers
- [ ] 4.5b Write tests for cross-layer composition (high-level | low-level)
- [ ] 4.6 Implement `Transducer` protocol with __or__ for composition
- [ ] 4.7 Implement core transducers: `filtering`, `mapping`, `taking`, `dropping`
- [ ] 4.8 Implement identity transducer and `comp(*transducers)`
- [ ] 4.9 Implement `where(expr)` → filtering transducer from Expr
- [ ] 4.10 Implement `select(*exprs)` → project transducer from Exprs
- [ ] 4.11 Hypothesis property tests: composition associativity, identity laws

## 5. DataFrame and LazyFrame
- [ ] 5.1 Write tests for DataFrame construction from dict and rows
- [ ] 5.2 Write tests for empty DataFrame (0 rows, 0 columns, filter-to-empty)
- [ ] 5.3 Write tests for strict validation errors (column length, schema mismatch)
- [ ] 5.4 Write tests for DataFrame.__repr__ (small and large)
- [ ] 5.5 Write tests for DataFrame.__or__(transducer) → LazyFrame
- [ ] 5.6 Write tests for LazyFrame immutability (| does not modify original)
- [ ] 5.7 Write tests for LazyFrame.collect() materialization
- [ ] 5.8 Write tests for LazyFrame.head(n) non-mutating + early termination
- [ ] 5.9 Write tests for LazyFrame.__repr__ shows plan not data
- [ ] 5.10 Write tests for schema mismatch on pipe → SchemaError (Expr-based transducers only)
- [ ] 5.10a Write tests for low-level transducers bypassing schema check
- [ ] 5.10b Write tests for double collect() on same LazyFrame
- [ ] 5.11 Write tests for Transducer.__call__(df) convenience
- [ ] 5.12 Write tests for po.reduce(reducer, df) user-facing
- [ ] 5.13 Implement eager `DataFrame` with columnar storage
- [ ] 5.14 Implement DataFrame construction from dict and rows with validation
- [ ] 5.15 Implement DataFrame.__repr__ and _repr_html_
- [ ] 5.16 Implement `LazyFrame` with immutable plan and collect()
- [ ] 5.17 Implement DataFrame.__or__ and LazyFrame.__or__
- [ ] 5.18 Implement LazyFrame.head(n) and LazyFrame.__repr__
- [ ] 5.19 Implement Transducer.__call__(df) convenience
- [ ] 5.20 Implement po.reduce(reducer, df, transducer=)
- [ ] 5.21 Remove `Series` class

## 6. Schema validation and typing
- [ ] 6.1 Write tests for DataFrame[Schema] generic typing
- [ ] 6.2 Write tests for auto-generated schema on select/project
- [ ] 6.3 Implement `DataFrame[Schema]` generic typing
- [ ] 6.4 Implement auto-generated schema for operations that change column set
- [ ] 6.5 Implement optional target schema parameter for typed results

## 7. Integration and polish
- [ ] 7.1 Update `__init__.py` exports (full public API surface per design.md)
- [ ] 7.2 Update tests for new API (remove old Series/DataFrame tests)
- [ ] 7.3 Update README examples to use new API
- [ ] 7.4 Update llm.txt and openspec/project.md
