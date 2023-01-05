---
date: 2016-07-01T17:53:15-07:00
title: Storage Management
type: post
---

Big data pipeline frequently produce large amounts of intermediate data, stored
on the filesystem both because it isn't practical to store it all in RAM and
because this allows for a pipeline which fails part way through to be restarted
without redoing all the work from scratch.  The Martian runtime's VDR (volatile
data removal) feature is intended for removing this intermediate data once it
is no longer needed.

## Volatile Data Removal

A call to a stage can be marked `volatile` by specifying
```coffee
call STAGE_NAME(
    arg1 = value,
) using (
    volatile = true,
)
```

If a stage is marked volatile it is eligible for volatile data removal once
all stages which depend on it are complete.  When the "VDR killer" is invoked,
all data files owned by the stage will be deleted (except those files specified
in output parameters of the top-level pipeline), freeing up disk space.  Job
metadata is retained, and the total amount of freed space is recorded.

In `--vdrmode=rolling`, the VDR killer is invoked whenever any stage completes.
In `--vdrmode=post` it is invoked when the pipeline completes.
Mrp's default is `--vdrmode=rolling`, however for development purposes, one
may wish to set `--vdrmode=disable` to preserve intermediate results.

Additionally, when VDR is not disabled, all stages which split will have their
chunks' files cleaned out by VDR when all dependent stages have completed.

### Strict-mode VDR

To enable more aggressive file cleanup, a stage can be marked
"strict-mode compatible" when it is declared:
```coffee
stage STAGE_NAME(
    in  int  value,
    out txt  summary,
    out gz[] archives,
    out json index,
) using (
    volatile = strict,
)
```
This is telling the runtime that the stage should not be producing any files
which other stages depend on without explicitly mentioning them in an output.
As a best practice, all new stages should opt in to this behavior.  All calls
to stages declared using `volatile = strict` are implicitly volatile,
regardless of the state of the `volatile` modifier on the `call`.

When a stage is marked strict-mode compatible, rather than waiting for all
dependent stages to complete and then deleting all of the files (or just the
chunk files if the top-level pipeline's outputs are bound to any of the outs),
each of the stage's output parameters is checked for file paths.  Files with
paths which are not mentioned in the stage's outputs are deleted immediately
when the stage completes.  Other files are deleted when there are no longer
any incomplete stages depending on the parameter which mentions that file.

In the example above, imagine a pipeline
```coffee
pipeline COMPLEX_VDR(
    in  int value,
    out txt output1,
    out int output2,
    out int output3,
)
{
    call STAGE_NAME(
        value = self.value,
    )

    call STAGE_2(
        value = STAGE_NAME.archives,
    )

    call STAGE_3(
        value = STAGE_NAME.index,
    )

    return (
        output1 = STAGE_NAME.summary,
        output2 = STAGE_2.output,
        output3 = STAGE_3.output,
    )
}
```
`summary` will be deleted immediately unless `COMPLEX_VDR`'s `output1` is
bound to another stage's inputs or the top-level pipeline's outputs (or if
`COMPLEX_VDR` itself is the top-level pipeline).  Otherwise it will be once
those stages have completed, or never if it's bound to the top-level outputs.
deleted. The files mentioned in `archives` will be deleted as soon as
`STAGE_2` completes successfully, and `index` will be deleted as soon as
`STAGE_3` completes successfully.  Note that this means that `index` should not
contain paths to the files listed in `archives`, because those files have
different lifetimes.

### Retained outputs

Frequently during debugging, and occasionally in other circumstances, it is
desirable to preserve a file after a pipeline completes even if it is not
part of the formal outputs, for example if one wants to later rerun a subset
of the pipeline which depends on that file, or if one wants to be able to
access a more "raw" form of the output.

"Retained" outputs are treated from a VDR perspective as if they were bound to
the top-level pipeline's outputs - they are never deleted.

A stage can be declared as retaining some outputs:
```coffee
stage STAGE_NAME(
    in  int  value,
    out txt  summary,
    out gz[] archives,
    out json index,
) using (
    volatile = strict,
) retain (
    summary,
)
```
This prevents `summary` from ever being deleted by VDR, regardless of whether
it is bound to anything else.  This should be used mainly for cases of small
output files which are important for later debugging.

Additionally, pipelines can declare retained parameters, e.g.
```coffee
pipeline PIPELINE_NAME(
    ...
)
{
    call PIPELINE_1(
        ...
    )

    call STAGE_2(
        ...
        PIPELINE_1.output1,
    )

    return (
        ...
    )

    retain (
        PIPELINE_1.output1,
    )
}
```
This means that the files mentioned in `output1` of `PIPELINE_1` will never be
deleted by VDR.  This is the preferred method to use during debugging to
preserve outputs which may be required for rerunning a later stage, in this
example `STAGE_2`.  It is preferred in part because it puts the `retain`
declaration closer to where the value is being used (and thus more clear about
why it's being retained) and because the stage to which `PIPELINE_1.output1` is
eventually bound might be called in other places where retention is not
required.
