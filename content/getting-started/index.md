---
date: 2016-11-01T17:53:15-07:00
title: Getting Started
type: post
---

## Installing Martian

Official binary distributions of the Martian toolchain are available for Linux.
We hope to have MacOS and Windows support soon.

|Download|OS|Arch|SHA256|
|---|---|---|---|
|[martian-v4.0.4-linux-x86_64.tar.xz](https://github.com/martian-lang/martian/releases/download/v4.0.4/martian-v4.0.4-linux-x86_64.tar.xz)|Linux|x86-64|<span style="font-size: 8px">d37f8d4f17d5fa4192223a900af0ef29e97c9ac96b3bc820c2ad49162fec1584</span>|
|[martian-v4.0.4-linux-x86_64.tar.gz](https://github.com/martian-lang/martian/releases/download/v4.0.4/martian-v4.0.4-linux-x86_64.tar.gz)|Linux|x86-64|<span style="font-size: 8px">1083f0cbd4fae609f469b780cad76bddd2c1ef9e7e086312844b001d47aad5ae</span>|
|[martian-v3.2.5-linux-x86_64.tar.gz](https://github.com/martian-lang/martian/releases/download/v3.2.5/martian-v3.2.5-linux-x86_64.tar.gz)|Linux|x86-64|<span style="font-size: 8px">3b3fb295c120014be344a548670c68a8463e8fe338e84955728e74886c3b5762</span>|
|[martian-v3.2.5-linux-x86_64.tar.xz](https://github.com/martian-lang/martian/releases/download/v3.2.5/martian-v3.2.5-linux-x86_64.tar.xz)|Linux|x86-64|<span style="font-size: 8px">3ff65723d7c238c3f92680bf0c688d0506343f3415c89692802ebfb183b9d23f</span>|
|[martian-v3.1.0-linux-x86_64.tar.gz](https://github.com/martian-lang/martian/releases/download/v3.1.0/martian-v3.1.0-linux-x86_64.tar.gz)|Linux|x86-64|<span style="font-size: 8px">669d6722563dc23834162993fcb29d2471317a993b3ca30782fa879b8a6f94ff</span>|
|[martian-v3.0.0-linux-x86_64.tar.gz](https://github.com/martian-lang/martian/releases/download/v3.0.0/martian-v3.0.0-linux-x86_64.tar.gz)|Linux|x86-64|<span style="font-size: 8px">f0708a27113417d8d69ad61835930dba8a8fd827f11d4fb6ce5c6108e773a57e</span>|
|[martian-v2.3.2-linux-x86_64.tar.gz](https://github.com/martian-lang/martian/releases/download/v2.3.2/martian-v2.3.2-linux-x86_64.tar.gz)|Linux|x86-64|<span style="font-size: 8px">657eb6018a9371ac6af7267191945fd5ca590963d93d5d8096078f37d92b1107</span>|
|[Coming soon](https://github.com/martian-lang/martian/blob/master/.github/CONTRIBUTING.md)|macOS|x86-64|
|[Please contribute!](https://github.com/martian-lang/martian/blob/master/.github/CONTRIBUTING.md)|Windows|x86-64|

### System Requirements
* Currently, running pipelines requires a Linux system with kernel version 2.6.23 or later.
  - Martian 2.x has been confirmed working on Linux versions as far back as RHEL/CentOS 5.5 or Ubuntu 10.
  - Martian 3.0 and higher are supported on RHEL/CentOS 6 or Ubuntu 12 or higher.
  - For the time being, `mrp` only functions on Linux.
  - Ancillary tools such as `mro` and `mrstat` are expected to work on MacOS.
* Martian was designed for large bioinformatics pipelines.  One may run into issues on systems with less than 6GB of available memory.  Editing `jobmanagers/config.json` to reduce the default memory request for jobs may alleviate some of those issues.


## Building from Source

### Prerequisites
* [Go](https://golang.org) 1.14 or higher is required to build Martian.
* The Python adapter for wrapping stage code requires Python 2.7 or 3.6 or higher.
* To build the user interface, [Node](https://nodejs.org) 10 or higher is required, along with NPM.

### Building the source

#### Build with `make`

To build the Martian toolchain from source, clone the [Martian GitHub repository](https://github.com/martian-lang/martian), run `make all`, and the compiled binaries will be generated in `bin/`.

~~~~
$ git clone --recursive https://github.com/martian-lang/martian.git
$ cd martian
$ make all
$ ls bin
mrjob mro mrp mrstat
~~~~

To test that everything is working, `make longtests` runs a few simple test pipelines
and verifies that their output is correct, including tests that pipeline failures are
handled correctly.

#### Build with [`bazel`](https://bazel.build)

Clone the repository and run
```
bazel test //...
```

#### Build with go

You can use
~~~~
$ go get golang.org/x/tools/cmd/goyacc
$ go install golang.org/x/tools/cmd/goyacc
$ go get github.com/martian-lang/martian/cmd/...
$ go generate github.com/martian-lang/martian/...
$ go install github.com/martian-lang/martian/cmd/...
~~~~
However that will not you'll still need to run `make web` in the repository
directory in order to build the web UI.  Furthermore, the martian binaries
expect various data files to be located in specific relative locations.
Building with `make` is therefore recommended.


## Environment Setup

### Martian Executables

The Martian toolchain comprises five core executables:

|Executable|Role|Details|
|---|---|---|
|`mro check` |Compiler/Checker|Parses and validates Martian code
|`mro format`|Formatter       |Canonicalizes Martian code formatting and whitespace
|`mro graph` |Analysis        |Supports queries, e.g. tracing inputs/outputs, as well as formatting the call graph.
|`mro edit`  |Refactoring     |Rename or remove stages/pipelines/inputs/outputs.
|`mrp`       |Pipeline Runtime|Executes a Martian pipeline or stage.
|`mrjob`     |Stage wrapper   |Wraps user stage code, ensuring it obeys the contracts `mrp` expects.
|`mrstat`    |Progress query  |CLI tool for querying `mrp`'s API and issuing commands.

Make these executables available on your `PATH` and then confirm that you can run them. If you unpacked or cloned Martian into `/home/user/git/martian`, for example, then:

~~~~
$ export PATH=$PATH:/home/user/git/martian/bin
$ mro --version
v4.0.2
~~~~

### Martian Project Path – MROPATH

The code for a Martian pipeline project typically lives under a single directory. Set `MROPATH` to this directory to allow the Martian executables to find the project code without the need for absolute paths.

When developing multiple projects, switch between them by changing `MROPATH`.

To give you an idea of how a Martian project looks in practice, here's an example:

~~~~
martian_project/
    bin/
        hello_go
        hello_rust
    lib/
        go/
            vendor/github.com/martian-lang/martian
                src/martian/adapter/adapter.go
            src/
                hello_go.go
        rust/
            Cargo.lock
            Cargo.toml
            src/
                hello_rust.rs
    mro/
        _hello_stages.mro
        hello.mro
        stages/
            hello/
                hello_py/
                    __init__.py
~~~~

Stage code (or binaries) are searched for relative to
- the mro file defining the stage
- the `MROPATH`
- the `PATH`
