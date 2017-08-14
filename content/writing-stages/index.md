---
date: 2016-08-01T17:53:15-07:00
title: Writing Stages
type: post
---

## Overview

Martian supports writing pipeline stages in virtually any language. The only requirement is that the language support JSON, which is nearly universal.

A Martian stage is an executable, either interpreted or compiled, that takes four command-line arguments as follows:

~~~~
$ stage_executable <type> <metadata_path> <files_path> <journal_prefix>
~~~~

The `type` argument is one of `split`, `join`, or `main` (the main body of the stage). The stage executable should switch on that type and provide implementations for each.

### Split Interface
[ WIP ]
### Join Interface
[ WIP ]
### Main/Chunk Interface
[ WIP ]

More details in [Advanced Features: Parallelization](../advanced-features/#parallelization).

## Martian Adapter

Martian provides support for writing stages in the form of adapters, whose purpose is to provide to stages the following:

- A well-defined interface for stages to be invoked by `mrp`
- Input arguments from upstream stages to be passed into the stage
- A well-defined method for returning output values to be passed to downstream stages
- An API so the stage can provide logging, status updates, and error reporting to its parent `mrp`

The goal of Martian adapters is the minimize the amount of boilerplate code that needs to be written for each stage implementation. Exactly how stage code is written and structured varies with the implementation language, but below are examples for languages that already have Martian adapters written.

## Martian Adapter API

The Martian adapter provides a number of services to the stage code. [ WIP ]

## Interpreted Languages
### Python

A Martian stage written in Python is simply a Python module. That is, a directory with an `__init__.py` containing the stage code. When writing a stage, you do not need to provide a `__main__` method as the Martian Python adapter provides an executable wrapper script that does an `import` of your Python module.

To satisfy the stage requirements, you must implement three functions `split`, `join`, and `main`, which will be called by the Martian Python adapter script.

The Python module should be located in its own directory somewhere under the `MROPATH`. The specific path is then specified in the MRO code to connect the MRO stage definition with the location of the Python implementation, e.g. `src py "path/to/my/python_module"`. Martian would then expect to be able to Python `import` that path as a module, and for it to implement `split`, `join` and `main` functions.

[ WIP ]

## Compiled Languages

Stage executables that are compiled must implement the command-line interface described above.

### Rust
### Go

## Shell Scripts

Stage executables that are shell scripts must implement the command-line interface described above.

## Writing an Adapter

If you are interested in developing a new Martian language adapter or contributing to an existing one, you can find more details [here](https://github.com/martian-lang/martian/tree/master/adapters).
