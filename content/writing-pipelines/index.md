---
date: 2016-11-01T17:53:15-07:00
title: Writing Pipelines
type: post
---

## Stages

A **stage** is the fundamental unit of computation in Martian, and is composed
with other stages into Martian **pipelines**, which are directed, acyclic
graphs of stages.

In order to ensure pipelines can be restarted and parallelized safely, stage
inputs are intended to be considered immutable, as are the outputs once the
stage completes.

Martian stages can be [implemented in any language](../writing-stages/), and
each stage can even be implemented in a different language, if desired. Martian
manages the flow of data from the outputs of one stage to the inputs of one or
more downstream stages in the graph. Martian provides a well-structured, typed,
validated, JSON-based mechanism for exchanging data between stages in a
language-independent manner.

Here is a basic stage definition example:

```coffee
filetype txt;

stage SORT_ITEMS(
    in  txt  unsorted,
    in  bool case_sensitive,
    out txt  sorted,
    src py   "stages/sort",
)
```

A stage is minimally defined by three things:

1. **Input Parameters -** A stage can declare one or more typed ```in```
parameters, to which pipeline input arguments or upstream stages' outputs
are bound. At runtime, Martian passes arguments into the stage code.
2. **Output Parameters -** Martian also provides a structured way for stage
code to return typed ```out``` values, which are passed by Martian to
downstream stages or the final pipeline outputs.
3. **Stage Code -** The ```src``` parameter specifies the executable code
that implements the logic of the stage. The type of this parameter indicates
the language of that code. For example, a stage could refer to a Python module,
or a C, C++, Go, or Rust binary, just to name a few possibilities.

Currently there are 2 values supported for the type parameter:

|`src` type|Stage type|
|---|---|
|`py`|Python stage code.  This is launched through an adapter process which provides useful utility methods for interacting with the pipeline runner.|
|`comp`|Executable code intended to run as a child process for `mrjob`.  This is the preferred way to handle compiled code.|
|`exe`|(deprecated) Executable code intended to be run directly.  Such code must manage the interface with `mrp` itself.|

Adding support for additional languages is
[fairly straightforward](https://github.com/martian-lang/martian/blob/master/adapters/README.md)

- pull requests welcome!  There is no required or preferred implementation
language in Martian. The third element of this parameter is a
language-dependent string that Martian uses to locate the code. In this
example, ```stages/sort``` is a directory that exists relative to the
`PYTHONPATH` environment variable, and contains a valid Python module with
a `__init__.py`.

## Pipelines

A pipeline definition comprises calls to defined stages. Each stage call must
bind its inputs to either the outputs of another upstream stage, or to the
input parameters of the pipeline itself. Here is a simple example:

```coffee
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
        sorted = SORT_ITEMS.sorted,
    )
    return (
        duplicates = FIND_DUPLICATES.duplicates,
    )
}
```

The example above does the following:

- Declares a user-defined filetype `txt`
- Declares two stages `SORT_ITEMS` and `FIND_DUPLICATES`
- Declares a pipeline `DUPLICATE_FINDER` that calls both stages. It accepts one input `unsorted` which must be a filename ending in `.txt`. The `unsorted` parameter is then passed to the input of `SORT_ITEMS`, whose output is then passed to `FIND_DUPLICATES`. The output `duplicates` of `FIND_DUPLICATES` is then returned as the output of the whole pipeline.

The Martian GitHub repository includes
[syntax highlighting](https://github.com/martian-lang/martian/tree/master/tools/syntax)
files for [Vim](https://www.vim.org/), [vscode](https://code.visualstudio.com/),
[Atom](https://atom.io/), and [Sublime](https://www.sublimetext.com/) text editors.
If your favorite editor is missing from this list, pull requests are welcome.
Instructions for setting up the syntax highlighting are
[available in the repository](https://github.com/martian-lang/martian/tree/master/tools#editor-syntax-highlighting).
The vscode extension is not yet "officially" published but can be
[downloaded from GitHub releases](https://github.com/martian-lang/martian/releases/download/v4.0.2/martian-lang-0.0.1.vsix).

### Composability

Pipelines specify input and output parameters the same way stages do, so they
may themselves also act as stages. This allows for the composition of an
arbitrary mix of individual stages and pipelines into still larger pipelines.
We refer to pipelines as "subpipelines" when they are composed into other
pipelines.

Because parameter binding is done by stage name, pipelines cannot call the same
stage or sub-pipeline twice without aliasing it like so:

```coffee
pipeline ADD_KEYS(
    in  string key1,
    in  string key2,
    in  string value1,
    in  string value2,
    in  json input,
    out json result,
)
{
    call ADD_KEY as ADD_KEY1(
        key = self.key1,
        value = self.value1,
        start = self.input,
    )
    call ADD_KEY as ADD_KEY2(
        key = self.key2,
        value = self.value2,
        start = ADD_KEY1.result,
    )

    return (
        outfile = ADD_KEY2.result,
    )
}
```

## Top-level file outputs

When a top-level pipeline completes, any outputs with file type are moved into
the pipestance directory's `outs` subdirectory.  Symbolic links are added to
the original locations of those files in the stage output directories.

For an output with `file` or `path` type, the name of a file in the top-level
output directory will be the name of the output parameter of the pipeline.  If
it is a user-defined file type, e.g. json, then the type will be appended to
the name as an extension, e.g. `.json`.

If a pipeline is defined like for example
```coffee
pipeline PIPE(
    out json foo "help text" "special_file",
)
```
then the string "help text" will be displayed in the console as a label for
the output file, and the default filename (which would be `foo.json`) is
overridden to `special_file`.  These annotations apply when defining struct
types as well.

In martian 4.0, if an output is a struct type, then in the top-level `outs`
directory there will be a _directory_ for that value, containing files from
within that structure.  Nested structures are handled recursively as deeper
directories.

An array of files will become a directory, with files named for the array index,
e.g. for `json[] foo` there will be `foo/1.json` and so on.  For typed maps,
`map<json>`, the outputs would be `foo/<key>.json` for each key in the map.
Arrays or typed maps of structs containing files and up as nested directories
as one would expect.

## Organizing Code

### MRO Files

Stage and pipeline specifications are referred to as **MRO code**, because
by convention they are written in files that have an ```.mro``` extension.

### Preprocessing with @include

Martian supports organizing one's pipeline definitions into multiple files which
can use an `@include` directive to import the stages, pipelines, and types
defined in other files.

`_my_stages.mro`

```coffee
filetype txt;

stage SORT_ITEMS(
    in  txt  unsorted,
    in  bool case_sensitive,
    out txt  sorted,
    src py   "stages/sort",
)
```

`pipeline.mro`

```coffee
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
```

### Stage Code vs Pipeline Code

The `@include` directive allows the developer to organize code.  Typically,
stages that are logically grouped together are declared in one file, for example
`_sorting_stages.mro`, and that file would be included into another MRO
file that declares a pipeline that calls these included stages. By convention,
MRO files containing stage declarations should be named with the suffix
`_stages`.

### Martian Project Directory Structure

To give you an idea of how a Martian project looks in practice, here's an example:

```text
martian_project/
    bin/
        hello_go
        hello_rust
    lib/
        go/
            vendor/github.com/martian-lang/martian
                src/martian/adapter/adapter.go
            src/
                hello_go.go
        rust/
            Cargo.lock
            Cargo.toml
            src/
                hello_rust.rs
    mro/
        _hello_stages.mro
        hello.mro
        stages/
            hello/
                hello_py/
                    __init__.py
```

## Formatting Code

Martian includes a canonical code formatting utility called `mro format`. It parses
your MRO code into its abstract syntax tree and re-emits the code with
canonical whitespace. In particular, `mro format` performs intelligent column-wise
alignment of parameter fields so that this:

```coffee
    stage SORT_ITEMS  (in txt unsorted,
in bool case_sensitive,
out txt sorted,
    src py "stages/sort",
)
```

becomes this:

```coffee
stage SORT_ITEMS(
    in  txt  unsorted,
    in  bool case_sensitive,
    out txt  sorted,
    src py   "stages/sort",
)
```

`mro format` is an "opinionated" formatter, inspired by tools like `gofmt`, therefore
we will borrow [their explanation](https://blog.golang.org/go-fmt-your-code) of
the benefits of canonical code formatting:

- **Easier to write**: never worry about minor formatting concerns while hacking away.
- **Easier to read**: when all code looks the same you need not mentally convert others' formatting style into something you can understand.
- **Easier to maintain**: mechanical changes to the source don't cause unrelated changes to the file's formatting; diffs show only the real changes.
- **Uncontroversial**: never have a debate about spacing or brace position ever again!

`mro format` takes a list of MRO filenames as arguments. By default, it will output
the formatted code back to `stdout`. If given the `--rewrite` option, it will
write the formatted code back into the original files. If given the `--all`
option, it will rewrite all MRO files found in your `MROPATH`. For consistency
of your MRO codebase, consider configuring editor save-hooks or git
commit-hooks that run `mro format --rewrite` or `mro format --all`.

`mro format` does not support any arguments that affect the formatting, otherwise it
would not be canonical!

If you run `mro format` with the `--includes` flag, it will (attempt to) fix up
`@include` directives.  Specifically, if a pipeline in an `mro` source file
uses a stage, it will ensure that the file defining that stage is _directly_
included, and that files which are not directly depended on are not included.
It will only add `@include` statements referring to files in the root of your
`MROPATH` or in the transitive closure of the existing includes.  The reason
for the convention of direct inclusions is the same as the reasons explained
in the [clang include-what-you-use][] tool - briefly, if a file you depend
on stops depending on another file, and you only included it transitively,
then your pipeline will fail to compile if the intermediate pipeline removes
its `@include`.

[clang include-what-you-use]: https://github.com/include-what-you-use/include-what-you-use/blob/master/docs/WhyIWYU.md

## Compiling<sup>*</sup> Code

One of the core components and principal benefits of Martian is `mro check`, a tool
which statically verifies your MRO code before you commit to a potentially
resource-intensive run of your pipeline. `mro check` identifies and helps you fix
errors that you might otherwise encounter hours, days, or even weeks into your
pipeline run.  It can also output the pipeline in
[GraphViz](https://en.wikipedia.org/wiki/Graphviz) dot format for
visualization (see below).

While `mro check` is technically more like a linter, in that it does not actually
compile your code into an intermediate or binary format, it does perform
many of the same parsing and semantic checking steps that a compiler would,
helping you to write correct code, and making it easier to perform major
refactorings when necessary.

### Running `mro check`

`mro check` takes a list of MRO filenames as arguments and parses and verifies those
files, emitting line-numbered messages for any errors encountered. If given the
`--all` option, it will parse and verify all MRO files found in your `MROPATH`.
The following verification steps are performed:

- **Preprocessing**: All `@include` directives are recursively evaluated.  Any preprocessing errors, such as a file not found, will stop `mro check` and be reported.
- **Lexing and Parsing**: The MRO code produced by the preprocessor is then lexed and parsed according to the [Martian grammar](https://github.com/martian-lang/martian/blob/master/martian/syntax/grammar.y) to produce an in-memory representation of the pipeline called an [Abstract Syntax Tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree) (AST).  Any syntax errors will stop `mro check` and be reported.
- **Semantic Analysis**: The AST produced by the parser abstract syntax tree is then analyzed according a number of semantic rules. Any semantic errors will will be reported.
  - All referenced types are built-ins or user-defined with `filetype`.
  - All called stages and pipelines are defined.
  - All parameter names are unique within each stage or pipeline interface.
  - All stage and pipeline names are unique.
  - Structs may be re-defined in multiple files, but only if the definitions match.
  - All input parameters of stages and pipelines are bound.
  - Inputs and outputs that are bound together have matching types.
  - All pipeline output parameters are bound by a return statement.
  - The pipeline call graph is evaluated for cyclic dependencies or invalid control bindings.

If no errors are encountered, `mro check` returns 0, otherwise it returns a nonzero code and prints error messages to standard error.
It is recommended best practice to configure a pre-commit hook that runs `mro check --all`.

### Outputting the Abstract Syntax Tree as JSON

`mro check` also supports a `--json` option that outputs the abstract syntax tree and
associated data as a JSON object. This can be useful for further processing of
the AST in external tools.  Be warned, however, that the json representation is
not a stable interface and may change in arbitrary ways in the future.

### Visualizing a pipeline with [GraphViz](https://en.wikipedia.org/wiki/Graphviz)

The default output of `mro graph` is a json representation of the call graph.
By using `mro graph`'s `--dot` option, you can generate a visualization of the
pipeline structure.  For example,
```bash
$ mro graph --dot mro/sc_rna_aggregator.mro | dot -Tsvg -o sc_rna_aggregator.svg
```
to get a plot like this:
![sc_rna_aggregator visualization](/img/sc_rna_aggregator.svg)

This is a new feature, and the output could be prettier - pull requests welcome!
