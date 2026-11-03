#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.

# Layer 17, real crashes: a Kona process commits transactions in a
# loop (one record each, a checkpoint every 25) and is killed with
# kill -9 at a different moment in each round. A fresh Kona process
# then recovers from the files alone. The recovered store must be
# exactly the store of the first n commits for some n (no partial
# transaction, no lost commit before it), and the recovered
# database must accept a new commit that survives another restart.
set -u
ROOT="${KSB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
KONA="${KONA:-$ROOT/tools/kona/k}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
LAYERS=""
for s in "$ROOT"/src/l*.k; do LAYERS="$LAYERS $s"; done

cat > "$T/writer.k" <<'K'
fr:{[s] bFrame[7;_ic s]}
step:{[db;i] c:dCommit[db;tPut[dBegin[db][1];fr[$i]][1]][1]; :[0=i!25; dCheckpoint[c][1]; c]}
db:dOpen["db"][1]
db:db step/ 1+!400
K

cat > "$T/check.k" <<'K'
fr:{[s] bFrame[7;_ic s]}
ex:{[st;i] sPut[st;fr[$i]][1][0]}
r:dOpen["db"]
n:sRecs[r[1][2]][1]
e:sNew ex/ 1+!n
:[r[0]=1; "OK recover-ran"; "BAD recover-ran"]
:[r[1][2]~e; "OK prefix"; "BAD prefix"]
c:dCommit[r[1];tPut[dBegin[r[1]][1];fr["after"]][1]]
r2:dRecover["db"]
:[(c[0]=1)&(r2[1][2]~c[1][2]); "OK commit-after-recover"; "BAD commit-after-recover"]
"COUNT ",$n
K

for d in 2 4 6 9; do
  W="$T/r$d"; mkdir -p "$W"
  # shellcheck disable=SC2086
  cat $LAYERS "$T/writer.k" > "$W/in.k"
  (cd "$W" && exec "$KONA" < in.k > /dev/null 2>&1) &
  pid=$!
  sleep "$d"
  if kill -9 "$pid" 2>/dev/null; then killed=1; else killed=0; fi
  wait "$pid" 2>/dev/null
  # shellcheck disable=SC2086
  cat $LAYERS "$T/check.k" > "$W/chk.k"
  out="$(cd "$W" && timeout "${TEST_TIMEOUT:-120}" "$KONA" < chk.k 2>&1 | head -c 200000 | tr -s ' \n' ' ')"
  n="$(echo "$out" | sed -n 's/.*"COUNT \([0-9]*\)".*/\1/p')"
  ok=1
  for c in recover-ran prefix commit-after-recover; do
    case "$out" in *"OK $c"*) ;; *) ok=0 ;; esac
  done
  if [ "$ok" = 1 ] && [ -n "$n" ]; then
    pass "kill-9-after-${d}s killed=$killed recovered=$n commits"
  else
    fail "kill-9-after-${d}s"; echo "$out" | head -c 2000
  fi
done

[ "$fails" = 0 ] && echo "ALL PASS" || echo "FAILURES"
