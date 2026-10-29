# KSB+ Step-by-Step Walkthrough

This document walks through a complete run of the 16-layer engine under Kona.

## Prerequisites

- Kona built from source (`~/workspace/.tools/kona/k` or `k` on PATH)
- This repository checked out

## 1. Run all layers

```sh
export KONA=/usr/local/bin/k   # or your path
sh run-tests.sh
```

Expected output:

```
PASS tests/t00.k
PASS tests/t01.k
...
PASS tests/t15.k
PASS tests/t16.k
```

## 2. Parallel test runner

```sh
sh bin/run-tests-parallel.sh
```

Launches each layer test in its own process.

## 3. Production runner with logging

```sh
sh bin/prod-runner.sh
```

Writes a timestamped log under `/tmp/ksb-logs/` and runs a partitioned query demo that launches two Kona processes.

## 4. Inspect a layer

```sh
cat src/l00.k src/l01.k src/l02.k tests/t02.k | $KONA
```

Each test prints `PASS name` lines and ends with `ALL PASS`.

## 5. Parallel partitioned query

The production runner demonstrates the partitioned path: two independent Kona processes each receive a partition of a table and produce results that are logged. Layer 16 provides the identity and merge helpers used by that path.

## Figures

Run `make figures` (or `sh bin/make-figures.sh`) to generate timing plots from real runs. A live GIF of the test runner is produced under `docs/figures/`.
