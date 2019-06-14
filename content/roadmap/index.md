---
date: 2016-07-08T15:53:15-07:00
title: Development Roadmap
type: post
---

# Martian Development Roadmap

All features here refer to notional plans. They are provided only to provide 
visibility into the current priorities of the Martian development team,
and are subject to change at any time.

## August 2017
* Initial GitHub publication

## Q3 2017 - 2.3.0
* Always-on UI port with basic (unencrypted) authentication and a basic command
line tool for remote administration. (done)
* Support for `perf record` profiling. (done)
* Some tracking of stage vmem usage. (done)
* Improved local-mode memory management. (done)
* Redesigned adapter API. (done)
* Improved resiliency to accidentally resetting stages which are still running. (done)
* More options for remote administration over the UI port. (done)
* Support building on macOS, and running non-pipeline tools.

## Q4 2017 - 3.0.0
* Stronger enforcement of stage and pipeline input and output types. (done)
* Declare chunk outputs which are not stage outputs. (done)
* Override default thread or memory requests from stage MRO. (done)
* Conditionally disable sub-pipelines (e.g. to support autodetection of which analyses to run). (done)

## Q2 2019 - 3.2.0
* Support for virtual address space reservations for jobs. (done)

## Q3 2019
* Support for structured data types in mro.
* Support for strongly-typed map data.
* Better control flows for array inputs.

## 2020
* Management tool for launching and running many pipelines concurrently.
