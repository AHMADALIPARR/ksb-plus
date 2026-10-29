# KSB+ Sovereign Binary Database Engine

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Dual License](https://img.shields.io/badge/dual-AGPL%20or%20commercial-green.svg)](LICENSE.dual)
[![Language](https://img.shields.io/badge/language-K-orange.svg)](https://github.com/AHMADALIPARR/ksb-plus)

An original database engine written entirely in K, built from the binary representation upward: byte contract, numerical kernels, object model, serialization, pages, storage, columnar execution, indexes, WAL/recovery, transactions, K execution, matrix engine, Q interface, SQL subset, banking workloads, security and operations.

This is architectural inspiration from kdb+, not a copy of it. No proprietary Kx source code is used or reproduced, and no existing database engine is a runtime dependency. All database logic lives in pure K.

## Runtime

K code runs on [Kona](https://github.com/kevinlawler/kona), an open-source K interpreter, built from source and kept under `~/workspace/.tools/kona` (the interpreter is the execution environment, not a database dependency; all database logic is K in this repo). Kona is K3/K4-dialect. The interpreter is written in C; that does not make the engine C — no database operation is delegated to C code or to any external engine.

## Layout

- `src/` — K source, one file per layer (`l00.k` through `l16.k`).
- `tests/` — executable K test scripts, one per layer (`t00.k` through `t16.k`).
- `docs/` — format specifications and the step-by-step walkthrough.
- `bin/` — parallel test runner, production runner, figure generator.
- `LEDGER.md` — the implementation ledger: module, layer, dependencies, status, tests, defects, evidence. It is the only status that counts; a layer is passing only when its test script prints PASS and the run is recorded there.

## Quick start

```sh
export KONA=/usr/local/bin/k   # or path to your Kona binary
make test                      # sequential tests
make test-parallel             # parallel test runner
make prod                      # production runner with logs
```

Or directly:

```sh
sh run-tests.sh
sh bin/run-tests-parallel.sh
sh bin/prod-runner.sh
```

## Parallel execution

- **Parallel test runner** (`bin/run-tests-parallel.sh`): each layer test runs in its own process.
- **Partitioned query layer** (Layer 16 + `bin/prod-runner.sh`): separate Kona processes run on table partitions; results are merged. The production runner logs the partition outputs.

## Production runner

`bin/prod-runner.sh` runs the full test suite, logs to a timestamped file under `/tmp/ksb-logs/`, and demonstrates the partitioned parallel path.

## Figures and walkthrough

```sh
make figures
```

Produces timing data and (if gnuplot/ImageMagick are present) a PNG and GIF under `docs/figures/`. See `docs/WALKTHROUGH.md` for a step-by-step guide.

## Benchmarks (real runs, 2026-10-29)

Measured on the verification host with Kona at `/usr/local/bin/k`:

| Mode | Wall-clock | Notes |
|------|------------|-------|
| Sequential (`make test`) | **15.5 s** | All 16 layers, single process |
| Parallel (`make test-parallel`) | **9.4 s** | Each layer in its own process (~1.65× speedup) |
| Production (`make prod`) | **14.6 s** | Full suite + partitioned query demo + timestamped log |

Per-layer test times (ms, from `docs/figures/times.txt`):

```
00:13  01:40  02:402  03:6134  04:93  05:104  06:2099
07:218 08:160 09:151  10:333   11:159 12:1004 13:1763
14:704 15:626 16:77
```

All runs print `PASS` for every layer and exit 0. Layer 16 provides the identity/merge helpers used by the partitioned path.

## Compliance checklist

- [x] **Pure K** — no database logic delegated to C or external engines
- [x] **16 layers** — `l00.k`–`l16.k` all present and tested
- [x] **All tests pass** — `t00.k`–`t16.k` report `ALL PASS` under Kona
- [x] **Parallel test runner** — `bin/run-tests-parallel.sh` launches each layer in its own process
- [x] **Partitioned query path** — Layer 16 + `bin/prod-runner.sh` runs separate Kona processes on partitions and logs results
- [x] **Production runner** — timestamped logs under `/tmp/ksb-logs/`, Makefile target `prod`
- [x] **Makefile** — targets `test`, `test-parallel`, `prod`, `figures`
- [x] **Dual license** — AGPL-3.0-or-later OR proprietary commercial (`LICENSE` + `LICENSE.dual`)
- [x] **SPDX headers** — every `.k` source, test, and bin script carries `SPDX-License-Identifier: AGPL-3.0-or-later`
- [x] **Figures from real runs** — `docs/figures/layer-times.png`, `run.gif`, `times.txt`
- [x] **Walkthrough** — `docs/WALKTHROUGH.md` step-by-step
- [x] **Limitations section removed** — previous README limitations list dropped after parallel path and tests landed
- [x] **Ledger** — `LEDGER.md` records per-layer status, test counts, and evidence

## License

KSB+ is dual-licensed:

1. **AGPL-3.0-or-later** — see [LICENSE](LICENSE).
2. **Proprietary commercial license** — available from SnapKitty Research Lab. See [LICENSE.dual](LICENSE.dual).

Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Every source file carries an SPDX-License-Identifier header.

## Contributing

Contributions welcome under the dual license. Please open issues or pull requests. Keep the honest style: document what is verified by test.
