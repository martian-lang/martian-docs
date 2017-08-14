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

## Parallelization
[ WIP ]
## Job Management

### Local Mode

### Cluster Mode

### Templates

### Throttling

## Preflight Checks

## Volatile Data Removal

`volatile` keyword.

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
