---
date: 2017-05-21T17:53:15-07:00
title: Writing Pipelines
type: post
---

## Stages

A stage is the fundamental unit of computation in Martian, and is composed with other stages into Martian pipelines, which are directed, acyclic graphs of stages.

Martian stages can be implemented in any language, and each stage can even be implemented in a different language, if desired. Martian manages the flow of data from the outputs of one stage to the inputs of one or more downstream stages in the graph. Martian provides a well-structured, typed, validated, JSON-based mechanism for exchanging data between stages in a language-independent manner.

Here is a basic stage definition example:

~~~~
filetype txt;

stage SORT(
    in  txt  unsorted,
    in  bool case_sensitive,
    out txt  sorted,
    src py   "stages/sort",
)
~~~~

A stage is minimally defined by three things:

1. **Input Parameters -** A stage can declare one or more typed ```in``` parameters, to which upstream stages' outputs are bound. At runtime, Martian passes type-checked arguments into the stage code.
2. **Output Parameters -** Martian also provides a structured way for stage code to return typed ```out``` values, which are validated and passed by Martian to downstream stages.
3. **Stage Code -** The ```src``` parameter specifies the executable code that implements the functionality of the stage. The type of this parameter indicates the language of that code. For example, a stage could refer to a Python module, a C, C++, Go, or Rust binary, or a shell script, just to name a few possibilities. There is no required or preferred implementation language in Martian. The third element of this parameter is a language-dependent string that Martian uses to locate the code. In this example, ```stages/sort``` is a folder that exists relative to the ```MROPATH``` environment variable, and contains a valid Python module with a ```__init__.py```.

## Pipelines

A pipeline definition comprises calls to defined stages. Each stage call must bind its inputs to either the outputs of another upstream stage, or to the input parameters of the pipeline itself. Here is a simple example:

~~~~
filetype txt;

stage SORT_ITEMS(
    in  txt  unsorted,
    in  bool case_sensitive,
    out txt  sorted,
    src py   "stages/sort",
)

stage FIND_DUPLICATES(
    in  txt  sorted,
    out txt  duplicates,
    src py   "stages/find_duplicates",
)

pipeline DUPLICATE_FINDER(
    in  txt  unsorted,
    out txt  duplicates,
)
{
    call SORT_ITEMS(
        unsorted = self.unsorted,
    )
    call FIND_DUPLICATES(
        sorted = SORT.sorted,
    )
    return (
        duplicates = FIND_DUPLICATES.duplicates,
    )
}
~~~~

The example above does the following:

- Declares a user-defined filetype `txt`
- Declares two stages `SORT` and `FIND_DUPLICATES`
- Declares a pipeline `DUPLICATE_FINDER` that calls both stages. It accepts one input `unsorted` which must be a filename ending in `.txt`. The `unsorted` parameter is then passed to the input of `SORT`, whose output is then passed to `FIND_DUPLICATES`. The output `duplicates` of `FIND_DUPLICATES` is then returned as the output of the whole pipeline.

### Composability

Pipelines specify input and output parameter the same way stages do, so they may also themselves act as stages. This allows for the composition of an arbitrary mix of individual stages and pipelines into still larger pipelines. We refer to pipelines as "subpipelines" when they are composed into other pipelines.

When a pipeline is run, the instantiation of it is called a "pipestance", which is a portmanteau of "pipeline" and "instance".

## Organizing Code

### MRO Files

Stage and pipeline code are referred to as **MRO code**, because they are written in files that have an ```.mro``` extension.

### Preprocessing with @include

Martian supports lexical preprocessing with an ```@include``` directive, which takes the path to another MRO file as an argument. This directive is evaluated by splicing the contents of the included file into the file where the directive is given, replacing the directive itself. This evaluation is recursive, and Martian keeps track of the inclusion tree in order to be able to report errors using per-source file line numbers.

```_my_stages.mro```
~~~~
filetype txt;

stage SORT_ITEMS(
    in  txt  unsorted,
    in  bool case_sensitive,
    out txt  sorted,
    src py   "stages/sort",
)
~~~~
```pipeline.mro```
~~~~
@include "_my_stages.mro"

pipeline DUPLICATE_FINDER(
    in  txt  unsorted,
    out txt  sorted,
)
{
    call SORT_ITEMS(
        unsorted = self.unsorted,
    )
    return (
        sorted = SORT_ITEMS.sorted,
    )
}
~~~~

### Stage Code vs Pipeline Code

By convention, the ```@include``` directive allows the developer to organize code into header files, although there is no formal distinction between header and non-header MRO files in Martian. Typically, stages that are logically grouped together are declared in one file, for example ```_sorting_stages.mro```, and that file would be included into another MRO file that declares a pipeline that calls these included stages. By convention, MRO files containing stage declarations should be named with the suffix ```_stages```.

## Pipeline Invocation

Thus far we have shown how to define stages and pipelines in MRO files. To run a pipeline, one writes a single pipeline `call` statement with a particular set of input arguments, into an MRO file. This is called an invocation. To invoke the example pipeline from above:

```invoke.mro```
~~~~
@include "pipeline.mro"

call DUPLICATE_FINDER(
    unsorted = "/home/duplicator_dave/unsorted.txt",
)
~~~~

Typically, an invocation MRO file contains a single `@include` statement that includes the pipeline definition, and a single `call` statement. It is generally discouraged to `call` a pipeline in the same file in which it is defined, because then the pipeline definition cannot be easily reused for other invocations with different input arguments.

For more details on how to run an invocation MRO with the Martian runtime, see [Running Pipelines](../running-pipelines).

## Symbols and Scope

Symbols in Martian may comprise uppercase and lowercase letters, numeric digits, and underscores. A symbol may not, however, begin with a numeric digit, which is reserved for number literals. The Martian lexer's regular expression for symbols is ```[a-zA-Z_][a-zA-Z0-9_]*\\b```.

Martian defines two scopes within which symbol names must be unique:

1. Within the scope of one pipeline invocation, which encompasses all recursively included MRO files, no two stages or pipelines may share the same name. This is considered the global scope of a pipestance.
2. Within the scope of a stage declaration, no two input parameters of a given stage can have the same name, and same for output parameters.

### Naming Conventions

The following naming conventions are strongly recommended for consistency and readability, but are not currently enforced by the compiler.

Stage and pipeline names should written in `ALL CAPS SNAKE_CASE`.

- Stage names should be a subject and verb: `FIND_DIPS`, `CALL_VARIANTS`
- Pipelines names should be actor verbs: `COIN_SORTER`, `DYSON_SPHERE_DETECTOR`
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

Martian also supports user-defined filetypes for which file extensions are enforced. A filetype is defined and referenced like this:

~~~~
filetype txt;

stage SORT(
    in  txt  unsorted_txt,
    in  bool case_sensitive,
    out txt  sorted_txt,
    src py   "stages/sort",
)
~~~~

## Compiling with mrc

## Formatting with mrf


## Volatile Data Removal

`volatile` keyword.

## Chunks
## Forks
## Preflights
