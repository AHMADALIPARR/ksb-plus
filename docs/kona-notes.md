# Kona dialect notes (verified by execution, 2026-10-24)

Kona is the K interpreter used here (open source, K3/K4 dialect, built
from source). These are not K generalities; they are Kona-specific
facts that were each proven by running code, after several of them
cost real debugging time. Follow them and the code loads; ignore them
and Kona hangs or misparses.

## Verbs and syntax

- No `<=` or `>=` verbs. K3 has `<`, `>`, `=` only. Write `a<=b` as
  `~(b<a)` and `a>=b` as `~(a<b)`. Writing `<=` silently parses as `<`
  followed by `=` and produces wrong values, not an error.
- Drop needs spaces: write `n _ b`, never `n_b`. `n_b` (digit,
  underscore, letter) lexes as a single bad token and parse-errors;
  `n _ b` works. (`n_10` with a digit after the underscore happens to
  work, but do not rely on it; always space both sides.)
- Multi-argument calls use brackets: `f[x;y]`, never `f x y` (that
  applies `f` to the list `x y` as one argument).
- Bare monadic `:` hangs the interpreter. Use `:[c;t;f]` for
  conditionals and `4:` for types. (Type numbers seen: int atom 1,
  char atom 3, int list -1, char list -3.)
- `&` is min, `|` is max, `^` is power (float result). There are no
  bitwise operators. All masking is div/mod arithmetic.
- `%` on ints is truncating integer division. Modulo for
  non-negative `a` and positive `m` is `a-m*a%m`.
- `_ic` (char to int) and `_ci` (int to char) exist and work.
- `#x` is count, but `#x=y` parses as `#(x=y)`, not `(#x)=y`.
  Parenthesize counts in comparisons: `(#x)=(y)`.
- Match `~` errors (type error) when the two sides have different
  shapes. Test comparisons must compare values of matching shape;
  a shape mismatch is a test bug, not a logic bug, but the runner
  treats any interpreter error as failure.

## Loading and running

- Do not use `\l` to load files; it is unreliable here (bare filename
  parse-errors, quoted filename reports the quoted name as not
  found). The runner feeds `src/lNN.k` followed by `tests/tNN.k` to
  Kona on stdin instead.
- A bracketed expression (`:[...]`, `(...)`, `[...]`) must open and
  close on the same line. A nested cond spanning lines breaks: Kona
  evaluates the partial line, errors, and derails the rest of the
  script. Multi-line function bodies are fine only when every line is
  bracket-balanced on its own. Safest rule: write every function
  definition on a single line.
- Any parse error can drop Kona into a continuation/debug prompt that
  never exits on EOF (it prints `>` forever). Always run Kona under
  `timeout`, and always fix the first error first: one error derails
  everything after it, so downstream errors are usually cascade, not
  real bugs.
- Kona is occasionally flaky: one run of files that pass cleanly
  showed intermittent type/rank/value errors plus garbage bytes in
  the output, and the same files passed on rerun (3/3, then 2/2).
  Treat a single failing run as suspect and rerun before concluding
  the code is wrong, but never hide a consistent failure behind
  reruns. Record flakiness honestly in the ledger.

## Conditionals, evaluation order, and lists (found in Layer 1)

- `:[...]` takes exactly three arguments. An assignment placed as
  a branch (e.g. `:[c; t; x:...; value]`) does not mean "assign
  then return value": it misparses and fails at runtime with a
  type error. Compute intermediates at function top level, or move
  the rest into a helper function called from the branch.
- Evaluation is right-to-left, so arithmetic on the left of a
  comparison binds wrong: `2*ar[1]<s` parses as `2*(ar[1]<s)`,
  which is 0 or 2, and a conditional on 2 is a type error.
  Parenthesize arithmetic in comparisons: `(2*ar[1])<s`.
- Juxtaposition with a variable is application, not a list:
  `IMX 1` where IMX holds an int parses as IMX applied to 1 and
  fails with a rank error. Literal lists (`1 2 3`) are fine, but
  a list containing a variable must use comma (`IMX,1`) or
  semicolons (`(IMX;1)`).
- Atoms are not lists. Drop from an atom never shrinks (`1 _ 5`
  stays 5), so drop-based recursion on an atom recurses forever
  to a stack error, and a stack error leaves later calls in the
  session silently misbehaving. Guard list functions with a type
  check (`(4:xs)>0` rejects atoms) before recursing or folding.
- Over-folds with a tagged accumulator need enlist-then-concat:
  `(1;0),xs` flattens the pair into elements, so the fold starts
  from a bare int and fails; `(,(1;0)),xs` prepends the pair as
  one element. Prefer over-folds or direct self-recursion with a
  leaf helper; a mutual-helper recursion returning tagged pairs
  once silently produced no output for non-empty lists, and its
  mechanism was never isolated, so that shape is avoided.
- A run with runtime errors tends to end in the `>` prompt flood
  at EOF (megabytes of prompts, killed only by timeout). A clean
  run exits promptly with no flood. The flood is a symptom of
  errors, not a separate bug: fix the errors and it goes away.
  Never let a flood file land in /tmp (512M tmpfs): redirect
  Kona output to workspace disk and inspect with a length filter.

## Homogeneous collapse, 1-char strings, and `#` precedence

- K collapses homogeneous pairs and triples: (1;5) is an int
  list, (`sym;`ab) is a symbol list, (2;100;50) is an int list.
  A pair is only a general pair when its elements differ in
  type. Object kind codes are therefore symbols (a symbol kind
  plus any payload is general, except a symbol payload, which is
  handled by accepting a 2-symbol list whose first element is a
  kind symbol as an object, with the ambiguity documented).
  All-int payload pairs and triples are int lists and must be
  accepted as such, not rejected as non-pairs.
- A 1-character quoted literal is a char atom (type 3), not a
  char list: 4:"x" is 3, 4:"xx" is -3. Enlist (, "x") for a
  1-character string. String validators must require type -3,
  and tests must not use 1-character literals as string payloads.
- A monadic verb before a comparison verb takes the comparison
  as its argument: #v<b parses as #(v<b), so ~(#v<b) is ~(#v),
  not ~(length < b). Parenthesize every count before a
  comparison: ~((#v)<b). The same right-to-left rule as
  2*ar[1]<s. Counts after the comparison verb are safe:
  i<#v is i < (#v).
- Monadic ? (distinct) on an atom is a rank error. Guard with a
  list check (type code <= 0) before calling ? on unvalidated
  input. Each over an atom is safe (it applies once).
- chk's ~ errors on shape mismatch instead of returning 0, so a
  wrong-shape actual versus expected produces an interpreter
  error on the chk line itself, not a FAIL line. A missing PASS
  with a nearby type error means the shapes differed: fix the
  expectation (or the code) so both sides have the same shape.

## Layer 4: test traps that are not engine bugs

- `%` is division, not modulo (already stated above), and the
  failure mode in tests is silent: `(b+1)%256` does NOT increment
  a byte modulo 256, it divides by 256 and usually yields 0.
  Byte increments in tests must use `bMod[b+1;256]`. A test that
  "corrupts" a byte with `%256` may leave the byte unchanged
  (when the byte was already 0) or zero it (when it was not),
  and either way the corruption test passes or fails for the
  wrong reason. The Layer 4 corrupt tests originally used `%256`
  and were fixed to `bMod`.
- A frame's tag byte occupies the frame's type-byte slot; it is
  not extra. A string of N chars frames to N+18 bytes (14 bytes
  of frame overhead plus a 4-byte length prefix plus N payload
  bytes), not N+19. The Layer 4 fit tests originally miscounted
  by one and were fixed.
- When a run floods with `>` prompts, only the FIRST type error
  is real; everything after it is cascade. Find the first error,
  fix that line, and rerun. In Layer 4 the cascade repeatedly
  pointed at lines after the true failure (a wrong limit
  comparison in pAppendB, then wrong test expectations), and
  each fix moved the first error forward until the run was
  clean.

## Layer 5: file verbs, nested reads, empty each

- Kona's `1:` monadic read of a nested structure is
  unreliable, deterministically: a single-element general list
  holding a 1000-int vector segfaulted Kona 3/3 on whole-object
  match after a write/read round trip, and the same shape with
  a 4096-int vector matched 0 despite identical sampled bytes,
  while the same object matched 1 in memory and a two-element
  list matched 1. Flat int lists round-trip exactly (verified:
  an 8192-byte two-page flat list split back into two valid
  pages). Consequence: persist flat byte lists only, never
  lists of pages, and never verify persistence with a
  whole-store match; verify per page instead.
- `1:` dyadic (`path 1: data`) truncates and rewrites the whole
  file; `5:` dyadic appends to an existing file. A save that
  must replace therefore uses `1:`, never `5:`.
- Kona appends ".K" to a file path unless the path already ends
  in ".K" (tried first on read, used directly on write). Save
  and load must use the same path value.
- Loading a missing file is a Kona-level DOE error that derails
  the session into the continuation flood. Never test it inside
  a suite; make it a caller-error contract instead.
- Each over an empty index list yields a general empty list
  (type 0), not `!0`. An empty result's type therefore depends
  on how it was built; compare empties by count, or normalize
  (Layer 5's `sLoadS` normalizes an empty split to `!0` so an
  empty loaded store equals `sNew` exactly).

## Layer 8: 5: appends, msync, and the wScan shape

- `5:` dyadic appends bytes to a flat-list file: probed
  2026-10-25, a file written with `1:` holding 65 66 67, then
  `"pw" 5: 68 69`, reads back with `1:` as 65 66 67 68 69. It
  creates a missing file (append to a new path reads back the
  appended bytes), and appending `!0` is a no-op on an existing
  file (it does NOT truncate). A test that appends to a file
  must therefore reset it first (a `1:` rewrite of the empty
  list) or reruns append behind the previous run's bytes and
  fail on sequence numbers; Layer 8's append-flow test does
  exactly this reset.
- Durability grounding, from Kona's source (`src/0.c`, read
  2026-10-25): `5:` dyadic calls `_5d_(x,y,1)` -- dosync 1 --
  and msyncs `MS_SYNC|MS_INVALIDATE` after the append,
  including on first creation (a missing file falls back to
  `_1d_write` with dosync 1). The `1:` dyadic write path calls
  `_1d_write` with dosync 0 and does not msync. So `5:`
  appends are Kona's synced path and `1:` rewrites are not;
  Layer 8's durability boundary rests on this, not on a claim
  about the filesystem. Kona's source also carries a TODO
  wondering whether a variable holding an earlier `1:` map
  sees a later `5:` append -- so never reuse a loaded value
  across an append; always load again.
- The wScan shape that survives Kona's mutual-recursion traps:
  ONE function, directly self-recursive as the final branch
  value, with the per-frame decoder as a leaf helper computed
  up front. The decoder's inputs (frame bytes, parsed triple)
  are computed as top-level locals before the conditional
  chain and read only as branch conditions and recursive-call
  arguments, never after a recursive call. Computing the
  parsed triple up front is safe because `bUnframe` on short
  or torn input returns a failure triple whose reason string
  can never equal the expected type byte, so the decoder
  fails fast without indexing missing fields. Do NOT route
  the recursive call through a helper: a branch call that
  repeats its own function through another function voids,
  even through a pass-through.
- Take precedence, same family as `#x=y`: `(#b)-5#b` parses
  as count minus take (an int minus a list, broadcasting),
  not as (count-5) take. Parenthesize the count before take:
  `((#b)-5)#b`. The Layer 8 torn-tail probe first failed
  for exactly this reason, not an engine reason.

## Representation facts

- Kona ints are signed 64-bit. There is no unsigned 64-bit atom, so
  u64 is a (hi;lo) u32 pair in Layer 0.
- Kona's `1:` file verbs store typed objects in Kona's own binary
  container format (type + count header, mmap). KSB+ page bytes live
  inside that container; the container header is not part of the KSB+
  page format. Raw-byte files with no container header are not
  available through Kona's verbs; this is a documented limitation,
  not something to pretend around.

## Layer 3: recursion, folds, empty typing, float extremes

- Direct self-recursion is safe (nest, wrapn, the Layer 3
  encoder cE, the Layer 3 decoder loop cDL). Mutual recursion
  is broken in Kona, proven by single-purpose miniatures
  (2026-10-25): (1) mutual frames leak locals, so an inner
  invocation overwrites outer locals and parameters; (2) a
  dyadic verb evaluated after a recursive call returns
  mis-evaluates as a projection (right operand kept, left
  dropped); (3) a :[...] branch call that transitively repeats
  its own function through another function returns void, even
  through a pass-through helper (mini-bm, mini-bp both silent);
  (4) assigning a :[...] result to a variable yields void
  (r:[...] is not a value); (5) over with a lambda leaks under
  nesting, while each calling the SAME function preserves
  locals (each through a different named function voids);
  (6) lambdas do not capture outer locals: pass every value a
  lambda needs as a lambda parameter. Design consequence: the
  encoder is one function with inline branches plus each
  (same function) plus non-repeating assembly helpers; the
  decoder is one directly-recursive loop over an explicit
  frame stack, with leaf helpers only. Never read a pre-call
  local after a recursive call in a repeating frame, and never
  put a mutually-repeating call as a :[...] branch value.
- Over (/) folds per element only over a FLAT list whose first
  element is the seed: f/((,seed),items). The pair form
  f/((seed;items)) applies f once with the whole items list as
  the second argument (cDecInts silently decoded one element
  this way); the enlisted-pair form f/((,seed;items)) hands the
  step a wrongly-shaped accumulator (index/type errors). The
  Layer 3 sequence decoders use the concat form.
- Empty-collection typing is a literal fact with decode
  consequences: a fold seed of !0 is an INT list, so a decoded
  empty float vector came out typed as an int list and failed
  the Layer 2 validator. The float sequence decoder seeds with
  0#1.0 2.0 (an empty float list) so empty float vectors keep
  float type through decode. The same care applies anywhere a
  decoded empty collection must keep its declared type.
- Length-prefixed strings decode to CHAR lists: the decoder's
  string reader applies _ci to the taken bytes. Without it, a
  decoded string is an int list and symbol interning ($ on it)
  fails with a type error. The encoder-section copy of the
  string reader already used _ci; the decoder-section copy did
  not, and the two definitions shadowed each other (the later
  one wins). Shadowed reader definitions were deleted so each
  reader has exactly one definition.
- Float = and < miscompare at the extremes: max double compares
  EQUAL to +Inf (max=Inf reads 1, max<Inf reads 0), while
  ordinary magnitudes compare correctly. The Layer 1 infinity
  test x=2*x therefore classified max double as +Inf, and
  Layer 3 encoded it as +Inf (silent corruption). Fixed by
  testing x-x for NaN (NaN only for infinities, since finite
  x-x is 0.0): kFIsPosInf is (~NaN)&(x>0)&NaN(x-x), and
  likewise for -Inf. After the fix, max double encodes as
  finite, its 7-digit decimal fails the round-trip check, and
  encoding refuses it with (0;"float") as designed.
- Kona's $ prints floats with about 7 significant digits, so
  Layer 3 float encoding VERIFIES the round trip and refuses
  lossy values (max float, 1/3, subnormals) with (0;"float")
  instead of storing them corrupted. Ordinary short decimals
  (1.5, 0.1, 1e10, 2.5e-10) round-trip.
- Kona has no char-minus-int arithmetic: digit values for the
  decimal float parser come from ? on "0123456789".
- bFrame takes TWO arguments (type byte plus payload) and
  bUnframe returns a TRIPLE (ok;type;payload) or
  (0;reason;!0). Layer 3 returns pairs, mapping the triple.
  Nested values carry an inline tag byte plus payload, not a
  per-object frame; the outer frame's checksum covers all
  nested bytes.
- A misplaced ] inside a long :[...] chain can balance globally
  while mis-nesting locally (the Layer 3 txn branch lost its
  false branch this way: len had 4 parts, txn had 2, and only
  txn decode failed). When one kind fails while siblings pass,
  parse the suspect function into a :[...] tree and check part
  counts per conditional instead of trusting total balance.
- Test-literal traps that recurred through Layer 3: constructors
  taking multiple arguments must be called with semicolons
  (oDict[ks;vs], oTxn[id;ops;st], oTable[names;cols]), never a
  single pair; single-element collections must be enlisted
  (oIntVec[,3], vs as ,(object)); a pair in parens is grouping,
  not enlist; an extra paren pair around two arguments makes
  them one argument and fails with "unmatched". A (0;"short")
  from cDecode almost always means the test's own construction
  failed upstream and cEncode never produced a frame.
- Each does NOT broadcast a list second argument: qReadChunk'[ads;st]
  zips addresses with store pages element-wise instead of pairing
  every address with the whole store. Replicate first, as Layer 6
  does for the store and for tables/rowid lists:
  qReadChunk'[ads;(#ads)#(,st)]. Atoms replicate by take directly
  ((#gs)#nm with nm a symbol atom is correct); only LISTS need
  enlisting before take. The same trap in the other direction:
  (#cols)#ix with ix a list takes the first #cols rowids, while
  (#cols)#(,ix) replicates the whole rowid list #cols times.
- Assignment inside a function to a global name does NOT touch the
  global: the name becomes a function local, so the right-hand side
  reads an uninitialized local and errors (type error). This broke
  the shared test harness chk the first time any check failed: the
  FAIL branch (F:F+1, whether as a :[...] branch or a top-level
  statement) had never executed in t00-t05 because every check
  passed. Counters updated from inside functions must use indexed
  assignment on a global container, which modifies in place:
  FC:(,0) at top level, FC[0]:FC[0]+(~m) inside chk, and the final
  line reads FC[0]. The t00-t05 chk definitions still carry the
  latent form; they are green and untouched, but any future failing
  check there will flood instead of printing FAIL.
- &/ and |/ (min-over / max-over) type-error on char lists. Char
  min/max go through grade, which works on chars: min is
  col[(<col)[0]], max is col[(<col)[(#col)-1]], guarded by an
  empty check first (indexing an empty grade errors). Int/float
  min/max still use Layer 1 kMin/kMax.
- A (1;single-value) expectation collapses when the value is a
  scalar: (1;2) is an int list [1,2], not the pair (1;[2]), so a
  chk comparing a (1;rowid-list) result against (1;2) shape-errors
  instead of printing FAIL. Single-element (ok;list) expectations
  must enlist: (1;,2). Multi-element lists are already lists, so
  (1;1 4) is safe.
- Unwrapping a (1;(a;b)) result: the store is [1][0] and the second
  value is [1][1]. Indexing [1]/[2] on the outer pair is wrong:
  [1] is the inner pair, [2] does not exist (index error). The
  Layer 6 qWriteC bug was exactly this.
- 0#(,1) is a TYPED int empty, not a general empty: enlist preserves
  the atom's type, and take preserves the list's type. A genuine
  general empty (type 0) comes from each over an empty index list:
  {[x] x}'[!0]. Layer 2 accepts a general-empty table column as
  valid, so this distinction matters when testing untyped columns.
- Iteration practice, learned the hard way: a session derailed by
  an error floods continuation prompts until the timeout kills it,
  and one 120s flood wrote 2.3GB. When iterating on a failing test,
  cap Kona's output (pipe through head -c) so a flood cannot eat
  the disk; a clean run is a few KB and exits promptly, so the cap
  never truncates a passing run.
- Type codes differ for atoms and vectors, and mixing them up fails
  silently as a wrong branch, not a parse error: an int ATOM has
  type 1, a float atom 2, a char atom 3, a symbol 4; the matching
  VECTORS have types -1, -2, -3, -4. Layer 7's xKeyOk first compared
  key atoms against -1/-2 (the vector codes), so every numeric
  lookup failed with "type" while char/symbol keys (whose atom and
  vector-code checks happened to be written correctly) passed.
  xKeyNan made the same mistake (-2 for a float atom instead of
  2). When a function takes a type code for a vector AND checks an
  atom against it, convert explicitly: atom codes are positive.
- Kona grade is STABLE (probed on int, float, symbol duplicates):
  equal keys keep their original relative order, so a sorted index
  built by grade has deterministic rowids for dup keys.
- Kona list match treats identical NaN lists as equal (a~a is 1 for
  a NaN-containing list), even though scalar NaN comparisons are
  special. An earlier probe that seemed to show NaN breaking match
  was actually comparing lists in different orders. Consequence:
  xIsSortIdx accepts a NaN-containing sorted index; only the NaN
  rows are unreachable by key, because lookup/insert/delete/range
  reject NaN keys explicitly.
- A rowid argument that must be a list must be enlisted when it has
  one element: xGather with atom 99 fails the int-list type check
  with "type" before ever reaching the bounds check; ,99 is the
  list that exercises "bounds".
- & and | do NOT short-circuit: both sides are evaluated. A
  validator that combines a type check with a comparison on the
  same value via & type-errors when the value has the wrong
  type, instead of returning 0: (1=4:ver)&(~(ver<0)) with ver a
  char atom evaluates "x"<0, and < between char and int is a
  type error. Layer 9 proved this: the first t09 run dropped
  into the prompt loop and flooded the output file (49MB of >
  prompts) on tBegin with a non-int version. Always NEST:
  type check as the outer :[...] condition, comparison only in
  the true branch (tIsTxnV split into V/V1/V2 helpers;
  tBeginV/tBeginW nested; tEntryOkV nested). The same hazard
  applies to = between incompatible types; nest that too
  rather than assuming = returns 0 across types.
- Mixed-operator arithmetic groups right-to-left, and the
  grouping is NOT always the intended one. Probed 2026-10-25:
  2*3+2 is 10 (2*(3+2)), so a diagonal index written i*n+i
  computes i*(n+i) and is wrong; it must be (i*n)+i. By
  contrast, j+c*!r and p-ctx[3]*i are correct as written,
  because right-to-left grouping matches intent there
  (j+(c*(!r)) and p-(ctx[3]*i)). The safe rule: parenthesize
  any mixed-operator chain whose intended grouping is not
  the rightmost-first one.
- Monadic ! applies to the whole product to its right: probed
  2026-10-25, !3*3 is 0..8 (i.e. !(3*3)), not (0 3 6). So
  !n*n is a correct 0..n*n-1 range, while i*n+i (above) is
  not a correct diagonal index. Probe, do not assume, when
  the two forms look alike.
- Kona ~ distinguishes float from int: an expected float cell
  written as an int (11 instead of 11.0) fails the match even
  though the values print the same. Float test expectations
  must carry .0 decimals. Related display trap: a tagged
  pair (1;5) prints as "1 5" (an int list) — same value,
  display only.
- Multi-list each is unproven beyond 2 lists in this codebase
  (all production eaches use 1 or 2 lists). Layer 11 packs
  extra context into a single ctx tuple and replicates it
  ((#ps)#(,ctx)) so every each stays at 2 lists.
- A tagged (1;plan) result passed to eExec fails "shape":
  the executor takes unwrapped plan objects, not tagged
  results. Similarly, a single-element plan arg list or
  payload must be enlisted (,(...)): ((...)) is grouping,
  not enlist, and makes oPlan fail "valid".
- Backtick-star is NOT a plain symbol literal. Probed
  2026-10-25: (4:`*)=4 is false inside a function, and the
  same comparison at top level floods the session; 4:`*
  prints as the odd form 4::`*. Never use `* as a sentinel
  value. Layer 12 uses the plain symbol `allcols for the
  all-columns case, tested by the type check (4:cols)=4
  (a user column named allcols arrives as a list, never
  the atom, so the type check cannot confuse them).
- Subtraction chains group right-to-left like every other
  mixed-operator chain: j-i-1 is j-(i-1), not (j-i)-1.
  Layer 12's string scanner computed a 1-char content length
  as 3 this way, and K's cyclic take turned 1#"a\"" into
  the 3-char list a"a instead of erroring. The fix writes
  the length as j-(i+1) (a single subtraction, no chain).
  Cyclic take is silent: any take whose count comes from
  arithmetic must be probed, because an off-by count
  repeats input instead of failing.
- An "unmatched error" line in Kona output is a PARSE error
  (kc.c: bracket matcher returns -2), not a runtime failure.
  The offending input line is discarded, so a test line
  with a dangling ] silently never runs: Layer 12's first
  suite run showed 55 PASS + 1 FAIL out of 64 chk lines,
  with 8 lines discarded. The runner cannot catch this
  (no FAIL line is printed for a discarded line), so test
  files must be bracket-balanced per line — check with
  awk/grep before trusting a green run, and reconcile the
  PASS count against the chk count.
- A chk line written chk["name"]; g; w (semicolon after the
  name) closes the chk[ bracket early and leaves a dangling
  ] at line end: same silent-discard failure as above.
  The form is always chk["name"; g; w].
- An env written ((`t;tab)) is the pair itself (grouping),
  not a list of pairs: lookup walks into the table object
  and returns "key". Env lists must enlist single pairs
  as (,(`t;tab)).
- `#x<y` parses as `#(x<y)`, not `(#x)<y. Layer 13's
  bounds guards written ~(#toks<(i+2)) did not compare a
  count at all: Kona compared the token list against the
  bound and counted the result, and ORDER BY parsing ran
  away to "wsfull error". The safe forms are ((i+1)<#toks)
  (count on the right, correct as written) and
  ~((#toks)<(i+2)) (count parenthesized on the left).
  The same parenthesize-counts rule already covered =;
  it covers < too.
- `=` between a symbol and an int is a type error, not 0.
  Probed 2026-10-25: `count=0 prints "type error" and drops
  the session into the prompt flood. A function returning
  "symbol or 0" (Layer 13's zAggSym) must be tested by type
  code, (4:a)=1 for the failure case, never by a=0. By
  contrast, ~ across atom types is safe (`a~0 is 0).
- Never index a value that might be an atom. Probed
  2026-10-25: {[it] it[0]~`agg} applied by each to symbol
  atoms ran away to wsfull instead of erroring. Guard
  with a type check before indexing, and keep each over
  tuples/lists, never over mixed atoms.
- A test env with two pairs needs no enlist:
  ((`t;tab);(`u;rt)) is already a list of two pairs.
  But (,(`t;tab));(`u;rt) is NOT: it is a 2-list whose
  first element is an enlisted pair, so lookup walks past
  it and returns "key". Enlist only single pairs.
- A join fails "key" when the two sides share a non-key
  column name (Layer 10 duplicate check). A join test
  fixture whose left table shares nm with the right table
  fails for that reason, not for a parser reason; keep
  join fixtures free of shared non-key names, and cover
  the duplicate case separately (it passes with "key").
- Juxtaposition builds a list ONLY for literals. Probed
  2026-10-25 in bare Kona: `1 2` works, but `1 a`, `a b`,
  and `100 kIMAX` (a bare name as a juxtaposed element)
  all rank-error, and `1 2 kIMAX` gives an index error.
  Never juxtapose a bare name; use commas (`a,b`),
  explicit parens (`(a;b)`), or join (`100,kIMAX`).
  This refines the Layer 1 note ("variable juxtaposition
  is application not a list"): the observed failure is a
  rank error, not a list.
- `#'` (each-count) is broken in this Kona: probed
  2026-10-25, #'((1 2);(3 4 5)) gives "valence error",
  and so does the parenthesized form (#'). Use a named
  count helper with each instead: yCnt:{[x] #x} then
  yCnt'xs. This is the same named-function-with-each
  pattern the codebase already uses for lambdas.
- Kona's PRINTER renders LONG_MAX as 0I and LONG_MIN as
  0N, but the VALUES are correct two's-complement
  integers (probed 2026-10-25: kChkAdd[5;7] is (1;12)
  with kIMAX in scope, and kChkAdd[IMAX;1] overflows
  correctly). Never judge an extreme int by its print;
  judge it by arithmetic behavior.
- After an error, probing the failed name is
  untrustworthy: a post-error `4:bt` printed type 6
  (the error value) instead of anything about the
  binding. Fix the error first, then re-probe clean.
- Assignment echoes are inconsistent and harmless:
  a qSplitTable result assignment echoes its value,
  while plain and qWrite assignments do not (Layer 10
  note records the same). The runner only checks for
  FAIL / error / ALL PASS lines, so echoes are noise.
