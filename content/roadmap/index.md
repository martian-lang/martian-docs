---
date: 2016-07-08T15:53:15-07:00
title: Development Roadmap
type: post
---

# Product development roadmap

All features here refer to notional plans, subject to change at any time.
They are provided here only to provide visibility into the current priorities
of the Martian development team.

## August 2017 - 2.3.0
* Initial GitHub publication
* Support building on OSX, and running non-pipeline tools.
* Always-on UI port with basic (unencrypted) authentication and a basic command
line tool for remote administration.
* Support for `perf record` profiling.
* Some tracking of stage vmem usage.
* Improved local-mode memory management.
* Redesigned adapter API.

## September 2017 - 2.4.0
* Improved resiliency to accidentally resetting stages which are still running.
* More options for remote administration over the UI port.
* (stretch) Improved web interface.

## Q1 2018 - 2.5.0
* A pipestance aggregater product, for visibility and management of multiple
concurrent `mrp` instances.
