# KSB+ Sovereign Binary Database Engine

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![GitHub stars](https://img.shields.io/github/stars/AHMADALIPARR/ksb-plus?style=social)](https://github.com/AHMADALIPARR/ksb-plus/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/AHMADALIPARR/ksb-plus?style=social)](https://github.com/AHMADALIPARR/ksb-plus/network/members)
[![Language](https://img.shields.io/badge/language-K-orange.svg)](https://github.com/AHMADALIPARR/ksb-plus)

An original database engine written entirely in K, built from the binary representation upward: byte contract, numerical kernels, object model, serialization, pages, storage, columnar execution, indexes, WAL/recovery, transactions, K execution, matrix engine, Q interface, SQL subset, banking workloads, security and operations.

This is architectural inspiration from kdb+, not a copy of it. No proprietary Kx source code is used or reproduced, and no existing database engine is a runtime dependency. All database logic lives in pure K.

## Runtime

K code runs on [Kona](https://github.com/kevinlawler/kona), an open-source K interpreter, built from source and kept under `~/workspace/.tools/kona` (the interpreter is the execution environment, not a database dependency; all database logic is K in this repo). Kona is K3/K4-dialect. The interpreter is written in C; that does not make the engine C — no database operation is delegated to C code or to any external engine.

## Layout

- `src/` — K source, one file per layer (`l00.k`, `l01.k`, ...).
- `tests/` — executable K test scripts, one per layer (`t00.k`, ...).
- `docs/` — format specifications (binary contract, page format, storage format, SQL subset, transaction model, and more).
- `LEDGER.md` — the implementation ledger: module, layer, dependencies, status, tests, defects, evidence. It is the only status that counts; a layer is passing only when its test script prints PASS and the run is recorded there.

## Run the tests

```sh
sh run-tests.sh
```

Each test script is fed to Kona on stdin and prints one PASS/FAIL line per check plus a summary. A layer with a failing or blocked test is not passing.

## Limitations (stated, not hidden)

- Durability boundaries depend on what Kona's file verbs actually guarantee; see `docs/storage.md` and the ledger. A successful write call is not automatically a durable write, and no claim of durable commit is made until the flush behavior is verified by test.
- No claim of ACID compliance, production readiness, SIMD, GPU, or parallel execution is made unless the corresponding tests pass.
- Where Kona cannot express a required low-level primitive (physical memory control, machine instructions, OS sync semantics), the limitation is documented in the ledger and the docs, never papered over with a high-level expression pretending to be that primitive.

## License

KSB+ is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See the [LICENSE](LICENSE) file for the full text.

Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

## Contributing

Contributions welcome under the AGPL-3.0. Please open issues or pull requests. Keep the honest limitations style: document what is verified by test, and what is not.
