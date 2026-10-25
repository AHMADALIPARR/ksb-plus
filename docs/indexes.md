# Layer 7: indexes

Two index kinds, both built on the Layer 6 columnar engine. Neither
changes stored data: an index is a K value naming rows, and the
columnar store stays the source of truth.

## Sorted index

A sorted index is `(keys;rowids)`: keys a typed vector in grade
order, rowids an int list of the same length. Kona grade is stable
(probed on int, float, and symbol duplicates), so dup keys keep
their original relative order and rowids are deterministic.

- `xSortBuild[col]` -> `(1;(sorted-keys;grade))`. Rejects
  non-typed-vector columns with "type".
- `xSortLookup[ix;key]` -> `(1;rowids)` for the key's
  `[xLo, xHi)` interval. Misses yield `(1;!0)`.
- `xSortRange[ix;lo;hi]` -> `(1;rowids)` for keys in `[lo,hi)`,
  via two `xLo` calls. `hi <= lo` yields `(1;!0)`; the guard sits
  after the key-type checks, so incomparable keys report "type"
  instead of silently returning empty.
- `xSortInsert[ix;key;row]` inserts after existing equals
  (position `xHi`). Row must be an int atom >= 0, else
  "type" / "range".
- `xSortDelete[ix;key;row]` deletes one occurrence. Absent key or
  absent row reports "key".

Results are in INDEX (sorted-key) order, not row order: a range
`[15,35)` over keys `10 10 20 30 40` returns rowids `2 0` (the 20 row,
then the 30 row).

Binary search is two SEPARATE directly self-recursive functions,
`xLo` (first i with `ks[i] >= key`) and `xHi` (first i with
`ks[i] > key`), with the midpoint recomputed inline in each branch.
They must not share a helper: Kona mutual recursion leaks locals
and voids branch calls (see kona-notes). Empty indexes are handled
by the `lo = hi` base case, never by indexing.

Predicates: `xIsSortIdx` checks structure plus sortedness
(`keys ~ keys[<keys]`); `xSortStruct` checks structure only, so
lookups are not O(n)-validated — sortedness is the caller's or the
test's explicit check. Key types: numeric indexes accept int or
float keys; char indexes require a char atom; symbol indexes require
a symbol; anything else is "type".

### NaN semantics (SQL-NULL-like)

Grade sorts NaN first, deterministically, so a built float index
may contain NaN rows. But NaN keys are rejected for lookup, insert,
delete, and range with "type", so those rows are unreachable by key
— they exist, they just cannot be found by key. Kona list match
treats identical NaN lists as equal, so `xIsSortIdx` still accepts a
NaN-containing sorted index, and save/load work for it.

## Hash index

A hash index is `(n;buckets)`: `n` buckets, each a `(keys;rowids)`
pair. Keys are placed by `kBucket` over `kHashBytes` of the key
bytes: int via `kI64ToBytes`, float via its `$` decimal, char atom
enlisted, symbol via its `$` name, all as int lists. Within a bucket,
rows stay in insertion (row) order.

- `xHashBuild[col;n]` -> `(1;(n;buckets))`. `n` must be an int
  atom >= 1, else "type" / "range"; the column must be typed, else
  "type". Buckets start as `n` copies of `(typed-empty;!0)`.
- `xHashLookup[ix;key]` -> `(1;rowids)`. An all-empty index yields
  `(1;!0)` before any key check, so an empty index never rejects a
  key type. Otherwise the key type must match, else "type".
- `xHashInsert[ix;key;row]` appends to the key's bucket. An
  all-empty index accepts any valid non-NaN key type; otherwise the
  type must match. An EMPTY bucket's keys are replaced by the typed
  empty for the key's type before appending, so a first insert into
  a virgin or wrongly-typed-empty bucket can never corrupt the
  bucket's type.
- `xHashDelete[ix;key;row]` deletes one occurrence, first match
  only. Empty index and absent key/row report "key". The key type
  is checked before the mask, so a mismatched key reports "type"
  instead of erroring in the element-wise comparison.
- `xIsHashIdx[ix]` is the struct check plus full placement
  verification: every key in every bucket re-hashes to its own
  bucket index. Empty buckets pass vacuously. A key deliberately
  filed in the wrong bucket still passes struct but fails placement
  (verified by test).

`xHashStruct` accepts bucket keys that are typed, or general AND
empty (virgin buckets built by hand). `xHashKeyType` is the first
non-empty bucket's keys type, or 0 when all buckets are empty.

## Persistence

Sorted indexes persist through Layer 6: `xSortSave[st;ix]` builds a
two-column table (`` `key`row ``) and writes it with `qWrite`,
returning `(1;(store;manifest))`; `xSortLoad[st;mn]` reads it back
and gates on `xIsSortIdx`, so a loaded index is sorted by
construction. An unsorted hand-built index is refused with "shape".
Manifests are plain K values kept by the caller, as in Layer 6.

Hash index persistence is out of scope for this layer.

## Gather and index scan

- `xGather[st;mn;ix;proj]` returns a table of exactly the given
  rows, in the given order, for the projected columns. Checks, in
  order: manifest ("shape"), rowids an int list ("type"), proj a
  symbol list ("type"), bounds ("bounds"; empty rowids trivially
  pass and yield a 0-row table with the projected columns). Then it
  reads only the projected columns with `qReadCols` and gathers.
- `xScanIdx[st;mn;ix;lo;hi;proj]` is range plus gather, end to end:
  a columnar store plus a sorted index yields rows, touching only
  the indexed range's rows and the projected columns.

## Limits

- Hash indexes do not persist (see above).
- No uniqueness enforcement: both index kinds allow dup keys.
- No composite (multi-column) keys.
- `xGather` with an empty projection list is untested (Layer 2
  behavior, not this layer's).
