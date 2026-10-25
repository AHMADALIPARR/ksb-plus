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
