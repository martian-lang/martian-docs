---
date: 2017-05-21T17:53:15-07:00
title: Running Pipelines
type: post
---

## Invoking a Pipeline

Thus far we have shown how to **define** stages and pipelines in MRO files. To actually **run** a pipeline, one writes a single pipeline `call` statement with a particular set of input arguments, into an MRO file. This is called an invocation. To invoke the example pipeline from above:

`invoke.mro`
~~~~
@include "pipeline.mro"

call DUPLICATE_FINDER(
    unsorted = "/home/duplicator_dave/unsorted.txt",
)
~~~~

Typically, an invocation MRO file contains a single `@include` statement that includes the pipeline definition, and a single `call` statement. It is generally discouraged to `call` a pipeline in the same file in which it is defined, because then the pipeline definition cannot be easily reused for other invocations with different input arguments.

When a pipeline is run, the instantiation of it is called a **"pipestance"**, which is a portmanteau of "pipeline" and "instance".

## How mrp Works

To run a pipeline, simply pass the invocation MRO file to `mrp`, which is the Martian runtime that executes pipelines.

~~~~
mrp invoke.mro
~~~~

- Parse and validate MRO file
- Convert MRO AST into the graph representation of the pipeline
- Begin evaluating dependencies and executing the stages of the pipeline
- Continuously monitors stages and advances through the pipeline graph when dependencies are satisfied

[ WIP - mrp options ]

## Restarting

[ WIP ]

Just run mrp again with the same mro file. Stages that were failed

## Logging

[ WIP ]
