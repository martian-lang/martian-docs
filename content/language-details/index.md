---
date: 2016-06-01T17:53:15-07:00
title: Language Details
type: post
---

## Tokens and Grammar

The Martian language's tokens are defined by regular expressions in its [lexical scanner](https://github.com/martian-lang/martian/blob/master/martian/syntax/lexer.go).

The Martian syntax is specified as a [YACC grammar](https://github.com/martian-lang/martian/blob/master/martian/syntax/grammar.y).

## Symbols and Scope

Symbols in Martian are identifiers for stages, pipelines, and parameters. They may comprise uppercase and lowercase letters, numeric digits, and underscores. A symbol may not begin with a numeric digit, which is reserved for number literals. The Martian lexer's regular expression for symbols is ```[a-zA-Z_][a-zA-Z0-9_]*\\b```.

Martian defines two scopes within which symbol names must be unique:

1. Within the scope of one pipeline invocation, which encompasses all recursively included MRO files, no two stages or pipelines may share the same name. This is considered the global scope of a pipestance.
2. Within the scope of a stage declaration, no two input parameters of a given stage can have the same name, and same for output parameters.

## Naming Conventions

The following naming conventions are strongly recommended for consistency and readability, but are not currently enforced by the compiler.

Stage and pipeline names should written in `ALL CAPS SNAKE_CASE`.

- Stage names should be a subject and verb: `FIND_DIPS`, `CALL_VARIANTS`
- Pipelines names should be "actor nouns": `COIN_SORTER`, `DYSON_SPHERE_DETECTOR`, `SV_CALLER`
- Names of pipelines intended to serve as subpipelines should be prefixed with an underscore: `_METRICS_REPORTER`

Parameter names should be written in `all lowercase snake_case`.

## Parameter Binding

This section describes the rules associated with parameter binding, the mechanism by which inputs and outputs of stages and pipelines are connected together.

Whenever a stage is called, each of its input parameters must be bound to either an output parameter of another stage, or an input parameter of the enclosing pipeline. Parameter bindings use a dotted notation where the left-hand term is either the name of a stage, or `self` when binding to an input of the pipeline itself.

Each output parameter of the pipeline must also be bound to an output of one of its called stages. This is done using a `return` statement, as shown above.

Martian enforces type matching on parameter bindings, statically verifying that two parameters bound together have the same type.

## Types

Martian supports the following built-in types:

|Type|Description|
|----|-----------|
|string|A string.|
|int|An integer number.|
|float|A floating point number with support for exponential notation.  |
|bool|A boolean flag whose valid values are ```true``` and ```false```.|
|path|A string meant to be interpreted as a filesystem path.|
|map|A JSON-compatible data structure whose top-level type is an object.|

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
