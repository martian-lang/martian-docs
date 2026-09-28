---
date: 2016-07-01T17:53:15-07:00
title: Advanced Features
type: post
---

Martian supports a number of advanced features to provide:

- Performance and resource efficiency that scales from single servers
  to large high-performance compute clusters
- Early error detection
- Data storage efficiency
- Loosely-coupled integration with other systems

## Debugging options

The `--debug` option to
`mrp` causes it to log additional information which may
be helpful for debugging `mrp`.

For debugging stage code,
the `--stackvars` flag sets an option in the
`jobinfo` file given to stage code.
For the python adapter, this flag causes
it to dump all local variables from every stack frame on failure.

## Resource Overrides

By specifying an appropriate
`json` file on the `mrp` command line with the
`--override=<FILE>`
flag, one can override the resource reservation, whether
it was left at the default or specified in the mro source or split.
The format
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

In addition to threads and memory,
overrides can be used to turn volatility
(see [Storage Management](../storage-management/)) on or off by setting
`"force_volatile": true`
or `false`.

The overrides file can also be used to control profile data collection
(see below)
for an individual stage, by for example setting
`"chunk.profile": "cpu"`.

## Performance Analysis

The `_jobinfo`
file in each stage's split/chunk/join directories includes
several performance metrics,
including cpu, memory, and I/O usage.
On
successful pipestance completion these statistics are aggregated into the
top-level `_perf` file.

In addition,
MRP can be started with the
`--profile` mode to enable various
profiling tools for stage code,
or profile modes can be enabled for a subset
of stages using `--override` (see above).
Similarly to `--jobmode`, profile
modes are defined in the
`profiles` key of `jobmanagers/config.json`.

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

A command may be specified in
`mrp`'s `--onfinish=<command>` flag.
The command
must be the path to an executable file.
It will run when the pipestance
completes or fails,
with the following command line arguments:

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
|All others|See [Job Management](../job-management/).|
