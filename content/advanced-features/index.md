---
date: 2016-07-01T17:53:15-07:00
title: Advanced Features
type: post
---

Martian supports a number of advanced features to provide:

- Performance and resource efficiency that scales from single servers to large high-performance compute clusters
- Early error detection
- Data storage efficiency
- Loosely-coupled integration with other systems

## Disabling sub-pipelines
Sometimes the choice of which sub-pipelines to run on the data depends on the
data.  For example, the first part of a pipeline might determine which of
several algorithms is likely to yield the best results on the given data set.
To support this, Martian 3.0 allows disabling of calls, e.g.
```
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
Disabled pipelines or stages will not run, and their outputs will be populated
with null values.  Downstream stages must be prepared to deal with this case.

## Parallelization
Subject to resource constraints, Martian parallelizes work by breaking
pipeline logic into chunks and parallelizing them in two ways.  First,
stages can run in parallel if they don't depend on each other's outputs.
Second, individual stages may split themselves into several chunks.

Stages which split are specified in mro as, for example,
```
stage SUM_SQUARES(
    in  float[] values,
    out float   sum,
    src comp    "sum_squares",
) split (
    in  float   value,
    out float   value,
)
```
In this example, the stage takes an array of "values" as inputs.  The "split"
function (see [writing stages](../writing-stages/#Split Interface)) determines
how to distribute the input data across chunks, giving a "value" to each,
as well as potentially setting thread and memory requirements for each chunk
and the join.  The after the chunks run, the join phase aggregates the output
from all of the chunks into the single output of the stage.

## Resource consumption
Martian is designed to run stages in parallel.  Either locally or in cluster
mode, it tries to ensure sufficient threads and memory are available for each
job running in parallel.  The default reservation is controlled by the
`jobmanagers/config.json` file (see below).  If a job needs more resources
than the default, there are two ways to request them.

If the stages splits (see above), the split stage can override the default
reservations of the chunk or join phases by setting the `__mem_gb` or
`__threads` keys in the chunk or join part of the `chunk_defs` it returns.
This is required if for example the split, chunk, or join methods don't all
have the same requirements, or if the split needs to compute the requirements
dynamically.  Alternatively, setting the resource requirements for the split,
or statically declaring the resources for all 3 phases (or just the chunk, if
there is no split), can be done in the mro file, e.g.
```
stage SUM_SQUARES(
    in  float[] values,
    out float   sum,
    src comp    "sum_squares",
) split (
    in  float   value,
    out float   value,
) using (
    mem_gb  = 4,
    threads = 16,
)
```

## Job Management
Broadly speaking, Martian has two ways to run stage jobs: Local Mode and Cluster Mode.

### Local Mode
In local mode, stage jobs run as a child process of `mrp` on the same machine.
Even in cluster mode, stages may be executed in local mode if the mro invokes
them with `call local`.  Several options to `mrp` control job scheduling
behavior for local jobs

|Option|Effect|
|---|---|
|<nobr>`--localcores=NUM`</nobr>|Specifies the number of threads worth of work `mrp` should schedule simultaneously.  The default is the number of logical cores on the machine.|
|<nobr>`--localmem=NUM`</nobr>|Specifies the amount of memory, in gigabytes, which `mrp` will allow to be reserved by jobs running in parallel.  The default is 90% of the system's total memory.|
|<nobr>`--limit-loadavg`</nobr>|Instructs `mrp` to monitor the system [loadavg](https://en.wikipedia.org/wiki/Load_(computing) ), and avoid starting new jobs if the difference between the number of logical cores on the system and the current one-minute load average is less than the number of threads requested by a job.  This may be useful for throttling the start of new jobs on shared systems which are heavily loaded, especially shared systems which do not enforce any kind of quota.  However it should be noted that CPU load tends to fluctuate, so in many cases this only delays the job start until the next time the load drops temporarily.|

### Cluster Mode
Larger research groups often have infrastructure for shared, distributed
workloads, such as [SGE](https://en.wikipedia.org/wiki/Oracle_Grid_Engine),
[slurm](https://slurm.schedmd.com/),
or [LSF](https://en.wikipedia.org/wiki/Platform_LSF).  Martian supports
distributing stage chunks on such platforms through a flexible, extensible
interface.

If `mrp` is started with `--jobmode=MODE` and `MODE` is not "`local`", it
looks in its `jobmanagers/config.json` file for a key in the `jobmodes` element
corresponding to `MODE`.  In that object, the following values are used to
configure the job:

|Key|Effect|
|---|---|
|`cmd`|The command (executable) used to submit batch work to the cluster manager.|
|`args`|Additional arguments to pass to the executable.  Ideally the batch submit executable has a mode to return just the "job ID" on standard output, without any other formatting.  If an argument is required to enable this mode, it should be added there, as well as any other fixed arguments which are required.|
|`queue_query`|A script, which `mrp` will look for in its `jobmanagers` directory, which accepts a newline-separated list of job IDs on standard input and returns on standard output the newline-separated list of job IDs which are known to the job manager to be still queued or running.  This is used for Martian to detect if a job failed without having a chance to write its metadata files, for example if the job template incorrectly specified the environment.|
|`queue_query_grace_secs`|If `queue_query` was specified, this determines the minimum time `mrp` will wait, after the `queue_query` command determines that a job is no longer running, before it will declare the job dead.  In many cases, due to the way filesystems cache metadata, the completion notification files which jobs produce may not be visible from where `mrp` is running at the same time that the job manager reports the job being complete, especially when the filesystem is under heavy load.  The grace period prevents succeeded jobs from being declared failed.|
|`env`|Specifies environment variables which are required to be set in this job mode.|

`mrp` will execute the specified `cmd` with the specified `args` and pipe a job
script to its standard input (see [Templates](#templates) below for how the job
script is generated).  If the command's standard output consists of a string
with no newlines or whitespace, it is interpreted as a job ID and recorded with
the job, to potentially be used later with the `queue_query` script.

### Templates

In addition to the information in the `config.json` file, `mrp` looks for a
file in the `jobmanagers` directory named `MODE.template` for the specified
`MODE`.  `mrp` does string substitutions on the content of the file to produce
the job script.  The string substitutions are of the form `__MRO_VALUE__`,
where `VALUE` [is one of](https://github.com/martian-lang/martian/blob/6edf70a6f70d86a2ae08169356f3b1b35ffc0818/src/martian/core/jobmanager.go#L549)

|Key|Value|
|---|---|
|`JOB_NAME`|The fully qualified stage/chunk name.|
|`THREADS`|The number of threads requested for the job.|
|`STDOUT`/`STDERR`|The absolute paths to the expected destination location for the standard output/error files.|
|`JOB_WORKDIR`|The working directory in which the stage code is expected to.|
|`CMD`|The actual command line to execute.|
|`MEM_GB`|The amount of memory, in GB, which the job is expected to use.  Additionally, `MEM_MB`,`MEM_KB`, and `MEM_B` provide the value in other units if required.|
|`MEM_GB_PER_THREAD`|Equal to `MEM_GB` divided by `THREADS`.  Similarly for `MB`, `KB`, and `B`.|

### Cluster mode command line options

There are several options for throttling how `mrp` uses the cluster
job manager.

|Option|Effect|Default|
|---|---|---|
|<nobr>`--maxjobs`</nobr>|Limit the number of jobs queued or pending on the cluster simultaneously.  0 us treated as unlimited.||
|<nobr>`--jobinterval`</nobr>|Limit the rate at which jobs are submitted to the cluster.||
|<nobr>`--mempercore`</nobr>|For clusters which do not manage memory reservations, specifies the amount of memory `mrp` should expect to be available for each core.  If this number is less than the cores to memory ratio of a job, extra threads will be reserved in order to ensure that the job gets enough memory.  A very high value will effectively be ignored.  A low value will result in many wasted CPUs.|none|

### Additional job management settings

There are a few additional options available in the `jobmanagers/config.json`
file which apply in both cluster and local modes, under the `settings` key.

Several popular third-party libraries use environment variables to control
the number of threads they parallize jobs over, for example `OMP_NUM_THREADS`
for OpenMP.  The `thread_envs` key specifies a list of environment variables
which should be set to be equal to the job thread reservation.  These are
applied in cluster mode, and in local mode if the number of threads is
constrained.  In local mode without a constraint on `mrp`'s total thread count,
it is not used, as it's expected that the user is not sharing the machine with
other users, so such a constraint on internal parallelism is just potentially
idle CPU cycles.

Additionally, for jobs which do not specify their thread or memory
requirements, the `threads_per_job` and `memGB_per_job` keys specify default
values.

## Debugging options
The `--debug` option to mrp causes it to log additional information which may
be helpful for debugging.

For debugging stage code, the `--stackvars` flag sets an option in the
`jobinfo` file given to stage code.  For the python adapter, this flag causes
it to dump all local variables from every stack frame on failure.

## Overrides

## Preflight Checks

## Volatile Data Removal

A call to a stage can be marked `volatile` by specifying
```
call STAGE_NAME(
    arg1 = value,
) using (
    volatile = true,
)
```

If a stage is marked volatile it is eligible for volatile data removal once
all stages which depend on it are complete.  When the "VDR killer" is invoked,
all file data owned by the stage will be deleted, freeing up disk space.  Job
metadata is retained, and the total amount of freed space is recorded.  In
`--vdrmode=rolling`, the VDR killer is invoked whenever any stage completes.
In `--vdrmode=post` it is invoked when the pipeline completes.
Mrp's default is `--vdrmode=disabled` for development purposes, however
production pipeline wrapper scripts should set `--vdrmode=rolling` to
minimize the disk usage high-water-mark.

## Parameter Sweeping

## Performance Analysis

## Completion Hooks

- path to pipestance
- {complete|failed}
- pipestance ID
- path to error file (if there was an error)


### mrp Options

 The rest are described here:

|Option|Description|
|---|---|
|`--zip`|After pipestance Zip metadata files after pipestance completes.|
|`--tags=TAGS`|Tag pipestance with comma-separated key:value pairs.|
|`--autoretry=NUM`|Automatically retry failed runs up to NUM times.|
|All others|See [Advanced Features](../advanced-features)|
