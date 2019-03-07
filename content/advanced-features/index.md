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
reservations of the chunk or join phases by setting the `__mem_gb`,
`__vmem_gb` or `__threads` keys in the chunk or join part of the `chunk_defs`
it returns.
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

As a special signal to the runtime, a stage may request a negative quantity for
memory or threads.  A negative value serves as a signal to the runtime that the
stage requires at least the absolute value of the requested amount, but can use
more if available.  That is, if a stage requests `threads = -4`, and `mrp` was
started with `--localcores=2` it will fail, but if it were started with
`--localcores=8` it would be treated as if it had asked for 8 threads.  The job
can check the metadata in the `_jobinfo` file to find out how many it actually
got.

During development, one may wish to run `mrp` with the `--monitor` flag, which
enforces that jobs stay within their resource reservation.

### Virtual Address Space (a.k.a. virtual memory or vmem)
Some systems enforce limits on virtual address space size in a misguided effort
to protect shared systems from processes which use too much memory.  While
there is no practical reason to impose such a limit on modern Linux systems,
the `vmem_gb` resource request exists to prevent pipeline failures on systems
which impose such a limit anyway.

If `mrp` detects that a virtual address space limit has been set, e.g. through
`ulimit -d` or `-v`, or by a job manager such as SGE with `h_vmem` or `s_vmem`
set, it will throttle local-mode jobs based on the vmem reservation.  The
default vmem reservation for a job is equal to the (rss) memory reservation
plus a constant `extra_vmem_per_job` defined in `jobmanagers/config.json`
which defaults to 3GB.

In cluster mode, if the job mode defined in `jobmanagers/config.json` sets the
configuration key `mem_is_vmem` to true, then `__MRO_MEM_GB__` and such will
use vmem amounts instead of RSS amounts.  This is true by default for SGE
clusters, since most such clusters either do not enforce memory restrictions
at all or are misconfigured to enforce vmem restrictions.  In all cluster
mode templates the variables `__MRO_VMEM_GB__` and similar can be used to get
vmem amounts.

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
|<nobr>`--localvmem=NUM`</nobr>|Causes `mrp` to behave as if it detected a virtual memory `rlimit` set for the given number of gigabytes.|

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
|`mem_is_vmem`|(optional) If true, template variables for `MEM` will use `VMEM` values.|

`mrp` will execute the specified `cmd` with the specified `args` and pipe a job
script to its standard input (see [Templates](#templates) below for how the job
script is generated).  If the command's standard output consists of a string
with no newlines or whitespace, it is interpreted as a job ID and recorded with
the job, to potentially be used later with the `queue_query` script.

If the command line to `mrp` includes the `--never-local` flag, the `local`
attribute on stages other than preflight stages will be ignored.

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
|`VMEM_GB`|The amount of virtual memory, in GB, which the job is expected to use.  Similarly to `MEM_GB`, `VMEM_MB`, `VMEM_KB`, and `MEM_B` are also provided.|
|`VMEM_GB_PER_THREAD`|Equal to `VMEM_GB` divided by `THREADS`.  Similarly for `MB`, `KB`, and `B`.|

### Cluster mode command line options

There are several options for throttling how `mrp` uses the cluster
job manager.

|Option|Effect|Default|
|---|---|---|
|<nobr>`--maxjobs`</nobr>|Limit the number of jobs queued or pending on the cluster simultaneously.  0 us treated as unlimited.|64|
|<nobr>`--jobinterval`</nobr>|Limit the rate at which jobs are submitted to the cluster.|100ms|
|<nobr>`--mempercore`</nobr>|For clusters which do not manage memory reservations, specifies the amount of memory `mrp` should expect to be available for each core.  If this number is less than the cores to memory ratio of a job, extra threads will be reserved in order to ensure that the job gets enough memory.  A very high value will effectively be ignored.  A low value will result in idle CPUs, but hopefully prevent cluster nodes from exhausting their memory.|none|

### The "special" resource

In addition to threads and memory, MRO and stage split definitions may include
a request for the `special` resource.  This is only used in cluster mode, and
is intended for cases where the cluster manager requires special additional
flags for some stages, for example if there is a separate queue for jobs which
require very large amounts of memory.

The `resopt` parameter in the `jobmanagers/config.json` file configures the way
such resources are incorporated into the job template for your cluster.
For SGE, for example, the parameter is `#$ -l __RESOURCES__`

The `MRO_JOBRESOURCES` environment variable may contain a semicolon-separated
list of key:value pairs.  If the `special` resource requested for the job
corresponds to one of those keys, then `__MRO_RESOURCES__` in the job template
is replaced with the `resopt` value from `jobmanagers/config.json`, with the
value corresponding to the given key substituted for `__RESOURCES__`.

For example, if the `resopt` config parameter is `#$ -l __RESOURCES__`,
`MRO_JOBRESOURCES=highmem;mem640=TRUE;lowmem:mem64=TRUE`, and the job requests
the special resource `"highmem"`, then `__MRO_RESOURCES__` in the job template
gets replaced with `#$ -l mem640=TRUE`.

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
The `--debug` option to `mrp` causes it to log additional information which may
be helpful for debugging `mrp`.

For debugging stage code, the `--stackvars` flag sets an option in the
`jobinfo` file given to stage code.  For the python adapter, this flag causes
it to dump all local variables from every stack frame on failure.

## Resource Overrides
By specifying an appropriate `json` file on the `mrp` command line with the
`--override=<FILE>` flag, one can override the resource reservation, whether
it was left at the default or specified in the mro source or split.  The format
of this json file is
```json
{
  "TOP_LEVEL_PIPELINE.SUBPIPELINE_1.INNER_SUBPIPELINE_1.STAGE_NAME": {
    "split.mem_gb": 2,
    "chunk.mem_gb": 24,
    "join.mem_gb": 2,
    "chunk.threads": 2
  },
  "TOP_LEVEL_PIPELINE.SUBPIPELINE_2.INNER_SUBPIPELINE_2.OTHER_STAGE": {
    "split.mem_gb": 2,
    "chunk.mem_gb": 24,
    "join.mem_gb": 2,
    "chunk.threads": 2
  }
}
```
In addition to threads and memory, overrides can be used to turn volatility
(see [Storage Management](../storage-management/)) on or off by setting
`"force_volatile": true` or `false`.

The overrides file can also be used to control profile data collection
(see below) for an individual stage, by for example setting
`"chunk.profile": "cpu"`.

## Preflight Checks
Preflight checks are used to "sanity check" the environment and top-level
pipeline inputs for a pipeline, for example ensuring that all required
software dependencies are available in the user's `PATH` environment, or that
specified input files are present.  A stage can be specified as preflight in
the call by specifying
```
call PREFLIGHT_STAGE(
    arg1 = self.input1,
) using (
    preflight = true,
)
```
Preflight stages cannot have outputs and cannot have their inputs bound to
outputs of other stages.  Even when embedded in a sub-pipeline, they will always
run before any other stages.

Preflight stages may also specify `local = true` in the call properties to
require that the stage runs as a child process of `mrp` even in cluster mode.
Use this option with care, as `mrp` may be running on a submit host with
very limited resources.

## Volatile Data Removal
See [Storage Management](../storage-management/).

## Parameter Sweeping

Often when testing changes to a pipeline, one wants to try the pipeline with
several different possible values for one or more of the pipeline inputs.
Parameter sweeping is intended for this use case.  A call such as
```
call PIPELINE_NAME(
    arg1 = "foo",
    arg2 = sweep(
        "bar",
        "baz",
    ),
)
```
will run the pipeline twice, once with `arg2 = "bar"` and again with
`arg2 = "baz"`.  The runtime is clever enough to avoid rerunning stages which
do not depend on `arg2` either directly or by depending on a stage which does.
In some cases this can save substantial computing resources.

This feature is intended for testing purposes only and should not be used in
production pipelines.  It can be confusing to figure out which version of the
final pipeline outputs corresponded to which fork, and the runtime may behave
poorly if multiple parameters are swept over in the same pipestance.

## Performance Analysis
The `_jobinfo` file in each stage's split/chunk/join directories includes
several performance metrics, including cpu, memory, and I/O usage.  On
successful pipestance completion these statistics are aggregated into the
top-level `_perf` file.

In addition, MRP can be started with the `--profile` mode to enable various
profiling tools for stage code, or profile modes can be enabled for a subset
of stages using `--override` (see above).  Similarly to `--jobmode`, profile
modes are defined in the `profiles` key of `jobmanagers/config.json`.

Each configured profile mode may have several configured parameters.

|  Key  | Effect |
|-------|--------|
|`adapter`| This string is passed to the native stage code adapter, and the adapter decides what to do with it.|
| `env` | This dictionary allows environment variables to be set.  If `${PROFILE_DEST}` or `${RAW_PERF_DEST}` are present in the value, they will be replaced with the full path to the `_profile.out` or `_perf.data` files in the stage's metadata directory. Any other environment variables will also be expanded at run time. |
| `cmd` | This string specifies a command which should run in parallel with the stage code and attempt attach to the stage code process. |
| `args`| This array specifies the arguments passed to `cmd`. Just like with `env`, these arguments are subject to environment variable expansion.  The additional psudo-environment variable `${STAGE_PID}` is expanded to the pid of the running stage process so that the command may attach. |
| `defaults` | This dictionary allows users to specify default values for environment variables used in expanding `args` and `env`, if they aren't already non-empty at runtime.|

The default martian distribution configures the following profile modes:

|  Mode  | Effect |
|--------|--------|
| `cpu`  | Enables adapter-based cpu profiling.  For python, this uses `cProfile`.  For Go, this uses `runtime/pprof`. |
| `line` | Enables Python's `line_profiler` (which must be installed). |
| `mem`  | Enables adapter-based memory profiling, using an allocator hook in python, or `runtime/pprof` in Go.  Additionally sets `MALLOC_CONF` and `HEAPPROFILE` to enable heap profiling for `jemalloc` (which is used by default for Rust) and `tcmalloc`, respectively. |
| `perf` | Enables profile sample collection with Linux's `perf record`. |
| `pyflame` | Enables profile sample collection with [PyFlame](https://github.com/uber/pyflame). |

## Completion Hooks

A command may be specified in `mrp`'s `--onfinish=<command>` flag.  The command
must be the path to an executable file.  It will run when the pipestance
completes or fails, with the following command line arguments:

- path to pipestance
- {complete|failed}
- pipestance ID
- path to error file (if there was an error)


### mrp Options

 The rest are described here:

|Option|Description|
|---|---|
|`--zip`|Zip metadata files after pipestance completes.|
|`--tags=TAGS`|Tag pipestance with comma-separated key:value pairs.|
|`--autoretry=NUM`|Automatically retry failed runs up to NUM times.|
|`--retry-wait=SECS`|After a failure, wait `SECS` seconds before automatically retrying.|
|All others|See [Advanced Features](../advanced-features)|
