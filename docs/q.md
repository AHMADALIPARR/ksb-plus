# Layer 12 — Q interface

Text queries over tables and columnar stores, in the q idiom.
Keywords are lowercase and case-sensitive; identifiers are
case-sensitive. There is no string interpolation, no sort/limit
clause, and no escape mechanism in string literals.

## Entry

`uQ[env;query]` — `env` is a list of `(name;value)` pairs
(enlist a single pair: `(,(name;value))` — a pair in parens
alone is grouping, not enlist). A value is a table object or a
`(store;manifest)` pair. Result is `(1;table)` for `select`,
`(1;vector)` for `exec`, or `(0;reason)`.

## Grammar

```
query  := select [cols] from t [where p,p,...]
        | exec col from t [where p,p,...]
cols   := * | c1,c2,...
p      := name op value
op     := < <= = >= > != <>
value  := [-]int | [-]float | "string" | `symbol
```

- Absent `cols` means `*` (all columns, no project step).
- Where predicates are COMMA-separated (q idiom), unlike SQL.
- Int literals: at most 18 digits. Floats need a leading digit
  (`.5` is rejected); exponents are supported (`2.5e-1`).
- String literals have no escapes; an unterminated string is a
  parse failure. String predicate values parse but fail with
  "type" at execution: Layer 6 has no string column type.
- Qualified names (`t.col`) are rejected in Q ("parse").

## Execution

- Table env: predicates become Layer 10 `filter` plans, columns
  become a `project` plan; no predicates and no projection is
  the identity (the table itself).
- Store env, first predicate present: the first predicate becomes
  a Layer 10 `scan` plan (Layer 6 pushdown), the rest become
  `filter` plans, then an optional `project` plan.
- Store env, no predicates: the store is read fully, then an
  optional `project` plan runs on the table.
- `exec` runs the same predicate pipeline, then returns the named
  column's raw vector via `oCol` (not a table).

## Errors

- "parse": rejected query text, including literal-construction
  failures (over-long names/strings map to "parse", not "limit").
- "key": unknown table name; unknown column (passed through from
  Layers 6/10).
- Every other execution reason passes through from Layers 6/10
  unchanged ("type", "op", "shape", "range", "bounds", "valid").

## Limits (honest)

- No `sort`/`limit` clause in Q text; use Layer 10 plans directly
  or the SQL layer (Layer 13).
- No joins in Q text; use Layer 10 `join` plans directly.
- No char-column predicates expressible: Layer 2 has no char-atom
  object, so a char predicate fails "type" from Layer 6.
- Parsing is segment-based (tokenize, split on clause keywords
  and separators, validate each segment). There is no recursive
  descent and no K source parser; plans are data (Layer 10).

## Kona notes (see kona-notes.md)

- The `*` character is NOT a usable symbol literal in Kona: the
  all-columns sentinel is the plain symbol `allcols`, and the
  star test is the type check `(4:cols)=4`.
- Arithmetic chains group right-to-left: `j-i-1` is `j-(i-1)`,
  not `(j-i)-1`. The string scanner writes `j-(i+1)`.
