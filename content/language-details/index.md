---
date: 2016-06-01T17:53:15-07:00
title: Language Details
type: post
---

## Tokens and Grammar

The Martian language's tokens are defined by regular expressions in its [lexical scanner](https://github.com/martian-lang/martian/blob/master/martian/syntax/lexer.go).

The Martian syntax is specified as a [YACC grammar](https://github.com/martian-lang/martian/blob/master/martian/syntax/grammar.y).

UTF-8 is the assumed encoding for all source files, as well as for the json
parameter files passed between `mrp` and stage processes.

## Symbols and Scope

Symbols in Martian are identifiers for stages, pipelines, and parameters. They may comprise uppercase and lowercase letters, numeric digits, and underscores. A symbol may not begin with a numeric digit, which is reserved for number literals. Identifiers beginning with two underscores are reserved as well. The Martian lexer's regular expression for symbols is ```^_?[a-zA-Z][a-zA-z0-9_]*\\b```.

Martian defines three scopes within which symbol names must be unique:

1. Within the scope of one pipeline invocation, which encompasses all recursively included MRO files, no two stages or pipelines may share the same name. This is considered the global scope of a pipestance.
2. Within the scope fo one pipeline definition, not including parent or child pipelines, the names assigned to calls must be unique.
3. Within the scope of a stage declaration, no two input parameters of a given stage can have the same name, and same for output parameters.

## Naming Conventions

The following naming conventions are strongly recommended for consistency and readability, but are not currently enforced by the compiler.

Stage and pipeline names should written in `ALL CAPS SNAKE_CASE`.

- Stage names should be a subject and verb: `FIND_DIPS`, `CALL_VARIANTS`
- Pipelines names should be "actor nouns": `COIN_SORTER`, `DYSON_SPHERE_DETECTOR`, `SV_CALLER`
- Names of pipelines intended to serve as subpipelines should be prefixed with an underscore: `_METRICS_REPORTER`
- Names of `struct` data types should use `PascalCase`.

Parameter names should be written in `all lowercase snake_case`.

## Parameter Binding

This section describes the rules associated with parameter binding, the mechanism by which inputs and outputs of stages and pipelines are connected together.

Whenever a stage is called, each of its input parameters must be bound to either an output parameter of another stage, or an input parameter of the enclosing pipeline. Parameter bindings use a dotted notation where the left-hand term is either the name of a stage, or `self` when binding to an input of the pipeline itself.

Each output parameter of the pipeline must also be bound to an output of one of its called stages. This is done using a `return` statement, as shown above.

Martian enforces type matching on parameter bindings, statically verifying that two parameters bound together have the same type.

## Types

### Built-in types
Martian supports the following built-in types:

|Type|Description|
|----|-----------|
|string|A string. String literals support escaping using json syntax: `\"`, `\\`, `\b`, `\n`, `\r`, `\t`, and `\uxxxx` (unicode U+xxxx).  Other escape sequences are undefined behavior - the parser _may_ accept them but the formatter will convert them to standard notation.|
|int|A signed 64-bit integer.|
|float|A double-precision floating point number.  Literal values may use exponential notation.|
|bool|A boolean flag whose valid values are `true` and `false`.|
|path|A string meant to be interpreted as a filesystem path to a directory.  All paths should be absolute, as each stage runs in its own working directory.|
|file|A string meant to be interpreted as a filesystem path to a regular file.  In most cases, a user-defined file type should be preferred.|
|map|A JSON-compatible data structure whose top-level type is an object (dictionary) with string keys.  In most cases, a typed container should be preferred.|

Implicit conversion from `string` to `file` or `path` is permitted, as well as
from `int` to `float` (though not the reverse).

### User-defined file types

Martian also supports user-defined filetypes.  The name of the file types
controls the file extension for the default filename pre-populated in the outs.
Martian enforces compile-time binding type matching between user-defined file
types, but allows implicit casting between user-defined file types and generic
"string" or "file" types.  A filetype is defined and referenced like this:

~~~~
filetype txt;

stage SORT(
    in  txt  unsorted_txt,
    in  bool case_sensitive,
    out txt  sorted_txt,
    src py   "stages/sort",
)
~~~~


This allows pipelines to be more clear about the format of files being passed
around, and to exploit the type checking to ensure that files are being used
conistently as they are passed around.  Note however that martian does not
attempt to validate that a file's content matches the declared type.

### Structured data types (Martian 4.0 preview)

A `struct` is related to the same concepts in other languages like C, a named
tuple in Python, or an object in javascript.  They can be declared,
```
struct MyType(
    int   foo,
    float bar,
)
```
Members of a struct can be extracted using the familiar `.` syntax, e.g.
```
call FOO(
    foo = STRUCT_OUTPUT.struct.foo,
)
```
The output of a stage or pipeline is always a `struct`.  Because of this, the
name of a stage or pipeline can be used as a type, to indicate a structure with
the same members and types as the outputs of the stage or pipeline, e.g.
```
stage STAGE1(
    in  int    in1,
    out file   out1,
    out string out2,
    out float  out3,
)

stage STAGE2(
    in  STAGE1 in1,
    out string out1,
)
```
This is convenient particularly for strictly sequential parts of pipelines where
all of the outputs of one stage become inputs to the next stage, but care
should be taken to limit the use of this type of typing to stages whose
development is tightly coupled.  In particular, stages which are not called
from within the same pipeline should probably not use each other's names as
types.

Martian structures support a form of "[duck typing](https://en.wikipedia.org/wiki/Duck_typing)".
If one has a struct `MyType` as declared above, and another type
```
struct MyBiggerType(
    int    foo,
    int    bar,
    string baz,
)
```
then a value of type `MyBiggerType` may be used for the input to a stage or
pipeline which asks for a `MyType`.  This is because for every field in `MyType`
there is a field with the same name in `MyBiggerType`, and that field in
`MyBiggerType` has a type that is assignable to the type for that field in
`MyType`.  Because of this, one can easily take a subset of the data from a
`struct` with only the values one actually needs.  Values with struct types may
also always be used for untyped map values.

As an additional convenience, martian supports a "wildcard expansion" of a
struct value when calling a stage, e.g.
```
call STAGE2(
    foo = self.foo,
    *   = STAGE1,
)
```
This is equivalent to `input = STAGE1.output` for every output of `STAGE1` that
is an input to `STAGE2`.  To prevent ambiguity, only one wildcard expansion is
allowed for each call, and it is an error if one of the outputs of `STAGE1` was
already assigned in the input call explicitly (e.g. `foo` in the example).

### Collection types

Martian also supports collections of values as arrays or typed maps.  These are
declared using a syntax that is familiar to users of C-style languages.  Arrays
are declared as for example `int[]`.  Typed maps (available in the martian 4.0
preview) always have string keys, and
are declared as for example `map<int>`.  These can be combined as for example
`map<int[][]>[]`.

In order to prevent confusing data flows, maps cannot be directly nested.  That
is, `map<map<int>>` is not permitted, nor is it permitted to nest untyped maps,
e.g. `map<map>`.  It _is_ permitted to have a map of structs, and those structs
may contain further maps.

A struct can be assigned to a typed map value if every field in the struct has a
type that can be assigned to the type of the map.  For example a struct with
only `int` and `float` fields may be assigned to a value of type `map<float>`.

Typed maps may be converted to untyped maps, and `map<T>` may be converted to
`map<U>` if type `T` is convertible to type `U`.  The same applies for arrays,
e.g. converting `T[]` to `U[]`.

Because the type system has no way to enforce the length of an array or the keys
of a map, there is no support for indexing into one.  If one knows the keys
ahead of time, use a struct.

A very important convenience is "projection" through structs.  Using the
`MyType` example struct from the previous section, if we have a value `FOO` of
type `map<MyType[]>` then `FOO.bar` has type `map<float[]>`.  To put it
another way, using the syntax of a Python list comprehension, if `A` is an
array of `struct` values then `A.b == [a.b for a in A]`


