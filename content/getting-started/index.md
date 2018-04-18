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
|[martian-v3.0.0-rc3-linux-x86_64.tar.gz](https://github.com/martian-lang/martian/releases/download/v3.0.0-rc3/martian-v3.0.0-rc3-linux-x86_64.tar.gz)|Linux|x86-64|<span style="font-size: 8px">ce841b5df88735b876d5c1315011d928c52f6a298caf89b214bc8e9c982f35b3</span>|
|[martian-v2.3.2-linux-x86_64.tar.gz](https://github.com/martian-lang/martian/releases/download/v2.3.2/martian-v2.3.2-linux-x86_64.tar.gz)|Linux|x86-64|<span style="font-size: 8px">657eb6018a9371ac6af7267191945fd5ca590963d93d5d8096078f37d92b1107</span>|
|[Coming soon](https://github.com/martian-lang/martian/blob/master/.github/CONTRIBUTING.md)|macOS|x86-64|
|[Please contribute!](https://github.com/martian-lang/martian/blob/master/.github/CONTRIBUTING.md)|Windows|x86-64|

### System Requirements
* Currently, running pipelines requires a Linux system with kernel version 2.6.23 or later.
  - Linux versions as far back as RHEL/CentOS 5.5 or Ubuntu 10 have been confirmed working.
  - Future updates may drop support for anything older than RHEL/CentOS 6 or Ubuntu 12.
  - For the time being, `mrp` only functions on Linux.
  - Ancillary tools such as `mrc`, `mrstat`, and `mrf` are expected to work on MacOS.
* Martian was designed for large bioinformatics pipelines.  One may run into issues on systems with less than 6GB of available memory.  Editing `jobmanagers/config.json` to reduce the default memory request for jobs may alleviate some of those issues.


## Building from Source

### Prerequisites
* [Go](https://golang.org) 1.9 or higher is required to build Martian.
* The Python adapter for wrapping stage code requires Python 2.7.
* To build the user interface, [Node](https://nodejs.org) 6 or higher is required, along with NPM.

### Building the source

To build the Martian toolchain from source, clone the [Martian GitHub repository](https://github.com/martian-lang/martian), run `make all`, and the compiled binaries will be generated in `bin/`.

~~~~
$ git clone --recursive https://github.com/martian-lang/martian.git
$ cd martian
$ make all
$ ls bin
mrc  mrf  mrg  mrjob  mrp  mrs  mrstat
~~~~

To test that everything is working, `make longtests` runs a few simple test pipelines
and verifies that their output is correct, including test that pipeline failures are
handled correctly.

## Environment Setup

### Martian Executables

The Martian toolchain comprises five core executables:

|Executable|Role|Details|
|---|---|---|
|`mrc`|Compiler/Checker|Parses and validates Martian code
|`mrf`|Formatter|Canonicalizes Martian code formatting and whitespace
|`mrp`|Pipeline Runtime|Executes a Martian pipeline
|`mrs`|Stage Runtime|Executes an individual Martian pipeline stage
|`mrjob`|Stage wrapper|Wraps user stage code, ensuring it obeys the contracts `mrp` or `mrs` expect.

Make these executables available on your `PATH` and then confirm that you can run them. If you unpacked or cloned Martian into `/home/user/git/martian`, for example, then:

~~~~
$ export PATH=$PATH:/home/user/git/martian/bin
$ mrc --version
v2.3.0-rc0.1
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
