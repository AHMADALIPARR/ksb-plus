# Layer 6: columnar engine

A table is stored as one chunk frame per column per row group, not
as whole rows. Each chunk is a 1-column table encoded with Layer 3
and stored as one record in a Layer 5 store. A column is read by
fetching only its own chunks; other columns' pages are never touched.

## Manifest

A manifest is `(names;tags;nrows;addrs)`:

- `names`: non-empty symbol list, unique (checked by qIsManifest).
- `tags`: int list, one per column: 1 int, 2 float, 3 char, 4 symbol
  (the Layer 3 column tags).
- `nrows`: non-negative int.
- `addrs`: per-column list of (page;slot) address lists, one address
  per chunk, in row order.

A column with no rows has no chunks; its type comes from the manifest
tag, so a 0-row read returns a correctly typed empty vector
(`!0`, `0#1.0 2.0`, `""`, or `0#`a`b`).

## Split

A split is `(names;tags;nrows;framesPerCol)`: the same shape with
chunk frames instead of addresses. `qSplitTable` builds a split from
a Layer 2 table; `qWrite` moves a split into a store and returns the
manifest. Splitting validates the table (kind, validity, unique
names, definite column types). A column whose element type cannot be
inferred — a general empty column, which Layer 2 accepts in a table —
is rejected with "type": chunking needs a definite element type, and
silently normalizing it to int would break round-trips.

## Row-group caps

Chunks are cut by fixed row counts, chosen so a chunk frame always
fits one 4096-byte page (4076 record bytes):

| column tag | cap (rows) | worst-case frame |
|---|---|---|
| 1 int | 400 | 3228 bytes (8 bytes per value + overhead) |
| 2 float | 150 | assumes at most 21 bytes per value (7-digit decimals plus length prefix plus margin); validated for short decimals, worst-case long-decimal fit is a formula estimate, not a measured maximum |
| 3 char | 3000 | 3000 bytes + overhead |
| 4 symbol | 25 | 25 symbols of 128 chars each (the Layer 2 symbol limit) |

Chunking is by count, not measured frame size, so short-symbol
columns use more chunks than needed: 30 symbols of 128 chars would
fit one page, but the 25 cap still splits them into 25 + 5. Fit is
verified by test (no chunk write fails with "limit"), not by
tightness of the caps.

## API

All functions return `(1;value)` / `(0;reason)` except the two
predicates, which return raw 0/1. Reasons include the Layer 2/3/4/5
reasons plus `type`, `shape`, `key`, `bounds`, `op`, `range`.

- `qSplitTable[tab]` -> `(1;split)`; `qWrite[st;sp]` -> `(1;(store;manifest))`
- `qIsManifest[mn]`, `qIsSplit[sp]` -> 0/1 (structural checks only;
  `qIsManifest` does not validate that addresses point at real pages)
- `qRead[st;mn]` -> `(1;table)`; `qColRead[st;mn;nm]` -> `(1;vector)`;
  `qReadCols[st;mn;nms]` -> `(1;column-list)`
- `qNames[mn]`, `qRows[mn]` -> `(1;names)` / `(1;nrows)`
- `qFilterIdx[col;op;val]` -> `(1;row-indices)`; `qFilter[tab;col;op;val]`
  -> `(1;table)`; `qProject[tab;nms]` -> `(1;table)`;
  `qSelect[tab;col;op;val;proj]` -> `(1;table)`
- `qAgg[tab;nm;op]` -> `(1;value)` for `count`sum`min`max`mean`
- `qScan[st;mn;col;op;val;proj]` -> `(1;table)`, pushed down (below)

Predicates: numeric columns take `lt`le`eq`ge`gt`ne; char and symbol
columns take `eq`ne only (anything else is "op"). Values must match
the column kind: numeric columns accept int/float values, char
columns require a char atom, symbol columns require a symbol
(anything else is "type"). NaN filter values on float columns give
Kona-comparison results: unspecified, not tested.

Aggregates: int sum is checked (`kChkAdd` fold, overflow -> "type");
float sum is direct `+/` (empty float -> 0.0). Min/max: int/float via
Layer 1 `kMin`/`kMax`; char via grade (Kona `&/`/`|/` type-error on
char lists); symbols -> "type". Empty -> (0;"empty") except count
(0) and float sum (0.0). Int mean is the checked sum cast to float
divided by the count; float mean is direct.

## Pushed-down scan

`qScan` reads only the predicate column, computes matching row
indices with `qFilterIdx`, then reads only the projected columns and
gathers those rows. It never materializes the full table. A scan on
one column does not touch other columns' pages at all — see below.

## Columnar isolation

Reads validate only the pages they touch. A corrupt chunk in an
unread column does not fail a read of another column: with the val
page corrupted, the id read still passes, the val read fails with
"checksum", and an id-only scan still passes. This is the columnar
isolation property, verified by test in t06, not a validation gap:
a full-table read still fails on the corrupt chunk, because it
touches every column.

## Persistence

Manifests are plain K values; they are not stored in the store.
`qWrite` returns the manifest, and the caller keeps it. A manifest
stays valid across a flat save/load round-trip because page ids are
stable (pages are concatenated in id order). The t06 persistence
test saves a store, loads it, and reads with the original manifest.

## Limits

- Fixed row-count chunking (see caps above); no size-measured packing.
- Reads validate only touched pages (isolation, by design).
- Float chunk cap worst case is a formula estimate (see caps above).
- NaN filter values are unspecified.
- No compression, no dictionaries, no zone maps: later layers may add
  them on top of this chunk/manifest shape.
