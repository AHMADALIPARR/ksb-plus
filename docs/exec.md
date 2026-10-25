# Layer 10: K execution

Plans are Layer 2 objects, not K source. There is NO K source
parser in this layer: a plan is data (a `plan` object whose payload
is (op;args)), and the executor walks it. This is stated honestly,
not as a gap to be filled silently: parsing K text into plan
objects belongs to a later layer's interface work, if at all.

## Environment

`eExec[env;plan]` takes two environment forms:

- A table object: `filter`, `project`, `select`, `sort`, `limit`,
  and `join` run against it.
- A `(store;manifest)` pair (the Layer 6 pair form): only `scan`
  runs against it. Any other op on a store environment fails
  "shape", and `scan` on a table environment fails "shape".

A pipeline is a list of plan objects, applied left to right;
the first failure stops the pipeline and is returned. A single
plan object is accepted as a one-step pipeline. Anything else
(an atom, an empty list, a list containing a non-plan) fails
"shape". An empty pipeline fails "shape" (there is no identity
query in this layer).

## Plan shape

Plan args are Layer 2 objects, never raw values:

- names and ops: sym objects (`sym;name)
- values: int, flt, str, or sym objects
- projections: a list object of sym objects

| op | args | meaning |
|---|---|---|
| scan | col, op, value, projection | Layer 6 pushed-down scan: predicate plus projection, store env only |
| filter | col, op, value | Layer 6 filter on a table |
| project | projection | column subset, in the given order |
| select | col, op, value, projection | filter then project, one step |
| sort | col [, dir] | ascending by default; dir −1 (int object) for descending |
| limit | n | first n rows; n = 0 gives a 0-row table |
| join | right-table, left-key, right-key | inner equi-join, table env only |

## Join

Join is an inner equi-join on key columns. It builds a Layer 7
hash index over the right table's key column, looks up each left
key, and concatenates the matches in left-row order (matches
within a left row in right-row order). Non-key columns from both
sides are kept; the right key column is dropped. A duplicate
non-key column name fails "key" before any rows are gathered.
NaN keys fail "type" (Layer 7 rejects NaN keys). A right side
that is not a table object fails "type".

## Sort

Sort is ascending by Layer 6's stable grade, or descending with
a second int arg of −1. Descending reverses the stable ascending
grade, so equal keys come out in reverse row order (not stable
descending). Sort by a missing column fails "key"; a non-int
direction fails "type"; any other direction value fails "range".

## Error vocabulary

- "shape": wrong environment for the op, wrong arg count, empty
  pipeline, non-plan input, malformed projection.
- "key": missing column (filter/project/select/sort/scan/join).
- "op": unknown op, or a predicate op invalid for the column.
- "type": wrong arg object type, wrong value type for the column,
  non-table join side, NaN key.
- "range": negative limit, direction other than 1/−1, out-of-range.
- "bounds": (from Layer 6) — not produced by this layer directly.
- "valid": (from Layer 6) — a corrupt store or manifest.

## Honest limits

- No parser: plans are data. K text is not executed.
- Char-column predicates cannot be expressed: Layer 2 has no
  char-atom object, and Layer 6 requires a char atom for a char
  predicate, so such a plan fails "type" from Layer 6.
- Descending sort is reversed-ascending, not stable-descending
  (see above).
- Join is inner equi-join only: no outer joins, no multi-key
  joins, no uniqueness enforcement (Layer 7 has none).
- Sort and limit materialize full tables; there is no streaming
  or lazy pipeline.
- A plan object that fails Layer 2 validity (bad op, bad args)
  cannot be constructed by oPlan at all — oPlan fails first, so
  the executor never sees it. An unknown op inside a hand-built
  plan pair fails "op" at dispatch.
