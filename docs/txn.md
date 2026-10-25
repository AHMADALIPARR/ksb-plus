# Transactions and concurrency (Layer 9)

A transaction is a value `(id;status;snapVer;work;entries)`:
`id` is an int >= 0, `status` is 0 open, 1 committed, 2 aborted,
`snapVer` is the store version the transaction began on, `work`
is the transaction's private working store, `entries` are its
buffered `` `put `` records as `(op;txn;data)` triples (no seq;
seqs are assigned when the entries reach the global WAL at
commit).

## Concurrency model

Single-writer optimistic concurrency, no locks. The shared store
carries a version counter, bumped exactly on commit. A
transaction reads from its snapshot (the store as of begin) plus
its own buffered writes, so reads never block and never see
another transaction's uncommitted work. At commit, the
transaction's snapshot version must still equal the shared
version; otherwise the commit fails with "conflict" and the
transaction's work is discarded -- first committer wins, at
whole-store version granularity. That granularity is coarse on
purpose: any concurrent commit conflicts, even one touching
different records. It is serializable and simple to reason
about, and the loser retries by beginning again on the new
version. Kona is single-threaded, so "concurrent" here means
interleaved begins and commits in one session, not threads;
there is no lock manager to build, and none is pretended.

## WAL interaction and atomicity

A transaction's puts reach the global WAL only at commit
(buffered entries plus a `` `commit `` marker, in that order).
An abort appends only an `` `abort `` marker: the aborted puts
never reached the shared store, so there is nothing to undo. A
crashed transaction -- puts in the log with no commit marker --
is likewise dropped by replay. `tReplay` is therefore the
atomicity proof: it applies non-transactional puts always,
transactional puts only for txn ids that have a `` `commit ``
marker anywhere in the log (two passes, so marker position does
not matter), and drops everything else.

## Caller contract

Thread `(store;version;wal)` together. A version match is the
guard that the store is unchanged since begin; mixing a store
from one lineage with a version from another breaks the guard
and is a caller error, not a tagged failure. A committed or
aborted transaction value is dead: puts and commits on it fail
with "status"; only abort on an open transaction succeeds, and
aborting a dead one fails too.

## API (src/l09.k)

- `tIsTxn` (raw 0/1) -- transaction structure validation.
  Entries are `` `put `` triples owned by this txn, each
  carrying a valid frame.
- `tBegin[store;ver;id]` -- snapshot the store and version.
- `tId`, `tStatus`, `tVer` -- validated accessors.
- `tPut[txn;frame]` -- buffer a put: apply it to the private
  work store (so reads see the transaction's own writes) and
  record the entry. The shared store is untouched until commit.
- `tGet[txn;page;slot]`, `tRecs[txn]` -- reads against the
  work store (snapshot plus own writes).
- `tCommit[txn;store;ver;wal]` --
  (1;(txn;store;version;wal)): the committed transaction value
  (status 1), the new shared store (the transaction's work
  store), the bumped version, and the WAL with the
  transaction's puts plus its commit marker appended. Failures:
  "shape" (bad txn or WAL), "type" (bad store or version),
  "status" (dead txn), "conflict" (version moved), "valid"
  (work store invalid).
- `tAbort[txn;wal]` -- (1;(txn;wal)): the aborted transaction
  value (status 2) and the WAL with only the abort marker
  appended.
- `tReplay[store;wal]` -- transaction-aware replay into a
  store (see above).

## Test scratch files

Layer 9 tests write `w9test.K` in the repo directory (relative
paths, so the current directory must be the repo dir, as under
`run-tests.sh`). It is git-ignored, and saves rewrite it rather
than appending, so reruns are clean.
