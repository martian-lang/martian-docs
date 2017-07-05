---
date: 2017-05-21T17:53:15-07:00
title: Running Pipelines
type: post
---

## Invocation

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

## Pipestance Layout

`mrp` creates a folder structure.

Easy to navigate. All you need are `cd`, `ls`, and `cat`. Pretty-printed JSON.

All pipestance state are in the filesystem. No database.

`files` folders

### Metadata
- `_log`
- `_jobinfo`
- `_stdout`
- `_stderr`
- `_errors`
- `_args`
- `_outs`
- `_complete`

## Volatile Data Removal

## Outputs

`outs` folder. Files get copied to this folder. Their original locations inside `files` folders are symlinked to the file in the `outs` folder.

`_uuid` uniquely identifies this pipestance. Useful for integration with other tracking systems.

`_timestamp` reports start and end times of the pipestance.

`invocation.mro` is copied and preserved. `mrosource.mro` contains the fully recursive preprocessed source code that was involved in this pipestance.

## Restarting

## Completion Hooks

## Logging

## User Interface

`--uiport=N`

## Resource Management

### Local Mode

### Cluster Mode

Templates

Throttling
