# WAL and recovery (Layer 8)

A WAL (write-ahead log) is the redo log for a Layer 5 store: a
sequence of entries, each a Layer 0 frame, so a store lost to a
crash can be rebuilt by replaying the log. Entries are
`(seq;op;txn;data)`: `seq` is a u32 sequence number starting at
0 and increasing by exactly 1 per entry, `op` is a symbol
(`` `put ``, `` `commit ``, `` `abort ``, `` `ckpt ``), `txn` is
the owning transaction id (-1 for a non-transactional entry;
Layer 9 interprets txn ids), `data` is a store frame for `` `put ``
and empty for markers. A WAL value is `(nextSeq;entries)`.

## File format

A WAL file holds ONE FLAT BYTE LIST: the entry frames
concatenated in seq order, with no header of its own. An entry
frame has type byte 87 and payload

```
u32be seq, 1 op-code byte, i32be txn, data bytes
```

Op codes: put 1, commit 2, abort 3, ckpt 4.

## Recovery semantics

`wRecover` scans frames in order and returns the longest valid
prefix plus a clean flag. A frame that fails to parse (short,
length, checksum, magic, version) ends the scan as a TORN TAIL:
the prefix is returned with clean 0, because a torn write can
damage any part of the final frame, and once a frame fails to
parse nothing after it can even be located. A frame that parses
(checksum passes) but carries a wrong type byte, a wrong seq, an
unknown op code, a short payload, or a bad put payload is NOT a
torn write -- its checksum proves it was fully written as-is --
so it fails recovery with a hard reason (type, gap, op, length,
valid). `wVerify` is the strict form: 1 only for a fully clean
log. Appending to a torn log is refused with "torn"; repair
first (`wRepair` rewrites the file to the valid prefix).

`wApply` replays every `` `put `` entry of a WAL onto a store,
in log order; markers are skipped. Layer 8 replay is
unfiltered; Layer 9 adds transaction-aware filtering on top.
`wCheckpoint` folds a log into a store and returns a fresh log.

## File verbs and durability boundary

WAL appends use `5:` dyadic, which appends bytes to a flat-list
file (probed 2026-10-25: a 3-byte file plus a 2-byte append
reads back as the 5-byte concatenation), creates a missing file,
and treats an empty append as a no-op. From Kona's source
(`src/0.c`), `5:` calls `_5d_(x,y,1)` -- dosync 1 -- and msyncs
`MS_SYNC` after the append, including on first creation (a
missing file falls back to `_1d_write` with dosync 1). A returned
`wAppendFile` is therefore a synced append by Kona's own
mechanism. WAL full rewrites use `1:` dyadic (`wSave`), whose
write path calls `_1d_write` with dosync 0 and does NOT msync; a
crash during a rewrite can leave a torn file, which `wLoad`
recovers by prefix replay. No claim beyond Kona's mechanism is
made. After a `wAppendFile`, always `wLoad` again before
reading: Kona's source notes a variable holding an earlier `1:`
map may not see the append, so no loaded value is ever reused
across an append. Loading a missing file is a Kona-level error
(DOE), not a tagged failure, and is a caller error by contract,
as with `sLoad`: documented, not tested.

## API (src/l08.k)

- `wFTYPE` -- 87, the WAL frame type byte.
- `wOpCode`, `wOpSym`, `wOpOk` -- op symbol/code conversion.
- `wNew` -- the empty WAL (`(0;!0)`).
- `wIsWal` (raw 0/1), `wSeqOk` (raw 0/1) -- structure and
  consecutiveness checks.
- `wAppend[wal;op;txn;data]` -- append one entry; the seq is
  assigned, never supplied.
- `wEntryBytes`, `wFrameEntry`, `wBytes` -- entry/frame/file
  byte forms.
- `wRecover[bytes]` -- (1;(wal;clean)) or (0;reason).
- `wVerify[bytes]` -- raw 0/1, strict.
- `wApply[store;wal]`, `wCheckpoint[store;wal]` -- replay and
  fold.
- `wSave[wal;path]`, `wLoad[path]` -- full rewrite / load.
- `wCreateFile[path]` -- idempotent empty-file creation.
- `wAppendFile[path;op;txn;data]` -- one synced append.
- `wRepair[path]` -- rewrite a torn file to its valid prefix.

## Test scratch files

Layer 8 tests write `w8test.K`, `w8a.K`, and `w8b.K` in the repo
directory (relative paths, so the current directory must be the
repo dir, as under `run-tests.sh`). They are git-ignored. The
append-flow file `w8a.K` is reset with `wSave[wNew;...]` at the
start of its flow: `wCreateFile` does not truncate an existing
file, so without the reset a rerun would append behind the
previous run's entries and fail on seqs. Saves rewrite, so
`w8test.K` and `w8b.K` are rerun-clean without a reset.
