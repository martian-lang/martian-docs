---
date: 2016-08-01T17:53:15-07:00
title: Writing Stages
type: post
---

## Overview

Martian supports writing pipeline stages in virtually any language. The only
requirement for pipeline executables is that they be able to write JSON to
files.

The martian runtime may need to restart stages for a variety of reasons,
including user input, hardware failures, or running out of memory.  Even if
stage code completes successfully, there are cases such as network partitions
in which the runtime may not be able to confirm successful completion.  Because
of this, stages should never alter their inputs, and must behave correctly if
re-run.  Formally, stages should ideally be
[pure functions](https://en.wikipedia.org/wiki/Pure_function).

A Martian stage is an executable, either interpreted or compiled, that takes
at least four command-line arguments as follows:

```sh
$ stage_executable [args] <type> <metadata_path> <files_path> <journal_prefix>
```

In most cases the interpretation of the arguments is handled by a
[language-specific adapter](#language-adapters).
The `type` argument is one of `split`, `join`, or `main` (`main` is run for
chunk phases, or for stages which do not
[split](../advanced-features/#parallelization) ). The stage executable should
switch on that type and provide implementations for each.

The details of the interface are generally handled by a language-specific
"adapter."  Currently, there are adapters for Python and Go in the main
repository, and an adapter for [Rust](https://github.com/martian-lang/martian-rust) in also available.  Adapters for
scripting languages are generally distributed with martian and should be
expected to be tied to a specific martian version, while adapters for
compiled languages obviously need to be compiled with the stage code.
For details on the interface between the job monitor process and the
adapter code, see the
[adapter documentation in the Martian repository](https://github.com/martian-lang/martian/blob/master/adapters/README.md).
When writing stage code, refer to the documentation for the
[language-specific adapter](#language-adapters) for additional details,
as they are intended to provide abstraction layers wrapping the interface
to the martian runtime, such as managing interaction with the journal
directory and accessing inputs and outputs.

### Split Interface
Input: The `args` file (containing the json dictionary of stage inputs)

Output: A `stage_defs` file, containing a json object containing two keys.

- `chunks`: a list of objects containing the input arguments to each stage,
and optional keys `__threads` and `__mem_gb` to override the default resource
reservation for each chunk.
- `join` (optional): an object containing `__threads` and `__mem_gb` overrides
to be used for the join phase.

More details in [Advanced Features: Parallelization](../advanced-features/#parallelization).

### Join Interface
Inputs:

- `args`: The stage input arguments
- `chunk_defs`: The chunk definitions produced by the split phase.
- `chunk_outs`: A json serialized list aggregating the outputs from each chunk.
- `outs`: The stage outputs.  This is written by the stage code, but for
outputs which are files, the paths to the recommended locations for those files
are populated by the runtime.

Output: The `outs` file is re-written with values populated for non-file
output types.

Because the runtime will attempt to reclaim disk space used by files which are
not required by any incomplete stages (see [Storage Management](../storage-management/)),
the final outputs of a stage should never contain references to files produced
by other stages.  This includes paths in the `outs` file as well as symbolic
links or other ways an output file might depend on an input file.  If the
outputs of a stage need to include a file produced by a previous stage, that
file should be copied or [hard-linked](https://en.wikipedia.org/wiki/Hard_link)
to the stage's outputs.

### Main/Chunk Interface
For stages which do not split, the `args` file contains the stage inputs.
For stages which do split, the `args` file contains the element of the
`chunks` key from the `stage_defs` file written by the split phase.

Outputs are written to the `outs` file, which is either the stage's `outs`
file (for stages which do not split) or will be aggregated into
`chunk_outs` to be passed to the `join` phase for stages which do split.

## Language Adapters

Martian provides support for writing stages in the form of adapters, whose
purpose is to provide to stages the following:

- A well-defined interface for stages to be invoked by `mrp`
- Input arguments from upstream stages to be passed into the stage
- A well-defined method for returning output values to be passed to downstream stages
- An API so the stage can provide logging, status updates, and error reporting.

The goal of Martian adapters is to minimize the amount of boilerplate code written for each stage implementation. Exactly how stage code is written and structured varies with the implementation language. Below are examples for some languages that currently have Martian adapters.

## Interpreted Languages

### [Python](https://github.com/martian-lang/martian/blob/master/adapters/python/martian.py)
A Martian stage written in Python is simply a Python module. That is, a
directory with an `__init__.py` containing the stage code.  The stage code
should not execute on import - the Martian Python adapter provides an
executable wrapper script that does an `import` of your Python module.

Python stages are run via an adapter which simplifies much of the high-level
tasks.  The stage `.py` file must contain a `main` method, expecting  and, if
the stage splits, a `split` and `join` method.

The `split` method is called with the contents of the `args` file as the
argument.  It must return a `stage_defs` object.

The `join` method is called with `args, outs, chunk_defs, chunk_outs`.
The `outs` are written back when the method returns.

The `main` method is called with the contents of the `args` and `outs` files
as input.  `outs` will be written back when the method returns.

The adapter wraps these json objects in a `Record` object, which
converts string keys into object attributes for convenience, and to prevent
accidentally setting invalid keys in `outs`.

Stage code may import the
[martian](https://github.com/martian-lang/martian/blob/master/adapters/python/martian.py)
module (the shell wrapper adds the version corresponding to the `mrp` process
to the `PYTHONPATH` - don't try to import it from elsewhere).  This provides
a number of convenience methods to the stage code:

|Method|Description|
|---|---|
|martian.make_path(filename)|Get the absolute path, in the stage's `files` directory, corresponding to given filename|
|martian.get_martian_version|Get the version of the parent `mrp` process|
|martian.get_pipelines_version|Get the pipeline version reported in the invocation mro|
|martian.update_progress(message)|Reports a progress update to bubble up to the parent `mrp` log.  There are no guarantees that the update will be reported before it is overwritten by a newer update.|
|martian.log_info(message)|Add a message to the chunk's log.|
|martian.log_warn(message)|Add a warning to the chunk's log.|
|martian.log_time(message)|Add a timestamped message to the chunk's log.|
|martian.log_json(label, obj)|Log an object as serialized json.|
|martian.throw(message)|Fail the stage with an error.|
|martian.exit(message)|Fail the stage with an assertion.|
|martian.alarm(message)|Log a message which will be reported by mrp at the end of the pipeline run.|

The Python module should be located in its own directory somewhere under the
`PYTHONPATH`.  The specific path is then specified in the MRO code to connect
the MRO stage definition with the location of the Python implementation, e.g.
`src py "path/to/my/python_module"`. Martian would then expect to be able to
Python `import` that path as a module.

## Compiled Languages

Stage executables that are compiled must implement the command-line interface described above.

### [Rust](https://github.com/martian-lang/martian-rust)
Refer to the [GitHub Pages for `martian-rust`](https://martian-lang.github.io/martian-rust).

### [Go](https://github.com/martian-lang/martian/blob/master/martian/adapter/adapter.go)
To implement a stage with Go, simply import
`github.com/martian-lang/martian/martian/adapter` and call the `RunStage`
method with your stage code logic as parameters from the main() method.

The `split`, `chunk`, `join` methods provided to `RunStage` called with
a `core.Metadata` object which provides access to args, outs, and so on.
For an example of how this can be used, see the
[go-based integration test stage](https://github.com/martian-lang/martian/blob/master/martian/test/sum_squares/sum_squares.go)
as an example.

Stage code can write to the stage `log` file with
[`util.Log`](https://godoc.org/github.com/martian-lang/martian/martian/util#Log)
and related methods.

The adapter handles writing the expected output files for the stage through
the return values of the methods given to `RunStage`.  `RunStage` will also
exit the process on completion - don't put any logic after the `RunStage` call.

## Writing an Adapter

If you are interested in developing a new Martian language adapter or
contributing to an existing one, you can find more details about the adapter
API [here](https://github.com/martian-lang/martian/tree/master/adapters).
Pull requests welcome!
