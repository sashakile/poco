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

`df.schema` SHALL return the `@po.schema` class itself (for declared schemas)
or a dynamically created `@po.schema` class (for inferred schemas). In both
cases, class-level field access SHALL return `Expr` nodes.

#### Scenario: Declared schema accessible

- **WHEN** `df = po.DataFrame({"name": ["Ana"], "age": [30]}, schema=Person)`
- **THEN** `df.schema` SHALL be the `Person` class
- **AND** `df.schema.age` SHALL return a `ColumnRef("age", dtype=int)` expression

#### Scenario: Inferred schema accessible

- **WHEN** `df = po.DataFrame({"name": ["Ana"], "age": [30]})`
- **THEN** `df.schema` SHALL be a dynamically created `@po.schema` class
- **AND** `df.schema.age` SHALL return a `ColumnRef("age", dtype=int)` expression

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
