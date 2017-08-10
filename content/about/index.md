---
date: 2017-05-21T17:53:15-07:00
title: About
type: post
---

Martian was created by at [10x Genomics](https://www.10xgenomics.com/), where it serves as a core part of the software engineering toolchain. As a developer framework, Martian helps to make tractable the building and maintenance of over 30 pipelines by 25+ developers. As a runtime, Martian has cumulatively executed, just internally at 10x Genomics, over 91 million jobs consuming 1.3 core-millennia of CPU time. Martian has executed many millions more core-hours at customer sites, and is one of the most heavily exercised computational pipeline frameworks deployed in the field.

### History

Martian came to life in April of 2014. It was built to address a number of looming challenges in complexity management, and satisfy a specific set of design objectives which were not met by any framework that existed at the time.

Martian was originally prototyped in [Javascript / Node.js](https://nodejs.org/) with [Jison](http://jison.org/) as the parser generator. After Martian proved successful in production use, a search was undertaken for a modern, statically compiled language on which to pursue more ambitious, long-term development. In August of 2014, mounting social signal led to the acceptance of [Rob Pike's proposal](https://www.youtube.com/watch?v=rKnDgT73v8s). A suitable candidate found, Martian was then ported to [Go](https://golang.org/), with [goyacc](https://godoc.org/golang.org/x/tools/cmd/goyacc) replacing Jison.

### The Name

Martian was originally named Mario. This was because, many presumed, pipelines and plumbing. However, being an inveterate contrarian, the [creator](https://twitter.com/ablewhiskey) vehemently insisted that Mario bore no relation whatever to [Super Mario Bros.](https://en.wikipedia.org/wiki/Super_Mario_Bros.), and was in fact named after [Mario Lopez](https://en.wikipedia.org/wiki/Mario_Lopez) because, reasons.

When this etymological yarn proved too challenging to explain to those unfamiliar with [Saturday Morning TV](https://en.wikipedia.org/wiki/Saved_by_the_Bell), it was grudgingly decided to find a new name that would appeal more to culturally illiterate audiences. The only constraint imposed was that the new name should conserve the first three letters of the old, so as to minimize disruption to the naming harmony of the extant ecosystem of Mario-based repositories, tools, and applications.

Following an exhaustive ```grep ^[Mm]ar /usr/share/dict/words```, the name Martian was selected, after the concept of the [Martian scientist](https://en.wikipedia.org/wiki/Martian_scientist) which, like Martian, acts as an agnostic observer of complex goings-on. The eschewal of a definite article is intentional, aiming to distinguish Martian from The Martian. It should be noted that the naming of Martian was subsequent to [the book](https://en.wikipedia.org/wiki/The_Martian_(Weir_novel)) but prior to the announcement of the [the movie](https://en.wikipedia.org/wiki/The_Martian_(film)).
