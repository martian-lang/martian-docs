---
date: 2016-07-01T17:53:15-07:00
title: Job Management
type: post
---

## Resource consumption

Martian is designed to run stages in parallel.
Either locally or in cluster
mode,
it tries to ensure sufficient threads and memory are available for each
job running in parallel.
The default reservation is controlled by the
`jobmanagers/config.json`
file (see below).
If a job needs more resources
than the default, there are two ways to request them.

If the stages splits
(see [Advanced Features: Parallelization](../advanced-workflows/#chunking)),
the split stage can override the default
reservations of the chunk or join phases by setting the
`__mem_gb`,
`__vmem_gb`
or `__threads`
keys in the chunk or join part of the `chunk_defs`
it returns.
This is required if for example the split,
chunk, or join methods don't all
have the same requirements,
or if the split needs to compute the requirements
dynamically.
Alternatively,
setting the resource requirements for the split,
or statically declaring the resources for all 3 phases (or just the chunk,
if
there is no split), can be done in the mro file, e.g.

```coffee
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

As a special signal to the runtime,
a stage may request a negative quantity for
memory or threads.
A negative value serves as a signal to the runtime that the
stage requires at least the absolute value of the requested amount,
but can use
more if available.
That is, if a stage requests `threads = -4`, and `mrp` was
started with `--localcores=2`
it will fail, but if it were started with
`--localcores=8`
it would be treated as if it had asked for 8 threads.
The job
can check the metadata in the
`_jobinfo` file to find out how many it actually
got.

During development,
one may wish to run `mrp` with the `--monitor` flag, which
enforces that jobs stay within their resource reservation.

### Virtual Address Space (a.k.a. virtual memory or vmem)

Some systems enforce limits on virtual address space size in a misguided effort
to protect shared systems from processes which use too much memory.
While
there is no practical reason to impose such a limit on modern Linux systems,
the `vmem_gb`
resource request exists to prevent pipeline failures on systems
which impose such a limit anyway.

If `mrp`
detects that a virtual address space limit has been set,
e.g. through
`ulimit -d`
or `-v`,
or by a job manager such as SGE with `h_vmem` or `s_vmem`
set,
it will throttle local-mode jobs based on the vmem reservation.
The
default vmem reservation for a job is equal to the (rss)
memory reservation
plus a constant
`extra_vmem_per_job`
defined in `jobmanagers/config.json`
which defaults to 3GB.

In cluster mode,
if the job mode defined in
`jobmanagers/config.json`
sets the
configuration key `mem_is_vmem`
to true, then `__MRO_MEM_GB__` and such will
use vmem amounts instead of RSS amounts.
This is true by default for SGE
clusters,
since most such clusters either do not enforce memory restrictions
at all or are misconfigured to enforce vmem restrictions.
In all cluster
mode templates the variables
`__MRO_VMEM_GB__`
and similar can be used to get
vmem amounts.

## Job Management

Broadly speaking,
Martian has two ways to run stage jobs:
Local Mode and Cluster Mode.

### Local Mode

In local mode,
stage jobs run as a child process of
`mrp` on the same machine.
Even in cluster mode,
stages may be executed in local mode if the mro invokes
them with `call local`.
Several options to `mrp` control job scheduling
behavior for local jobs

|Option|Effect|
|---|---|
|<nobr>`--localcores=NUM`</nobr>|Specifies the number of threads worth of work `mrp` should schedule simultaneously.  The default is the number of logical cores on the machine.|
|<nobr>`--localmem=NUM`</nobr>|Specifies the amount of memory, in gigabytes, which `mrp` will allow to be reserved by jobs running in parallel.  The default is 90% of the system's total memory.|
|<nobr>`--limit-loadavg`</nobr>|Instructs `mrp` to monitor the system [loadavg](https://en.wikipedia.org/wiki/Load_(computing) ), and avoid starting new jobs if the difference between the number of logical cores on the system and the current one-minute load average is less than the number of threads requested by a job.  This may be useful for throttling the start of new jobs on shared systems which are heavily loaded, especially shared systems which do not enforce any kind of quota.  However it should be noted that CPU load tends to fluctuate, so in many cases this only delays the job start until the next time the load drops temporarily.|
|<nobr>`--localvmem=NUM`</nobr>|Causes `mrp` to behave as if it detected a virtual memory `rlimit` set for the given number of gigabytes.|

### Cluster Mode

Larger research groups often have infrastructure for shared,
distributed
workloads,
such as [SGE](https://en.wikipedia.org/wiki/Oracle_Grid_Engine),
[slurm](https://slurm.schedmd.com/),
or [LSF](https://en.wikipedia.org/wiki/Platform_LSF).
Martian supports
distributing stage chunks on such platforms through a flexible,
extensible
interface.

If `mrp` is started with
`--jobmode=MODE`
and `MODE` is not "`local`", it
looks in its
`jobmanagers/config.json`
file for a key in the `jobmodes` element
corresponding to `MODE`.
In that object, the following values are used to
configure the job:

|Key|Effect|
|---|---|
|`cmd`|The command (executable) used to submit batch work to the cluster manager.|
|`args`|Additional arguments to pass to the executable.  Ideally the batch submit executable has a mode to return just the "job ID" on standard output, without any other formatting.  If an argument is required to enable this mode, it should be added there, as well as any other fixed arguments which are required.|
|`queue_query`|A script, which `mrp` will look for in its `jobmanagers` directory, which accepts a newline-separated list of job IDs on standard input and returns on standard output the newline-separated list of job IDs which are known to the job manager to be still queued or running.  This is used for Martian to detect if a job failed without having a chance to write its metadata files, for example if the job template incorrectly specified the environment.|
|`queue_query_grace_secs`|If `queue_query` was specified, this determines the minimum time `mrp` will wait, after the `queue_query` command determines that a job is no longer running, before it will declare the job dead.  In many cases, due to the way filesystems cache metadata, the completion notification files which jobs produce may not be visible from where `mrp` is running at the same time that the job manager reports the job being complete, especially when the filesystem is under heavy load.  The grace period prevents succeeded jobs from being declared failed.|
|`env`|Specifies environment variables which are required to be set in this job mode.|
|`mem_is_vmem`|(optional) If true, template variables for `MEM` will use `VMEM` values.|

`mrp` will execute the specified
`cmd` with the specified `args` and pipe a job
script to its standard input (see [Templates](#templates) below for how the job
script is generated).
If the command's standard output consists of a string
with no newlines or whitespace,
it is interpreted as a job ID and recorded with
the job,
to potentially be used later with the `queue_query` script.

If the command line to `mrp`
includes the `--never-local` flag, the `local`
attribute on stages other than preflight stages will be ignored.

### Templates

In addition to the information in the
`config.json` file, `mrp` looks for a
file in the `jobmanagers`
directory named `MODE.template` for the specified
`MODE`.
`mrp`
does string substitutions on the content of the file to produce
the job script.
The string substitutions are of the form `__MRO_VALUE__`,
where `VALUE`
[is one of](https://github.com/martian-lang/martian/blob/6edf70a6f70d86a2ae08169356f3b1b35ffc0818/src/martian/core/jobmanager.go#L549)

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

There are several options for throttling how
`mrp` uses the cluster
job manager.

|Option|Effect|Default|
|---|---|---|
|<nobr>`--maxjobs`</nobr>|Limit the number of jobs queued or pending on the cluster simultaneously.  0 is treated as unlimited.|64|
|<nobr>`--jobinterval`</nobr>|Limit the rate at which jobs are submitted to the cluster.|100ms|
|<nobr>`--mempercore`</nobr>|For clusters which do not manage memory reservations, specifies the amount of memory `mrp` should expect to be available for each core.  If this number is less than the cores to memory ratio of a job, extra threads will be reserved in order to ensure that the job gets enough memory.  A very high value will effectively be ignored.  A low value will result in idle CPUs, but hopefully prevent cluster nodes from exhausting their memory.|none|

### The "special" resource

In addition to threads and memory,
MRO and stage split definitions may include
a request for the `special` resource.
This is only used in cluster mode, and
is intended for cases where the cluster manager requires special additional
flags for some stages,
for example if there is a separate queue for jobs which
require very large amounts of memory.

The `resopt` parameter in the
`jobmanagers/config.json`
file configures the way
such resources are incorporated into the job template for your cluster.
For SGE, for example,
the parameter is `#$ -l __RESOURCES__`

The `MRO_JOBRESOURCES`
environment variable may contain a semicolon-separated
list of key:value pairs.
If the `special` resource requested for the job
corresponds to one of those keys,
then `__MRO_RESOURCES__` in the job template
is replaced with the `resopt`
value from `jobmanagers/config.json`, with the
value corresponding to the given key substituted for
`__RESOURCES__`.

For example, if the `resopt`
config parameter is `#$ -l __RESOURCES__`,
`MRO_JOBRESOURCES=highmem;mem640=TRUE;lowmem:mem64=TRUE`,
and the job requests
the special resource
`"highmem"`,
then `__MRO_RESOURCES__` in the job template
gets replaced with `#$ -l mem640=TRUE`.

### Additional job management settings

There are a few additional options available in the
`jobmanagers/config.json`
file which apply in both cluster and local modes,
under the `settings` key.

Several popular third-party libraries use environment variables to control
the number of threads they parallelize jobs over,
for example `OMP_NUM_THREADS`
for OpenMP.
The `thread_envs`
key specifies a list of environment variables
which should be set to be equal to the job thread reservation.
These are
applied in cluster mode,
and in local mode if the number of threads is
constrained.
In local mode without a constraint on
`mrp`'s total thread count,
it is not used,
as it's expected that the user is not sharing the machine with
other users,
so such a constraint on internal parallelism is just potentially
idle CPU cycles.

Additionally,
for jobs which do not specify their thread or memory
requirements, the
`threads_per_job`
and `memGB_per_job` keys specify default
values.
