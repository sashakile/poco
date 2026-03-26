## ADDED Requirements

### Requirement: Schema declaration via `@po.schema` decorator

The `@po.schema` decorator SHALL imply `@dataclass` and replace each field
with a `ColumnDescriptor`. When a field is accessed on the class (not an
instance), it SHALL return an `Expr` node representing that column. When
accessed on an instance, it SHALL return the actual value.

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

### Requirement: Schema inference from data

The system SHALL infer a schema from dict or row-based data when no explicit
schema is provided. The inferred schema SHALL be a dynamically created
`@po.schema` class with `ColumnDescriptor`s.

#### Scenario: Infer from dict

- **WHEN** a user creates `po.DataFrame({"name": ["Ana"], "age": [30]})`
- **THEN** `df.schema` SHALL have fields `name: str` and `age: int` with working descriptors

#### Scenario: Infer from rows

- **WHEN** a user creates `po.DataFrame([{"name": "Ana", "age": 30}])`
- **THEN** `df.schema` SHALL have fields `name: str` and `age: int` with working descriptors

#### Scenario: Mixed-type column raises SchemaError on inference

- **WHEN** a user creates `po.DataFrame({"val": [1, "two", 3.0]})`
- **THEN** the system SHALL raise a `SchemaError` with a message identifying
  the column `"val"` and the conflicting types found
- **AND** the error message SHALL suggest declaring an explicit schema

#### Scenario: None values infer type from non-None values

- **WHEN** a user creates `po.DataFrame({"age": [30, None, 25]})`
- **THEN** the inferred type SHALL be `Optional[int]` (i.e., `int | None`)

### Requirement: Empty DataFrame construction

The system SHALL support constructing DataFrames with zero rows. A DataFrame
with columns but no rows preserves its schema. A DataFrame with no columns
and no rows is valid but has an empty schema.

#### Scenario: Empty columns with explicit schema

- **WHEN** `po.DataFrame({"name": [], "age": []}, schema=Person)`
- **THEN** a DataFrame with 0 rows SHALL be created
- **AND** `df.schema` SHALL match the `Person` schema

#### Scenario: Empty columns without schema raises error

- **WHEN** `po.DataFrame({"name": [], "age": []})` is called without a schema
- **THEN** the system SHALL raise a `SchemaError` because types cannot be
  inferred from empty columns
- **AND** the error message SHALL suggest providing an explicit schema

#### Scenario: Empty dict, zero columns

- **WHEN** `po.DataFrame({})`
- **THEN** a DataFrame with 0 columns and 0 rows SHALL be created

#### Scenario: Filter removes all rows

- **WHEN** all rows are filtered out by a `where` operation
- **THEN** the result SHALL be a valid DataFrame with 0 rows and the original schema

### Requirement: Schema to code bridge

`schema.to_code()` SHALL return a string containing a valid `@po.schema` class
definition that, when executed, produces an equivalent schema.

#### Scenario: Generate code from inferred schema

- **WHEN** a user calls `df.schema.to_code()` on a DataFrame with inferred schema
- **THEN** the output SHALL be a valid Python `@po.schema` class definition with correct field names and types

#### Scenario: Generated code includes import

- **WHEN** `to_code()` is called
- **THEN** the output SHALL include `import poxo as po` and the `@po.schema` decorator

#### Scenario: Schema subclassing

- **WHEN** a user defines `@po.schema class Employee(Person): salary: float`
- **THEN** `Employee` SHALL have all fields from `Person` plus `salary`
- **AND** `Employee.salary` SHALL return a `ColumnRef("salary", dtype=float)` expression
