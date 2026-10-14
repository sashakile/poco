---
id: schema
kind: intent
statement: "THE system SHALL define schemas via a dataclass-implying decorator with declared, inferred, and inherited forms that constrain types, names, ordering, and code generation"
---

# Schema model

## Constraints

| id | kind | expr | traces_to |
|----|------|------|-----------|
| cs.decorator | invariant | `@po.schema` implies `@dataclass`: class-level field access returns Expr nodes, instance access returns values, dataclass init/repr/eq and `dataclasses.fields()` are preserved | [[schema]] |
| cs.runtime_object | invariant | A runtime schema is a declared or dynamically created `@po.schema` class; class-level access returns Exprs in both cases | [[schema]] |
| cs.inference | invariant | Schemas are inferred from dict or row data as dynamic schema classes; incompatible type mixes, unsupported homogeneous types, and all-None columns raise `SchemaError` with suggestions | [[schema]] |
| cs.numeric_promotion | invariant | Compatible numerics promote along `bool < int < float`, orthogonal to nullability (None yields the Optional variant); NaN is a valid float, not None | [[schema]] |
| cs.supported_types | invariant | Column dtypes are `int`, `float`, `str`, `bool`, and their Optional variants; unsupported declared types raise `SchemaError` at decoration naming the type and supported set | [[schema]] |
| cs.name_constraints | invariant | Column names must be valid Python identifiers and not keywords; violations raise `SchemaError` | [[schema]] |
| cs.to_code | invariant | `schema.to_code()` returns a valid `@po.schema` class definition equivalent to the schema, including the import | [[schema]] |
| cs.subclassing | invariant | Single inheritance merges parent-then-child fields; overrides must restate the exact type; type-changing overrides and diamond inheritance raise `SchemaError` | [[schema]] |
| cs.zero_field | invariant | A zero-field schema is valid and consistent with empty DataFrame construction | [[schema]] |
| cs.field_ordering | invariant | Field order is deterministic: declaration order, parent-then-child, first-dict/row insertion order for inference, and operation-defined order for auto-generated schemas; row keys always match schema order | [[schema]] |
| cs.cross_family | invariant | Promotion applies only within the numeric family; numeric+str mixes raise `SchemaError`; all-bool stays bool | [[schema]] |

## Model

### States

- `undeclared`
- `declared`
- `inferred`
- `rejected`

### Transitions

| id | from | to | guard |
|----|------|----|-------|
| t_declare | undeclared | declared | [[schema.cs.supported_types]] |
| t_infer | undeclared | inferred | [[schema.cs.numeric_promotion]] |
| t_reject_family | inferred | rejected | [[schema.cs.cross_family]] |
| t_reject_names | undeclared | rejected | [[schema.cs.name_constraints]] |
| t_subclass | declared | declared | [[schema.cs.subclassing]] |
| t_codegen | declared | declared | [[schema.cs.to_code]] |

## Properties

| id | kind | derives_from | generator | predicate |
|----|------|--------------|-----------|-----------|
| p.decorator | unit | [[schema.cs.decorator]] | schema classes accessed at class and instance level | class access yields ColumnRef Exprs; instance access yields values; dataclass behavior holds |
| p.runtime_object | unit | [[schema.cs.runtime_object]] | declared and dynamic schemas | both expose Exprs on class-level access |
| p.inference | unit | [[schema.cs.inference]] | dict and row data including invalid mixes | inferred schemas match fields; invalid data raises the specified SchemaErrors |
| p.numeric_promotion | unit | [[schema.cs.numeric_promotion]] | numeric columns with mixed widths, None, and NaN | widest promotion with correct Optional application |
| p.supported_types | unit | [[schema.cs.supported_types]] | declarations over supported and unsupported types | unsupported types raise at decoration; Optional variants accepted |
| p.name_constraints | unit | [[schema.cs.name_constraints]] | column names with spaces, keywords, leading digits | `SchemaError` for each violation class |
| p.to_code | unit | [[schema.cs.to_code]] | inferred schemas round-tripped through exec | generated code reproduces an equivalent schema |
| p.subclassing | unit | [[schema.cs.subclassing]] | subclass declarations including overrides and diamonds | merging, override, and diamond rules hold |
| p.zero_field | unit | [[schema.cs.zero_field]] | empty schema declarations and empty DataFrames | zero-column schemas construct and iterate |
| p.field_ordering | unit | [[schema.cs.field_ordering]] | declared, inherited, inferred, and generated schemas | field order follows the deterministic rules |
| p.cross_family | unit | [[schema.cs.cross_family]] | mixed numeric/str/bool columns | cross-family mixes raise; all-bool stays bool |

## Purpose

Anchor every layer's column typing in one declarative, introspectable
schema model with deterministic ordering and executable code generation.

## ADDED Requirements

### Requirement: Schema declaration via `@po.schema` decorator

`@po.schema` SHALL imply `@dataclass` and produce a class where accessing a
field on the class (not an instance) returns an `Expr` node representing that
column. Accessing a field on an instance returns the actual value.

#### Scenario: Class access returns Expr

- **WHEN** a user accesses `Person.age` on a `@po.schema`-decorated class
- **THEN** the result SHALL be a `ColumnRef("age", dtype=int)` expression

#### Scenario: Instance access returns value

- **WHEN** a user creates `p = Person("Ana", 30)` and accesses `p.age`
- **THEN** the result SHALL be `30`

#### Scenario: Dataclass behavior preserved

- **WHEN** a user applies `@po.schema` to a class with typed fields
- **THEN** the class SHALL behave as a `@dataclass` (init, repr, eq)

#### Scenario: Instance equality uses dataclass __eq__, not Expr

- **WHEN** a user compares `Person("Ana", 30) == Person("Ana", 30)`
- **THEN** the result SHALL be `True` (Python `bool`), using the
  `@dataclass`-generated `__eq__`, not `Expr.__eq__`

#### Scenario: dataclasses.fields() introspection preserved

- **WHEN** a user calls `dataclasses.fields(Person)` on a `@po.schema` class
- **THEN** it SHALL return correct field metadata (name, type, default)
  matching the original class definition

### Requirement: Runtime schema object

A runtime schema object SHALL be either a `@po.schema`-decorated class (for
declared schemas) or a dynamically created `@po.schema` class (for inferred
schemas). In both cases, class-level field access SHALL return `Expr` nodes.
The `DataFrame.schema` property that exposes this object is defined in
`dataframe/spec.md`.

#### Scenario: Declared schema returns Expr on class access

- **WHEN** a `@po.schema` class `Person` is used as a runtime schema
- **THEN** `Person.age` SHALL return a `ColumnRef("age", dtype=int)` expression

#### Scenario: Dynamically created schema returns Expr on class access

- **WHEN** a schema is dynamically created with fields `name: str` and `age: int`
- **THEN** class-level access on the schema SHALL return `Expr` nodes
- **AND** `DynSchema.age` SHALL return a `ColumnRef("age", dtype=int)` expression

### Requirement: Schema inference from data

The system SHALL infer a schema from dict or row-based data when no explicit
schema is provided. The inferred schema SHALL be a dynamically created
`@po.schema` class.

#### Scenario: Infer from dict

- **WHEN** a user creates `po.DataFrame({"name": ["Ana"], "age": [30]})`
- **THEN** `df.schema` SHALL have fields `name: str` and `age: int`

#### Scenario: Infer from rows

- **WHEN** a user creates `po.DataFrame([{"name": "Ana", "age": 30}])`
- **THEN** `df.schema` SHALL have fields `name: str` and `age: int`

#### Scenario: Incompatible types raise SchemaError on inference

- **WHEN** a user creates `po.DataFrame({"val": [1, "two", 3.0]})`
- **THEN** the system SHALL raise a `SchemaError` with a message identifying
  the column `"val"` and the incompatible types found (`int`, `str`, `float`)
- **AND** the error message SHALL suggest declaring an explicit schema

#### Scenario: Unsupported homogeneous type raises SchemaError on inference

- **WHEN** a user creates `po.DataFrame({"data": [{"a": 1}, {"b": 2}]})`
- **THEN** the system SHALL raise a `SchemaError` indicating that `dict` is
  not a supported column type and listing the supported types

#### Scenario: None values infer type from non-None values

- **WHEN** a user creates `po.DataFrame({"age": [30, None, 25]})`
- **THEN** the inferred type SHALL be `Optional[int]` (i.e., `int | None`)

#### Scenario: All-None column raises SchemaError

- **WHEN** a user creates `po.DataFrame({"age": [None, None, None]})`
- **THEN** the system SHALL raise a `SchemaError` because the column type
  cannot be inferred from all-None values
- **AND** the error message SHALL suggest providing an explicit schema

### Requirement: Numeric type promotion in inference

When a column contains compatible numeric types, the system SHALL promote to
the widest type in the hierarchy `bool < int < float`. This promotion SHALL be
orthogonal to nullability inference. If a numeric column also contains `None`,
the final type SHALL be the `Optional` variant of the promoted numeric type.

#### Scenario: int and float promote to float

- **WHEN** a user creates `po.DataFrame({"val": [1, 2.0, 3]})`
- **THEN** the inferred type SHALL be `float`

#### Scenario: Promotion interacts with nullability

- **WHEN** a user creates `po.DataFrame({"val": [1, 2.0, None]})`
- **THEN** types SHALL promote to `float` first, then nullability SHALL be
  applied, resulting in `Optional[float]` (i.e., `float | None`)

#### Scenario: bool and int promote to int

- **WHEN** a user creates `po.DataFrame({"val": [True, 1, 2]})`
- **THEN** the inferred type SHALL be `int`

#### Scenario: All-bool infers bool

- **WHEN** a user creates `po.DataFrame({"flag": [True, False, True]})`
- **THEN** the inferred type SHALL be `bool`

#### Scenario: NaN is a valid float, not None

- **WHEN** a user creates `po.DataFrame({"x": [1.0, float('nan'), 3.0]})`
- **THEN** the inferred type SHALL be `float` (not `Optional[float]`)
- **AND** `float('nan')` SHALL be treated as a valid `float` value

### Requirement: Supported column types

The system SHALL support the following Python types as column dtypes:
`int`, `float`, `str`, `bool`, and their `Optional` variants (`int | None`,
`float | None`, `str | None`, `bool | None`). Schema declaration with
unsupported types SHALL raise a `SchemaError` at decoration time naming
the unsupported type and listing supported types.

#### Scenario: Unsupported type in schema raises error

- **WHEN** a user declares `@po.schema class Bad: data: dict`
- **THEN** the system SHALL raise a `SchemaError` indicating `dict` is not
  a supported column type and listing the supported types

#### Scenario: Optional variant is supported

- **WHEN** a user declares `@po.schema class Row: age: int | None`
- **THEN** the schema SHALL accept `age` as `Optional[int]`

### Requirement: Column name constraints

The system SHALL require that column names are valid Python identifiers and
SHALL reject Python keywords as column names. Column names that are not valid
identifiers SHALL cause a SchemaError to be raised.

#### Scenario: Space in column name raises error

- **WHEN** `po.DataFrame({"first name": ["Ana"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating `"first name"`
  is not a valid Python identifier

#### Scenario: Python keyword as column name raises error

- **WHEN** `po.DataFrame({"class": ["A"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating `"class"` is a
  reserved Python keyword and cannot be used as a column name

#### Scenario: Column name starting with digit raises error

- **WHEN** `@po.schema class Bad: pass` with a field named `1age`
- **THEN** the system SHALL raise a `SchemaError` (Python rejects this
  at class definition time; the schema decorator need not handle it separately)

### Requirement: Schema to code bridge

`schema.to_code()` SHALL return a string containing a valid `@po.schema` class
definition that, when executed, produces an equivalent schema.

#### Scenario: Generate code from inferred schema

- **WHEN** a user calls `df.schema.to_code()` on a DataFrame with inferred schema
- **THEN** the output SHALL be a valid Python `@po.schema` class definition with correct field names and types

#### Scenario: Generated code includes import

- **WHEN** `to_code()` is called
- **THEN** the output SHALL include `from poco import po` and the `@po.schema` decorator

### Requirement: Schema subclassing

The system SHALL support single inheritance for `@po.schema`-decorated
classes. A `@po.schema`-decorated class MAY inherit from another
`@po.schema` class, and the subclass SHALL include all fields from the parent
plus its own fields.

Field overrides in a subclass SHALL be permitted only if the new type is
exactly equivalent to the parent's field type. Overrides that attempt to
change the type SHALL be rejected.

#### Scenario: Subclass inherits parent fields

- **WHEN** a user defines `@po.schema class Employee(Person): salary: float`
- **THEN** `Employee` SHALL have all fields from `Person` plus `salary`
- **AND** `Employee.salary` SHALL return a `ColumnRef("salary", dtype=float)` expression

#### Scenario: Identical field override is permitted

- **WHEN** a user defines `@po.schema class Worker(Person): age: int`
- **THEN** the schema SHALL be valid since `Worker` merely restates the `int` type

#### Scenario: Subclass field type override raises error

- **WHEN** a user defines `@po.schema class Bad(Person): age: str`
- **THEN** the system SHALL raise a `SchemaError` indicating that field `age`
  cannot change type from `int` to `str` in a subclass

#### Scenario: Diamond inheritance raises error

- **WHEN** a user defines `@po.schema class Bad(SchemaA, SchemaB): pass`
  where `SchemaA` and `SchemaB` are `@po.schema` classes with overlapping fields
- **THEN** the system SHALL raise a `SchemaError` indicating that multiple
  schema inheritance with overlapping fields is not supported

### Requirement: Zero-field schema is valid

A `@po.schema`-decorated class with no fields SHALL be valid and SHALL produce a schema
with zero columns. This SHALL be consistent with empty DataFrame construction from
`{}` and `[]`.

#### Scenario: Zero-field schema declaration

- **WHEN** a user defines `@po.schema class Empty: pass`
- **THEN** it SHALL produce a valid schema with 0 columns
- **AND** `dataclasses.fields(Empty)` SHALL return an empty tuple

#### Scenario: Zero-field schema with DataFrame

- **WHEN** a user constructs `po.DataFrame([], schema=Empty)`
- **THEN** a valid DataFrame with 0 columns and 0 rows SHALL be created

### Requirement: Schema field ordering is deterministic

Schema field order SHALL follow these rules:

- **Declared schema** (`@po.schema`): fields are ordered by declaration order
  in the class body
- **Inherited schema**: parent fields first (in parent declaration order),
  then child fields (in child declaration order)
- **Inferred schema from dict**: fields ordered by key insertion order of the
  first dict (for dict-of-lists, the dict's key order; for list-of-dicts, the
  first row's key order)
- **Auto-generated schema** (from `select`, `derive`, `groupby`, `join`):
  fields ordered as defined by the operation (`select`: argument order;
  `derive`: original columns then new columns in keyword order; `groupby`: key
  columns then aggregation columns in keyword order; `join`: see relational
  spec)

Row keys (`dict[str, object]`) always correspond to the schema field order.

#### Scenario: Inherited field ordering

- **WHEN** a user defines `@po.schema class Base: a: int; b: str` and
  `@po.schema class Child(Base): c: float`
- **THEN** `dataclasses.fields(Child)` SHALL return fields ordered `[a, b, c]`
  (parent first, then child)

#### Scenario: Inferred schema from dict

- **WHEN** a user creates `po.DataFrame({"z": [1], "a": [2], "m": [3]})`
- **THEN** the inferred schema field order SHALL be `[z, a, m]` (dict key
  insertion order)

### Requirement: Schema inference rejects incompatible type families

Type promotion SHALL apply only within the numeric family (`bool < int < float`).
Cross-family combinations (numeric + `str`) SHALL raise `SchemaError`.

#### Scenario: bool and str column raises SchemaError

- **WHEN** a user creates `po.DataFrame({"flag": [True, "yes"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating column `"flag"`
  has incompatible types `bool` and `str`

#### Scenario: int and str column raises SchemaError

- **WHEN** a user creates `po.DataFrame({"value": [1, "one"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating column `"value"`
  has incompatible types `int` and `str`

#### Scenario: all-bool column infers bool

- **WHEN** a user creates `po.DataFrame({"flag": [True, False, True]})`
- **THEN** the inferred type for column `"flag"` SHALL be `bool` (not promoted
  to `int`)

#### Scenario: bool and None infers Optional[bool]

- **WHEN** a user creates `po.DataFrame({"flag": [True, None, False]})`
- **THEN** the inferred type for column `"flag"` SHALL be `bool | None`

## Requirements

### Requirement: Schema declaration via `@po.schema` decorator

`@po.schema` SHALL imply `@dataclass` and produce a class where accessing a
field on the class (not an instance) returns an `Expr` node representing that
column. Accessing a field on an instance returns the actual value.

#### Scenario: Class access returns Expr

- **WHEN** a user accesses `Person.age` on a `@po.schema`-decorated class
- **THEN** the result SHALL be a `ColumnRef("age", dtype=int)` expression

#### Scenario: Instance access returns value

- **WHEN** a user creates `p = Person("Ana", 30)` and accesses `p.age`
- **THEN** the result SHALL be `30`

#### Scenario: Dataclass behavior preserved

- **WHEN** a user applies `@po.schema` to a class with typed fields
- **THEN** the class SHALL behave as a `@dataclass` (init, repr, eq)

#### Scenario: Instance equality uses dataclass __eq__, not Expr

- **WHEN** a user compares `Person("Ana", 30) == Person("Ana", 30)`
- **THEN** the result SHALL be `True` (Python `bool`), using the
  `@dataclass`-generated `__eq__`, not `Expr.__eq__`

#### Scenario: dataclasses.fields() introspection preserved

- **WHEN** a user calls `dataclasses.fields(Person)` on a `@po.schema` class
- **THEN** it SHALL return correct field metadata (name, type, default)
  matching the original class definition

### Requirement: Runtime schema object

A runtime schema object SHALL be either a `@po.schema`-decorated class (for
declared schemas) or a dynamically created `@po.schema` class (for inferred
schemas). In both cases, class-level field access SHALL return `Expr` nodes.
The `DataFrame.schema` property that exposes this object is defined in
`dataframe/spec.md`.

#### Scenario: Declared schema returns Expr on class access

- **WHEN** a `@po.schema` class `Person` is used as a runtime schema
- **THEN** `Person.age` SHALL return a `ColumnRef("age", dtype=int)` expression

#### Scenario: Dynamically created schema returns Expr on class access

- **WHEN** a schema is dynamically created with fields `name: str` and `age: int`
- **THEN** class-level access on the schema SHALL return `Expr` nodes
- **AND** `DynSchema.age` SHALL return a `ColumnRef("age", dtype=int)` expression

### Requirement: Schema inference from data

The system SHALL infer a schema from dict or row-based data when no explicit
schema is provided. The inferred schema SHALL be a dynamically created
`@po.schema` class.

#### Scenario: Infer from dict

- **WHEN** a user creates `po.DataFrame({"name": ["Ana"], "age": [30]})`
- **THEN** `df.schema` SHALL have fields `name: str` and `age: int`

#### Scenario: Infer from rows

- **WHEN** a user creates `po.DataFrame([{"name": "Ana", "age": 30}])`
- **THEN** `df.schema` SHALL have fields `name: str` and `age: int`

#### Scenario: Incompatible types raise SchemaError on inference

- **WHEN** a user creates `po.DataFrame({"val": [1, "two", 3.0]})`
- **THEN** the system SHALL raise a `SchemaError` with a message identifying
  the column `"val"` and the incompatible types found (`int`, `str`, `float`)
- **AND** the error message SHALL suggest declaring an explicit schema

#### Scenario: Unsupported homogeneous type raises SchemaError on inference

- **WHEN** a user creates `po.DataFrame({"data": [{"a": 1}, {"b": 2}]})`
- **THEN** the system SHALL raise a `SchemaError` indicating that `dict` is
  not a supported column type and listing the supported types

#### Scenario: None values infer type from non-None values

- **WHEN** a user creates `po.DataFrame({"age": [30, None, 25]})`
- **THEN** the inferred type SHALL be `Optional[int]` (i.e., `int | None`)

#### Scenario: All-None column raises SchemaError

- **WHEN** a user creates `po.DataFrame({"age": [None, None, None]})`
- **THEN** the system SHALL raise a `SchemaError` because the column type
  cannot be inferred from all-None values
- **AND** the error message SHALL suggest providing an explicit schema

### Requirement: Numeric type promotion in inference

When a column contains compatible numeric types, the system SHALL promote to
the widest type in the hierarchy `bool < int < float`. This promotion SHALL be
orthogonal to nullability inference. If a numeric column also contains `None`,
the final type SHALL be the `Optional` variant of the promoted numeric type.

#### Scenario: int and float promote to float

- **WHEN** a user creates `po.DataFrame({"val": [1, 2.0, 3]})`
- **THEN** the inferred type SHALL be `float`

#### Scenario: Promotion interacts with nullability

- **WHEN** a user creates `po.DataFrame({"val": [1, 2.0, None]})`
- **THEN** types SHALL promote to `float` first, then nullability SHALL be
  applied, resulting in `Optional[float]` (i.e., `float | None`)

#### Scenario: bool and int promote to int

- **WHEN** a user creates `po.DataFrame({"val": [True, 1, 2]})`
- **THEN** the inferred type SHALL be `int`

#### Scenario: All-bool infers bool

- **WHEN** a user creates `po.DataFrame({"flag": [True, False, True]})`
- **THEN** the inferred type SHALL be `bool`

#### Scenario: NaN is a valid float, not None

- **WHEN** a user creates `po.DataFrame({"x": [1.0, float('nan'), 3.0]})`
- **THEN** the inferred type SHALL be `float` (not `Optional[float]`)
- **AND** `float('nan')` SHALL be treated as a valid `float` value

### Requirement: Supported column types

The system SHALL support the following Python types as column dtypes:
`int`, `float`, `str`, `bool`, and their `Optional` variants (`int | None`,
`float | None`, `str | None`, `bool | None`). Schema declaration with
unsupported types SHALL raise a `SchemaError` at decoration time naming
the unsupported type and listing supported types.

#### Scenario: Unsupported type in schema raises error

- **WHEN** a user declares `@po.schema class Bad: data: dict`
- **THEN** the system SHALL raise a `SchemaError` indicating `dict` is not
  a supported column type and listing the supported types

#### Scenario: Optional variant is supported

- **WHEN** a user declares `@po.schema class Row: age: int | None`
- **THEN** the schema SHALL accept `age` as `Optional[int]`

### Requirement: Column name constraints

The system SHALL require that column names are valid Python identifiers and
SHALL reject Python keywords as column names. Column names that are not valid
identifiers SHALL cause a SchemaError to be raised.

#### Scenario: Space in column name raises error

- **WHEN** `po.DataFrame({"first name": ["Ana"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating `"first name"`
  is not a valid Python identifier

#### Scenario: Python keyword as column name raises error

- **WHEN** `po.DataFrame({"class": ["A"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating `"class"` is a
  reserved Python keyword and cannot be used as a column name

#### Scenario: Column name starting with digit raises error

- **WHEN** `@po.schema class Bad: pass` with a field named `1age`
- **THEN** the system SHALL raise a `SchemaError` (Python rejects this
  at class definition time; the schema decorator need not handle it separately)

### Requirement: Schema to code bridge

`schema.to_code()` SHALL return a string containing a valid `@po.schema` class
definition that, when executed, produces an equivalent schema.

#### Scenario: Generate code from inferred schema

- **WHEN** a user calls `df.schema.to_code()` on a DataFrame with inferred schema
- **THEN** the output SHALL be a valid Python `@po.schema` class definition with correct field names and types

#### Scenario: Generated code includes import

- **WHEN** `to_code()` is called
- **THEN** the output SHALL include `from poco import po` and the `@po.schema` decorator

### Requirement: Schema subclassing

The system SHALL support single inheritance for `@po.schema`-decorated
classes. A `@po.schema`-decorated class MAY inherit from another
`@po.schema` class, and the subclass SHALL include all fields from the parent
plus its own fields.

Field overrides in a subclass SHALL be permitted only if the new type is
exactly equivalent to the parent's field type. Overrides that attempt to
change the type SHALL be rejected.

#### Scenario: Subclass inherits parent fields

- **WHEN** a user defines `@po.schema class Employee(Person): salary: float`
- **THEN** `Employee` SHALL have all fields from `Person` plus `salary`
- **AND** `Employee.salary` SHALL return a `ColumnRef("salary", dtype=float)` expression

#### Scenario: Identical field override is permitted

- **WHEN** a user defines `@po.schema class Worker(Person): age: int`
- **THEN** the schema SHALL be valid since `Worker` merely restates the `int` type

#### Scenario: Subclass field type override raises error

- **WHEN** a user defines `@po.schema class Bad(Person): age: str`
- **THEN** the system SHALL raise a `SchemaError` indicating that field `age`
  cannot change type from `int` to `str` in a subclass

#### Scenario: Diamond inheritance raises error

- **WHEN** a user defines `@po.schema class Bad(SchemaA, SchemaB): pass`
  where `SchemaA` and `SchemaB` are `@po.schema` classes with overlapping fields
- **THEN** the system SHALL raise a `SchemaError` indicating that multiple
  schema inheritance with overlapping fields is not supported

### Requirement: Zero-field schema is valid

A `@po.schema`-decorated class with no fields SHALL be valid and SHALL produce a schema
with zero columns. This SHALL be consistent with empty DataFrame construction from
`{}` and `[]`.

#### Scenario: Zero-field schema declaration

- **WHEN** a user defines `@po.schema class Empty: pass`
- **THEN** it SHALL produce a valid schema with 0 columns
- **AND** `dataclasses.fields(Empty)` SHALL return an empty tuple

#### Scenario: Zero-field schema with DataFrame

- **WHEN** a user constructs `po.DataFrame([], schema=Empty)`
- **THEN** a valid DataFrame with 0 columns and 0 rows SHALL be created

### Requirement: Schema field ordering is deterministic

Schema field order SHALL follow these rules:

- **Declared schema** (`@po.schema`): fields are ordered by declaration order
  in the class body
- **Inherited schema**: parent fields first (in parent declaration order),
  then child fields (in child declaration order)
- **Inferred schema from dict**: fields ordered by key insertion order of the
  first dict (for dict-of-lists, the dict's key order; for list-of-dicts, the
  first row's key order)
- **Auto-generated schema** (from `select`, `derive`, `groupby`, `join`):
  fields ordered as defined by the operation (`select`: argument order;
  `derive`: original columns then new columns in keyword order; `groupby`: key
  columns then aggregation columns in keyword order; `join`: see relational
  spec)

Row keys (`dict[str, object]`) always correspond to the schema field order.

#### Scenario: Inherited field ordering

- **WHEN** a user defines `@po.schema class Base: a: int; b: str` and
  `@po.schema class Child(Base): c: float`
- **THEN** `dataclasses.fields(Child)` SHALL return fields ordered `[a, b, c]`
  (parent first, then child)

#### Scenario: Inferred schema from dict

- **WHEN** a user creates `po.DataFrame({"z": [1], "a": [2], "m": [3]})`
- **THEN** the inferred schema field order SHALL be `[z, a, m]` (dict key
  insertion order)

### Requirement: Schema inference rejects incompatible type families

Type promotion SHALL apply only within the numeric family (`bool < int < float`).
Cross-family combinations (numeric + `str`) SHALL raise `SchemaError`.

#### Scenario: bool and str column raises SchemaError

- **WHEN** a user creates `po.DataFrame({"flag": [True, "yes"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating column `"flag"`
  has incompatible types `bool` and `str`

#### Scenario: int and str column raises SchemaError

- **WHEN** a user creates `po.DataFrame({"value": [1, "one"]})`
- **THEN** the system SHALL raise a `SchemaError` indicating column `"value"`
  has incompatible types `int` and `str`

#### Scenario: all-bool column infers bool

- **WHEN** a user creates `po.DataFrame({"flag": [True, False, True]})`
- **THEN** the inferred type for column `"flag"` SHALL be `bool` (not promoted
  to `int`)

#### Scenario: bool and None infers Optional[bool]

- **WHEN** a user creates `po.DataFrame({"flag": [True, None, False]})`
- **THEN** the inferred type for column `"flag"` SHALL be `bool | None`

## Requirements
