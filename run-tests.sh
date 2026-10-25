#!/bin/sh
# Run every KSB+ layer test under Kona and report pass/fail per file.
# Each test file expects its layer chain already loaded, so the runner
# feeds src/l00.k through src/lNN.k followed by tests/tNN.k to Kona
# on stdin (Kona's \l is unreliable here). Kona is run under timeout:
# a parse error drops Kona into a continuation prompt that never exits
# on EOF, so an unbounded run would hang instead of failing.
# A file passes only if it prints no FAIL line and its summary says
# ALL PASS.
KONA="${KONA:-$HOME/workspace/.tools/kona/k}"
cd "$(dirname "$0")"
fail=0
for t in tests/t*.k; do
  n="$(basename "$t" .k)"
  num="${n#t}"
  src="src/l${num}.k"
  if [ -f "$src" ]; then
    srcs=""
    for s in src/l*.k; do
      sn="$(basename "$s" .k)"
      snum="${sn#l}"
      if [ "$snum" \> "$num" ]; then break; fi
      srcs="$srcs $s"
    done
    out="$(cat $srcs "$t" | timeout 60 "$KONA" 2>&1)"
  else
    out="$(timeout 60 "$KONA" < "$t" 2>&1)"
  fi
  if printf '%s\n' "$out" | grep -q "FAIL"; then
    echo "FAIL $t"; fail=1
  elif printf '%s\n' "$out" | grep -qi "error"; then
    echo "FAIL $t (interpreter error in output)"; fail=1
  elif printf '%s\n' "$out" | grep -q "ALL PASS"; then
    echo "PASS $t"
  else
    echo "BLOCKED $t (no summary)"; fail=1
  fi
done
exit $fail
