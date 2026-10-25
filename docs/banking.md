# Layer 14: banking + time-series workloads

Prefix `y`. Depends on Layer 9 (transactions) and Layer 12
(Q interface, via the Layer 13 SQL subset for account queries).
All public functions return `(1;value)` or `(0;reason)`.
Tables are Layer 2 table objects (unwrapped with `[1]`).

## Banking

Money is integer cents. Reason strings reuse the codebase set
(`"type"`, `"shape"`, `"key"`, `"range"`, `"valid"`, `"funds"`,
`"empty"`, `"status"`, `"conflict"`, `"overflow"`, `"bounds"`,
`"op"`); `"funds"` is new, for insufficient balance.

- `yAcctNew[ids;bals]` — int vectors, equal lengths, unique
  ids, non-negative balances. A 0-row table is valid.
- `yBal`, `yBalIx`, `ySetBal` — balance lookup by account or
  row index; `ySetBal` rebuilds the table (Kona indexed
  assignment copies, per the Layer 5 note).
- `yDeposit`, `yWithdraw` — amount must be a non-negative int
  atom. New balances go through Layer 1 checked arithmetic
  (`kChkAdd`/`kChkSub`), so an overflow is reported, never
  wrapped. Withdrawing more than the balance reports
  `(0;"funds")`; withdrawing exactly the balance is allowed.
- `yTransfer` — amount non-negative; self-transfer reports
  `(0;"shape")`; unknown from/to reports `(0;"key")`;
  insufficient funds reports `(0;"funds")`. Both new
  balances are computed (debit via `kChkSub`, credit via
  `kChkAdd`) BEFORE the table is rebuilt, so a credit
  overflow cannot leave a half-applied debit.
- `yTotal` — checked int sum of `bal` (empty sums to 0).
- `yConserved[a;b]` — `(1;1)` iff both tables total the same.

## Journal

`yJNew` is the empty journal table
(`jid`from`to`amt, all int columns). `yJAppend` validates
the table shape, int-atom fields, and non-negative amount.
`yJReplay` folds `yTransfer` over the rows in order; the
first failure propagates. `yJCheck[j;t0;t1]` replays `j` onto
`t0` and compares with `t1` by `~`: a tampered amount gives
`(1;0)` (a finding, not a call error), while a replay error
(e.g. unknown account) propagates as `(0;reason)`.

## Transactions over the store

`yTxBuild[st;mn;ver;txnid;from;to;amt]` builds a transfer
transaction WITHOUT committing, so one built transaction can
be committed, conflicted, or aborted by the test. The
transaction is built exactly like Layer 9 builds one (same
tuple shape `(id;status;ver;workstore;entries)`, same `` `put ``
entry format), except chunk addresses are tracked via `sPut`,
because `tPut` does not return them. The commit itself still
goes through `tCommit`, so WAL entries, the commit marker,
and the version check are Layer 9 semantics, not a copy.

`yTxTransfer` is build-then-commit in one call and returns
`(1;(newstore;newmanifest;newver;newwal))`. Conflict is
first-committer-wins at whole-store version granularity:
two transactions built at the same version, the second
commits with `(0;"conflict")` after the first, and the
loser retries by rebuilding on the new version. An aborted
transaction writes only its marker; replay drops it.

## Time-series

`yTickNew[ts;sym;px;vol]` — ts int, sym symbol, px float,
vol int, equal lengths; ts >= 0, vol >= 0, and every px
finite-or-zero (Layer 1 `kFClass` in `(3;4)`). NaN, +Inf,
and -Inf prices are rejected with `(0;"valid")`.

`yBuckets[ts;width]` — floor division by `width` (width must
be a positive int), so bucket boundaries are exact.

`yOHLC[tab;width]` — columns
`` `sym`bucket`open`high`low`close`vol ``. Rows are grouped
by (sym, bucket); open/close are the first/last prices in
TIME order (grade on ts), high/low are max/min price, vol
is the checked int sum. Row order follows FIRST OCCURRENCE
of each (sym, bucket) pair in the input (Kona `?` preserves
order); it is not sorted order. A 0-row tick table gives a
0-row OHLC table with typed empty columns.

`yVwap[tab]` — `(sum px*vol) / (sum vol)` in float.
Empty ticks give `(0;"empty")`, zero total volume gives
`(0;"range")`, non-finite px gives `(0;"valid")`.

`yRollMean[col;n]` — float column, n >= 1. Element i is the
mean of the trailing window: from index 0 while i < n, then
the last n elements. Empty input gives an empty float list.

## Persistence

Accounts and WALs round-trip through Layer 5 `sSave`/`sLoad`
and Layer 8 `wSave`/`wLoad` (symbol paths ending in `.K`,
git-ignored as `y14store.K`, `y14store0.K`, `y14wal.K`,
`y14torn.K`). Crash recovery is: save the base store plus
the WAL, load both, `tReplay` onto the base, read through
the new manifest — equal to the post-transfer table. A WAL
with its last 3 bytes dropped loads with clean flag 0.

## Honest limits

Kona is single-threaded, so "concurrent" here means
interleaved begins/commits in one session — there is no
lock manager, and none is pretended (Layer 9 design note).
Layer 5 `1:` rewrites are NOT msynced, so no durable-commit
claim is made from Layer 5; Layer 8 WAL appends via `5:`
are msynced per the Layer 8 design note, while full
rewrites via `1:` are not synced.

## Evidence

`tests/t14.k`: 81/81 checks, ALL PASS, confirmed by
`./run-tests.sh` (PASS for t00-t14). Coverage: account
construction (incl. empty, bad types, length mismatch, dup
ids, negative balance), balance hit/miss/bad type, deposit
(incl. IMAX overflow), withdraw (incl. exact balance and
funds), transfer (incl. conservation, unknown sides, self,
negative, funds, credit overflow with original unchanged),
totals, journal append/replay/check (incl. tamper and
unknown-account), store write/read, transactional commit
(version bump, WAL count, commit marker, replay rebuild),
conflict plus retry on the new version, abort plus replay,
SQL over accounts (where + order, sum), tick validation
(incl. NaN price), OHLC (two symbols, two buckets, single
tick, empty, bad width, unsorted input), VWAP (hand-computed
12.1 and 12.5, zero volume, empty), rolling mean (n=2, n=1,
n>length, bad n, bad type, empty), and persistence
(save/load round-trip, replay rebuild, torn WAL clean 0).
