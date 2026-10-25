# Layer 13 — SQL subset

Text queries in SQL shape, over the Layer 12 env (a list of
`(name;value)` pairs; values are table objects or
`(store;manifest)` pairs). Keywords are case-INSENSITIVE;
identifiers are case-sensitive. Clauses come in one fixed
order; anything out of order or trailing fails "parse".

## Grammar

```
query := SELECT collist FROM t [JOIN u ON q1.c1 = q2.c2]
           [WHERE p [AND p ...]] [ORDER BY [q.]c [ASC|DESC]]
           [LIMIT n]
collist := * | item [, item ...]
item    := [q.]col | COUNT|SUM|AVG|MIN|MAX ( [q.]col | * )
p       := [q.]col op value        (Layer 12 pred groups)
op      := < <= = >= > != <>
value   := [-]int | [-]float | "string" | `symbol
```

- `*` alone means all columns. An aggregate must be the ONLY
  item; mixing aggregates with plain columns fails "parse"
  (that needs GROUP BY, out of subset), and aggregate queries
  reject ORDER BY and LIMIT ("parse").
- `*` as an aggregate argument is allowed only for COUNT
  (`SUM(*)` fails "parse"); other aggregates take a column.
- JOIN is an inner equi-join via the Layer 10 join plan. ON
  needs qualified names on both sides and `=` only, in either
  order (normalized at parse). Unqualified ON sides or a
  non-`=` operator fail "parse"; a qualifier naming no table
  in scope fails "key".
- A qualifier anywhere (SELECT, WHERE, ORDER BY, aggregate
  argument) must name a table in scope (FROM, or JOIN with a
  join) or the query fails "key". Unknown tables fail "key".
- WHERE predicates are AND-separated (case-insensitive AND).
  ORDER BY is a single column, default ASC; it sorts BEFORE
  projection, so it may name any filtered-table column, not
  just a selected one. LIMIT n needs a non-negative int token
  (a minus sign or a float fails "parse"); LIMIT 0 gives a
  0-row table.
- Self-join by one name fails "parse": without aliases the
  two sides are indistinguishable.
- Columns literally named like clause keywords (from, join,
  where, order, limit, select) are not addressable in the
  positions where the parser scans for those keywords.

## Execution

- Plain queries (no join, no aggregate): table envs run
  Layer 10 filter/sort/project/limit plans; store envs push
  the first predicate down as a Layer 10 scan plan (Layer 6
  pushdown), or read fully when there are no predicates.
  Plan order is filters, sort, project, limit.
- Joins: both sides are materialized first (stores are read
  fully, since join needs table objects), then the Layer 10
  join plan runs, followed by filters, sort, project, limit.
  The joined table keeps left columns plus right non-key
  columns; the right key column is dropped (Layer 10 shape),
  so WHERE/ORDER BY on it fails "key".
- Aggregates materialize (no scan pushdown): filters and the
  join (if any) run first, then the aggregate. COUNT(*) uses
  oLen (row count); COUNT(col)/SUM/AVG/MIN/MAX use qAgg on
  the post-pipeline table (missing column fails "key", empty
  MIN/AVG fail "empty", symbol MIN/MAX fail "type" — all
  Layer 6 behavior, passed through). AVG maps to the Layer 6
  `mean` op; the result column is still named `avg`. The
  result is a 1-row 1-column table named
  count/sum/avg/min/max.

## Errors

- "parse": rejected query text, out-of-order clauses,
  trailing tokens, aggregate misuse, bad LIMIT tokens.
- "key": unknown table, unknown column, qualifier naming no
  table in scope, duplicate join columns (Layer 10).
- Every other reason passes through from Layers 6/10/12
  unchanged ("type", "op", "shape", "range", "empty").

## Limits (honest)

- No GROUP BY / HAVING, no OR, no subqueries, no outer
  joins, no multi-key joins, no expressions in SELECT.
- No aliases: a table has exactly one name (its env name).
- String predicate values parse but fail "type" at execution
  (Layer 6 has no string column type), same as Layer 12.
- Parsing is segment-based (tokenize, find clause keywords,
  slice segments), reusing the Layer 12 tokenizer and
  pred-group parser. There is no K source parser; plans are
  data (Layer 10).

## Kona notes (see kona-notes.md)

- `#x<y` parses as `#(x<y)`, not `(#x)<y`: count guards
  must parenthesize the count, `~((#toks)<(i+2))`.
- `=` between a symbol and an int is a type error: a
  function returning "symbol or 0" must be tested by type
  code `(4:a)=1`, never by `a=0`.
- Never index a value that might be an atom: `sym[0]` on a
  symbol atom runs away (wsfull) instead of erroring.
