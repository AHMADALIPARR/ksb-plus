# Storage format (Layer 5)

A store is a list of pages (Layer 4 byte lists), indexed by page
id: page id is the index into the list. Records are addressed as
(page id;slot), where slot is the record index inside the page.
`sPut` appends to the last page and allocates a fresh page when
the record does not fit; `sAppendTo` appends to a named page and
fails with "limit" when it does not fit. A single frame larger
than a page (record bytes over 4076) fits nowhere and fails with
"limit". All store operations build new stores; Kona copies on
indexed assignment, so deriving a new store never mutates the
old one (verified by test).

## File format

A store file holds ONE FLAT BYTE LIST: the pages concatenated
in id order, with no separator and no header of its own. The
page count is the byte length divided by 4096; a file whose
length is not a multiple of 4096 fails load with "length", and a
file that is not an int list fails with "type". On load the flat
bytes are split into 4096-byte pages and every page is fully
validated (Layer 4 `pParse`); any invalid page fails load with
"valid".

The flat format is deliberate, not incidental. Kona's `1:`
monadic read of a nested structure (a general list holding large
int vectors) returns objects that break traversal: probed
2026-10-25, a single-element general list holding a 1000-int
vector segfaulted Kona deterministically (3/3) on whole-object
match after a write/read round trip, and the same shape with a
4096-int vector matched 0 despite identical sampled bytes, while
the same object matched 1 in memory and a two-element list
matched 1. Flat int lists round-trip exactly. Layer 5 therefore
never saves a list of pages, and no test verifies persistence by
a whole-store match: persistence is verified per page
(validation, fields, frames, decoded objects).

## Kona file semantics (from Kona's source, src/0.c, and probes)

- `path 1: data` (1: dyadic) truncates and rewrites the whole
  file. A second save replaces, never appends. `sSave` uses 1:
  deliberately: the `5:` dyadic path appends to an existing file,
  and appending a store to a store file would corrupt it.
- Kona appends ".K" to the path unless the path already ends in
  ".K". Save and load must use the same path value; the on-disk
  name is the path value plus ".K" when applicable.
- Paths must be symbols or char lists. A 1-character string is
  a char atom and is rejected by the dyadic write path; `sSave`
  and `sLoad` reject non-symbol, non-char-list paths with
  "type".
- `1: path` (1: monadic) reads the file back as a Kona object
  in Kona's own binary container format (type + count header).
  The container header is not part of the KSB+ format; the KSB+
  data is the flat byte list inside it.
- Loading a missing file is a Kona-level error (DOE), not a
  tagged failure, and it derails the session (continuation
  flood). It is a caller error by contract: `sLoad` requires an
  existing file created by `sSave`. It is documented, not
  tested, for exactly that reason.

## Durability boundary (honest)

The 1: write path mmaps, writes, and munmaps without msync, so
a returned save is a complete file replacement, not a proven
durable commit. Kona's synced-write path (`5:` with dosync)
applies to first creation and to appends, neither of which
`sSave` uses, for the reasons above. No durable-commit claim is
made. Gate B (persistence) means save/load round-trips pass
their tests, not that commits are proven durable.

## API (src/l05.k)

- `sNew` — the empty store (`!0`).
- `sIsStore`, `sValid` (raw 0/1), `sCount`, `sRecs` — store
  predicates and counts; `sRecs` propagates the first page
  failure reason.
- `sCreate[store]` — returns (1;(store;id)).
- `sPage[store;id]`, `sGet[store;id;slot]` — fetch page /
  record; bounds and type failures as tagged reasons.
- `sAppendTo[store;id;frame]` — append to a named page.
- `sPut[store;frame]` — append to the last page with
  auto-spill; returns (1;(store;id;slot)). Requires a valid
  store and a valid frame; with both guards, the only way the
  last-page append can fail is "limit", so no failure reason is
  ever inspected.
- `sSave[store;path]` — full rewrite; returns (1;path).
- `sLoad[path]` — returns (1;store) or (0;reason). An empty
  file loads as `sNew` (`!0`): each over an empty index list
  yields a general empty list, so `sLoadS` normalizes empty to
  `!0` rather than leaking the each-typing into the API.

## Test scratch files

Layer 5 tests write `s5test.K`, `s5test0.K`, `s5testL.K`, and
`s5testG.K` in the repo directory (relative paths, so the
current directory must be the repo dir, as under
`run-tests.sh`). They are git-ignored, and saves rewrite them,
so reruns are clean.
