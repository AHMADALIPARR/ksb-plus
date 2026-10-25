# KSB+ implementation ledger

Status values: planned, in progress, passing, failed, blocked.
A layer is passing only when its test script runs under Kona and
prints PASS for every check. Blocked is not passing.

| Module | Layer | Dependencies | Implementation | Tests | Status | Defects | Evidence |
|---|---|---|---|---|---|---|---|
| runtime | - | - | Kona (open K interpreter, built from source, `~/workspace/.tools/kona/k`) | smoke: arithmetic, vectors, strings, scans, recursion, indexed assignment | passing | Kona is occasionally flaky (see l00 evidence note); always run under timeout | 2026-10-24: `1+2` -> 3, `+/1 2 3` -> 6, vector add, strings, `+\1 2 3` -> 1 3 6, factorial recursion -> 120, clean EOF exit on clean scripts |
| l00 | 0 binary contract | runtime | src/l00.k | tests/t00.k | passing | none in KSB+ logic. Kona dialect traps found and fixed during this layer are recorded in docs/kona-notes.md (no <=/>=, spaced drop, single-line bracketed expressions, no \l, parenthesized counts) | 2026-10-24: tests/t00.k 41/41 checks, ALL PASS, exit 0, confirmed by run-tests.sh (PASS) and multiple direct runs. Coverage: byte validation, u8/u16/u32/i8/i16/i32/u64-pair round trips plus known vectors (u32 16909060 -> 1 2 3 4), Adler-style checksum known value (65 66 67 -> 26017991), length-prefixed strings, framed values with short/magic/version/length/checksum rejection, strict UTF-8 (valid 1-4 byte, overlong, surrogate, truncated, bad continuation, lone continuation, >U+10FFFF). Correction note: run-tests.sh initially failed twice because of a runner bug (it built the source path as src/00.k instead of src/l00.k, so the test ran without its source and errored on undefined names); fixed 2026-10-24 and the runner now passes. Separately, one earlier direct run of these identical files showed intermittent type/rank/value errors plus garbage bytes and a hang; the same files passed on rerun. That single direct-run incident is still attributed to Kona interpreter instability, not KSB+ logic, and recorded here rather than hidden. |
| l01 | 1 numerical kernels | l00 | src/l01.k | tests/t01.k | passing | none in KSB+ logic. Kona dialect traps found and fixed during this layer are recorded in docs/kona-notes.md (no assignment inside :[ branches, right-to-left comparison parenthesization, variable juxtaposition is application not a list, atom guards before drop/fold, over-fold enlist-prepend, prompt flood as a symptom of errors). Kona display quirk: IMAX prints 0I, IMIN prints 0N, but both behave as ordinary two's complement values; raw Kona int div-by-zero returns IMAX and raw +,-,* wrap, so all public arithmetic is checked. Kona float NaN compares less than everything including -Inf, so NaN is detected by x < -Inf; -0.0 collapses to 0.0. | 2026-10-24: tests/t01.k 152/152 checks, ALL PASS, exit 0, clean prompt-free output (3.5KB). Coverage: checked add/sub/mul incl. IMAX/IMIN boundaries and the 3037000499/3037000500 sqrt boundary, trunc/floor div and rem/mod incl. negatives and IMIN/-1, comparisons, booleans, shifts/masks via div/mod, bitwise AND/OR/XOR/NOT on 0..IMAX, i64 big-endian byte round trips incl. IMIN/IMAX, fixed-point trunc and half-away-from-zero, float classification (NaN/+Inf/-Inf/zero/finite), checked over-fold reductions incl. overflow propagation and atom rejection, Adler/mod-prime hashing with known values. Earlier failing runs were fixed by code/test corrections, not reruns: 4-arg :[ misparse, `2*ar[1]<s` precedence, `IMX 1` application parse, atom drop infinite recursion. |
| l02 | 2 object model | l01 | src/l02.k | tests/t02.k | passing | No custom physical-memory allocator: Kona manages all memory, so limits here are counts (lengths, columns, names, payloads, depth), enforced by validation, not by allocation control; documented in code. Depth is enforced by oIsValid, not by constructors (only a top-down walk knows final depth). A 2-symbol list whose first element is a kind symbol is ambiguous (sym object vs name list); callers must use oKind/oIsValid for objects and oIsSymList for name lists, never both on the same value. Kona collapse facts baked into the design: homogeneous pairs/triples collapse to typed lists (kind codes are symbols so objects stay general; all-int time/ref payloads accepted as int lists), and 1-char quoted literals are char atoms, not char lists. | 2026-10-24: tests/t02.k 162/162 checks, ALL PASS, exit 0, clean output (4.4KB). Coverage: all 16 kind codes plus malformed inputs, every constructor success and failure mode (type/limit/shape/key/valid/range/empty/op/overflow), full-tree validity incl. depth 32 ok / 33 rejected, length/get/dict-get/column/row/matrix/field/plan/ref/txn/time/symbol/string accessors incl. bounds/missing/wrong-kind, copy independence at pair and list level, append/slice/reverse/map-int transforms, and boundaries: 1M/1M+1 vector length, 1M/1M+1 string length, 128/129-char symbols, 256/257 table columns and schema fields, 67108864/67108865 ref length. Earlier failing runs were fixed by code/test corrections, not reruns: symbol kind codes (int kinds collapsed), oIsObjPair for sym objects, list guards before ? on atoms, (#v)<b parenthesization, 2-char string payloads in tests. |
| l03 | 3 value format | l02 | src/l03.k | tests/t03.k | planned | - | - |
| l04 | 4 pages | l03 | src/l04.k | tests/t04.k | planned | - | - |
| l05 | 5 storage manager | l04 | src/l05.k | tests/t05.k | planned | - | - |
| l06 | 6 columnar engine | l05 | src/l06.k | tests/t06.k | planned | - | - |
| l07 | 7 indexes | l06 | src/l07.k | tests/t07.k | planned | - | - |
| l08 | 8 WAL/recovery | l05 | src/l08.k | tests/t08.k | planned | - | - |
| l09 | 9 transactions | l08 | src/l09.k | tests/t09.k | planned | - | - |
| l10 | 10 K execution | l06 | src/l10.k | tests/t10.k | planned | - | - |
| l11 | 11 matrix engine | l10 | src/l11.k | tests/t11.k | planned | - | - |
| l12 | 12 Q interface | l10 | src/l12.k | tests/t12.k | planned | - | - |
| l13 | 13 SQL subset | l12 | src/l13.k | tests/t13.k | planned | - | - |
| l14 | 14 banking workloads | l09,l12 | src/l14.k | tests/t14.k | planned | - | - |
| l15 | 15 security/ops | l09,l12 | src/l15.k | tests/t15.k | planned | - | - |

## Acceptance gates

- Gate A binary correctness: needs l00-l03 passing.
- Gate B persistence: needs l04-l05 passing.
- Gate C query correctness: needs l06,l10,l12,l13 passing.
- Gate D transaction integrity: needs l08-l09 passing.
- Gate E matrix correctness: needs l11 passing.
- Gate F enterprise readiness: needs l14-l15 passing plus concurrency,
  corruption, resource-limit, and benchmark evidence.

No gate is passing yet. No gate is claimed passing until its tests pass.
