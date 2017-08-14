---
date: 2016-11-01T17:53:15-07:00
title: Getting Started
type: post
---

## Installing Martian

Official binary distributions of the Martian toolchain are available for Linux, macOS and Windows:

|Download|OS|Arch|SHA256|
|---|---|---|---|
|[martian-2.2.0-linux-amd64.tar.gz](-)|Linux|x86-64|
|[martian-2.2.0-darwin-amd64.tar.gz](-)|macOS|x86-64|
|Coming soon|Windows|x86-64|

## Building from Source

To build the Martian toolchain from source, clone the [Martian GitHub repository](https://github.com/martian-lang/martian), run `make all`, and the compiled binaries will be generated in `bin/`.

~~~~
$ git clone --recursive https://github.com/martian-lang/martian.git
$ cd martian
$ make all
$ ls bin
mrc         mrp         mrf         mrs
~~~~

## Environment Setup

### Martian Executables

The Martian toolchain comprises four core executables:

|Executable|Role|Details|
|---|---|---|
|`mrc`|Compiler/Checker|Parses and validates Martian code
|`mrf`|Formatter|Canonicalizes Martian code formatting and whitespace
|`mrp`|Pipeline Runtime|Executes a Martian pipeline
|`mrs`|Stage Runtime|Executes an individual Martian pipeline stage

Make these executables available on your `PATH` and then confirm that you can run them. If you unpacked or cloned Martian into `/home/user/git/martian`, for example, then:

~~~~
$ export PATH=$PATH:/home/user/git/martian/bin
$ mrc --version
2.2.0
~~~~

### Martian Project Path – MROPATH

The code for a Martian pipeline project typically lives under a single directory. Set `MROPATH` to this directory to allow the Martian executables to find the project code without the need for absolute paths.

When developing multiple projects, switch between them by changing `MROPATH`.

To give you an idea of how a Martian project looks in practice, here's an example:

~~~~
martian_project/
    lib/
        go/
            bin/
                hello_go
            src/
                hello_go.go
        rust/
            Cargo.lock
            Cargo.toml
            bin/
                hello_rust
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
