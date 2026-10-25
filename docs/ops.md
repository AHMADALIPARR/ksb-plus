# Layer 15: security + ops

Prefix `n`. Depends on Layer 9 (transactions) and Layer 12
(Q interface, via the Layer 13 SQL subset). All public
functions return `(1;value)` or `(0;reason)`. New reason:
`"denied"` (authorization refusal, distinct from a call
error: the query parsed fine and was refused).

## Password hashes: demonstration-grade only

`nUserNew` hashes passwords with Layer 1 `kHashStr`, an
Adler/mod-prime checksum of the password bytes. That is
DEMONSTRATION-GRADE ONLY: no salt, no key-derivation work
factor, fast to brute-force. It is NOT a secure password
hash and must never be presented as one. This layer's
contribution is access-control logic (users, roles,
permissions, audit, rate limits, authorized query
execution) plus ops. Production use requires a real KDF
in place of `kHashStr`; the auth logic itself does not
depend on which hash function fills the hash column.

## Users and authentication

`nUserNew[users;passes]` — users a symbol vector, passes a
general list of char lists, equal lengths, unique users.
A 0-row table is valid. A flat char list is not a list of
passwords (`"pw"` has type -3, not 0) and fails `"type"`.

`nAuth[usertab;user;pass]` — user a symbol atom, pass a
char list, else `(0;"type")`. Returns `(1;1)` for a hash
match, `(1;0)` for a wrong password, and `(1;0)` for an
unknown user (existence is not leaked through the result).

## Roles and permissions

`nRoleNew[users;roles]` — the user-role table
(`user`role). `nPermNew` is the empty permission table
(`role`obj`op). `nGrant` appends one permission row;
`nRevoke` removes every row matching all three of
role/obj/op (a no-match revoke returns the table
unchanged). Objects are arbitrary symbols: for authorized
queries the object is the TABLE NAME as it appears in the
query/env, not a column name.

`nCan[permtab;userroles;user;obj;op]` — `(1;1)` iff the
user holds some role with a matching (role;obj;op) row.
It chains Layer 6 `qFilter`: userroles by user, then
permissions by obj, then by op, then a membership test of
the surviving roles against the user's roles. Wrong table
shapes give `(0;"shape")`; bad atom types give
`(0;"type")`; no match gives `(1;0)`.

## Audit

`nAuditNew` is the empty audit table
(`seq`user`op`obj`allowed). `nAuditAppend` numbers each
row with the current row count as `seq`; `allowed` must
be int 0 or 1 (`"type"` for non-int, `"range"` otherwise).
`nAuditVerify` returns `(1;1)` iff the table has the audit
shape, the `seq` column equals `!#rows`, and every
`allowed` value is 0/1. A broken sequence or a bad
`allowed` value gives `(1;0)` — a finding, not a call
error. A non-table gives `(0;"type")`.

## Rate limiting

`nRateNew` is the empty bucket table
(`user`tokens`last). `nRateAllow[bk;user;ts;rate;cap]` is
a token bucket: a new user starts at `cap` tokens at `ts`
and spends one immediately; an existing user refills to
`min(cap; tokens + (ts-last)*rate)` with checked multiply
and add (overflow propagates), then spends one if the
refill is >= 1. Returns `(1;(allowed;newbuckets))`.
Backward time (`ts < last`) gives `(0;"range")`; `cap`
must be >= 1 and `rate`, `ts` >= 0, else `(0;"range")`.

## Authorized query execution

Authorization runs BEFORE execution. `nAuthQ` tokenizes
and parses with `uTok`/`uParseQ`, takes the table name
(`parsed[1]`, for both `select` and `exec` forms), checks
`` `read `` permission on it, and returns `(0;"denied")`
without executing when denied; otherwise it runs
`uQ[env;query]`. `nAuthSQL` does the same with
`uTok`/`zParseSQL`: it checks the FROM table (`st[1]`)
and, when a JOIN table is present (`(4:st[4])=4`), the
JOIN table (`st[4]`); any denial returns `(0;"denied")`
before `zSQL` runs. Parse errors propagate unchanged.

## Ops

- `nBackup[st;wal;spath;wpath]` — `sSave` then `wSave`,
  returning `(1;(spath;wpath))`. The store file is written
  first, so a failed WAL save leaves the store file in
  place (reported by the propagated error).
- `nRestore[spath;wpath]` — `sLoad` then `wLoad`,
  returning `(1;(store;wal;clean))`.
- `nCheckpoint[st;wal]` — passthrough to Layer 8
  `wCheckpoint`, returning `(1;(newstore;freshwal))`.
- `nVerifyStore[st]` — `(1;(npages;nrecs;valid))` from
  `#st`, `sRecs`, and `sValid`; non-stores give
  `(0;"type")`.
- `nQuota[tab;maxrows]` — row count from the first column
  of a table object; `(1;1)` at or under the quota,
  `(0;"limit")` over it.

## Gate F evidence (enterprise readiness)

Gate F needs l14-l15 passing PLUS concurrency,
corruption, resource-limit, and benchmark evidence. All
four are present by execution:

- Concurrency: Layer 9 interleaved-transaction tests
  plus Layer 14 conflict/retry tests
  (first-committer-wins at whole-store version
  granularity; the loser retries on the new version).
  Boundary: Kona is single-threaded, so "concurrent"
  means interleaved begins/commits in one session —
  there is no lock manager, and none is pretended.
- Corruption: Layer 8 torn/corrupt WAL tests plus
  Layer 15 audit-tamper tests (broken sequence and bad
  `allowed` both verify as `(1;0)`).
- Resource-limit: Layer 2 count limits plus Layer 15
  quota tests (under / over / exact / empty).
- Benchmark (executed 2026-10-25, shell-timed, in /tmp,
  NOT a test assertion): a Kona workload of a 2000-row
  tick table (OHLC over 20 buckets x 4 symbols = 80 rows,
  VWAP 23.32667), 20 sequential transactional transfers
  (final version 20), and 100 SQL queries over a 100-row
  table env (final query returns 49 rows) ran in real
  17.676s (user 13.635s, sys 0.234s). The full
  `./run-tests.sh` suite (t00-t15) ran in real 28.425s
  (user 21.292s, sys 1.356s), all PASS.

Durability boundary (unchanged from Layers 5/8): Layer 5
`1:` rewrites are NOT msynced, so no durable-commit claim
is made from Layer 5; Layer 8 WAL appends via `5:` are
msynced, while full rewrites via `1:` are not synced.

## Evidence

`tests/t15.k`: 73/73 checks, ALL PASS, confirmed by
`./run-tests.sh` (PASS for t00-t15). Coverage: user
construction (incl. empty, dup, length, bad types, flat
password list), auth (good, bad, unknown, bad types,
non-table), role construction, grant/revoke/can matrix
(multiple roles, multiple objects, unknown user, bad
types, no-match revoke), audit append/verify/tamper
(sequence break, bad allowed, wrong names, non-table,
bad allowed value/type), rate limit (new user, drain,
deny, refill, cap, backward time, second user, bad
types/ranges), authorized Q and SQL (allow/deny, exec,
bad query, join allow/deny on the second table), ops
(backup/restore round-trip, restore+replay rebuild,
checkpoint rotation, verify-store report, quota
under/over/zero/empty/bad types).
