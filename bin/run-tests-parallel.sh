#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Parallel test runner for KSB+ layers under Kona.
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

KONA="${KONA:-k}"
cd "$(dirname "$0")/.." || exit 1
fail=0
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

for t in tests/t*.k; do
  n=$(basename "$t" .k)
  num=${n#t}
  srcs=""
  for s in src/l*.k; do
    sn=$(basename "$s" .k)
    snum=${sn#l}
    if [ "$snum" \> "$num" ]; then break; fi
    srcs="$srcs $s"
  done
  (
    out=$(cat $srcs "$t" | timeout 90 "$KONA" 2>&1)
    if printf '%s\n' "$out" | grep -q "FAIL"; then
      echo "FAIL $t" > "$tmpdir/$n"
    elif printf '%s\n' "$out" | grep -qi "error"; then
      echo "FAIL $t (interpreter error)" > "$tmpdir/$n"
    elif printf '%s\n' "$out" | grep -q "ALL PASS"; then
      echo "PASS $t" > "$tmpdir/$n"
    else
      echo "BLOCKED $t" > "$tmpdir/$n"
    fi
  ) &
done
wait
for f in "$tmpdir"/t*; do
  cat "$f"
  case $(cat "$f") in
    FAIL*|BLOCKED*) fail=1 ;;
  esac
done
exit $fail
