---
date: 2017-05-21T17:53:15-07:00
title: Running Pipelines
type: post
---

## Invoking a Pipeline

Thus far we have shown how to define stages and pipelines in MRO files. To run a pipeline, one writes a single pipeline `call` statement with a particular set of input arguments, into an MRO file. This is called an invocation. To invoke the example pipeline from above:

```invoke.mro```
~~~~
@include "pipeline.mro"

call DUPLICATE_FINDER(
    unsorted = "/home/duplicator_dave/unsorted.txt",
)
~~~~

Typically, an invocation MRO file contains a single `@include` statement that includes the pipeline definition, and a single `call` statement. It is generally discouraged to `call` a pipeline in the same file in which it is defined, because then the pipeline definition cannot be easily reused for other invocations with different input arguments.

When a pipeline is run, the instantiation of it is called a **"pipestance"**, which is a portmanteau of "pipeline" and "instance".

For more details on how to run an invocation MRO with the Martian runtime, see [Running Pipelines](../running-pipelines).

Running a pipeline requires an invocation MRO file that contains a pipeline `call` statement. We will use the example invocation from the [Writing Pipelines](../writing-pipelines/#pipeline-invocation) section:

```invoke.mro```
~~~~
@include "pipeline.mro"

call DUPLICATE_FINDER(
    unsorted = "/home/duplicator_dave/unsorted.txt",
)
~~~~

## How mrp Works

~~~~
mrp invoke.mro
~~~~

## Restarting


## Logging
