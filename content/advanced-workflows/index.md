---
date: 2016-07-01T17:53:15-07:00
title: Advanced Workflows
type: post
---

## Disabling sub-pipelines

Sometimes the choice of which sub-pipelines to run on the data depends on the
data.
For example,
the first part of a pipeline might determine which of
several algorithms is likely to yield the best results on the given data set.
To support this,
Martian 3.0 allows disabling of calls, e.g.

```coffee
pipeline DUPLICATE_FINDER(
    in  txt  unsorted,
    out txt  duplicates,
)
{
    call CHOOSE_METHOD(
        unsorted = self.unsorted,
    )
    call SORT_1(
        unsorted = self.unsorted,
    ) using (
        disabled = CHOOSE_METHOD.disable1,
    )
    call SORT_2(
        unsorted = self.unsorted,
    ) using (
        disabled = CHOOSE_METHOD.disable2,
    )

    call FIND_DUPLICATES(
        method_1_used = CHOOSE_METHOD.disable2,
        sorted1       = SORT_1.sorted,
        sorted2       = SORT_2.sorted,
    )
    return (
        duplicates = FIND_DUPLICATES.duplicates,
    )
}
```

Disabled pipelines or stages will not run,
and their outputs will be populated
with null values.
Downstream stages must be prepared to deal with this case.

Note that the value being bound to
`disabled` must be a boolean.
Martian does
not have a concept of "falsey"
values the way for example Python or JavaScript
do.

## Parallelization

Subject to resource constraints,
Martian parallelizes work by breaking
pipeline logic into chunks and parallelizing them in two ways.
First,
stages can run in parallel if they don't depend on each other's outputs.
Second,
individual stages may split themselves into several chunks.

### Chunking

Stages which split are specified in mro as, for example,

```coffee
stage SUM_SQUARES(
    in  float[] values,
    out float   sum,
    src comp    "sum_squares",
) split (
    in  float   value,
    out float   value,
)
```

In this example,
the stage takes an array of "values" as inputs.
The "split"
function (see [writing stages](../writing-stages/#Split Interface)) determines
how to distribute the input data across chunks,
giving a "value" to each,
as well as potentially setting thread and memory requirements for each chunk
and the join.
After the chunks run,
the join phase aggregates the output
from all of the chunks into the single output of the stage.

### `map call`

To run a stage or sub-pipeline once for each element in an array or map,
one can
say

```coffee
stage SQUARE(
    in  float value,
    out float square,
    src comp  "square",
)

stage SUM(
    in  float[] values,
    out float   sum,
    src comp    "sum",
)

pipeline SUM_SQUARES(
    in  float[] values,
    out float   sum,
)
{
    map call SQUARE(
        value = split self.values,
    )

    call SUM(
        values = SQUARE.square,
    )

    return (
        sum = SUM.sum,
    )
}
```

which is mostly equivalent to the chunked version shown above in this case,
however it opens up new possibilities for pipelines.
Furthermore, because the
next call can be mapped over the outputs of the previous one,
in some cases one
can improve efficiency by avoiding the useless
`join` and `split` in between.

One or more parameters to a
`map call`
must be declared as being `split`.
If
more than one parameter is bound in this way,
all of them must be bound to
either arrays with the same lengths or typed maps with the same keys.
If the
split argument was an array,
the output of the stage will be an array with the
same length.
If it was a typed map,
the output will be a typed map with the
same keys.
Splitting an untyped map is not permitted,
as there is no way to
confirm compatibility of the values.

## Preflight Checks

Preflight checks are used to
"sanity check"
the environment and top-level
pipeline inputs for a pipeline,
for example ensuring that all required
software dependencies are available in the user's
`PATH` environment, or that
specified input files are present.
A stage can be specified as preflight in
the call by specifying

```coffee
call PREFLIGHT_STAGE(
    arg1 = self.input1,
) using (
    preflight = true,
)
```

Preflight stages cannot have outputs and cannot have their inputs bound to
outputs of other stages.
Even when embedded in a sub-pipeline, they will always
run before any other stages.

Preflight stages may also specify
`local = true`
in the call properties to
require that the stage runs as a child process of
`mrp` even in cluster mode.
Use this option with care,
as `mrp` may be running on a submit host with
very limited resources.
