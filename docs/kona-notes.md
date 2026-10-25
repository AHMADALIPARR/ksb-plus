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

## Representation facts

- Kona ints are signed 64-bit. There is no unsigned 64-bit atom, so
  u64 is a (hi;lo) u32 pair in Layer 0.
- Kona's `1:` file verbs store typed objects in Kona's own binary
  container format (type + count header, mmap). KSB+ page bytes live
  inside that container; the container header is not part of the KSB+
  page format. Raw-byte files with no container header are not
  available through Kona's verbs; this is a documented limitation,
  not something to pretend around.
