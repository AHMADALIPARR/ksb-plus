#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
# Production runner for KSB+. Logs to stdout and a timestamped log file.
# Supports partitioned parallel queries by launching separate Kona processes.

KONA="${KONA:-k}"
LOGDIR="${LOGDIR:-/tmp/ksb-logs}"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/ksb-$(date +%Y%m%d-%H%M%S).log"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

log "KSB+ production runner starting"
log "Kona: $KONA"

# Run all layer tests and log results
log "Running layer tests"
fail=0
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
  out=$(cat $srcs "$t" | timeout 90 "$KONA" 2>&1)
  if printf '%s\n' "$out" | grep -q "ALL PASS"; then
    log "PASS $t"
  else
    log "FAIL $t"
    fail=1
  fi
done

# Parallel partitioned query demo: split a small table across processes
log "Running parallel partitioned query demo"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Write two partition scripts
cat > "$TMP/p0.k" << 'KEOF'
/ Partition 0 query
names:`id`val
id:1 2 3 4
val:10 20 30 40
tblr:oTable[names;(id;val)]
tbl:tblr[1]
"part0 ",($#tbl[1][0])
KEOF

cat > "$TMP/p1.k" << 'KEOF'
/ Partition 1 query
names:`id`val
id:5 6 7 8
val:50 60 70 80
tblr:oTable[names;(id;val)]
tbl:tblr[1]
"part1 ",($#tbl[1][0])
KEOF

(cat src/l00.k src/l01.k src/l02.k "$TMP/p0.k" | timeout 30 "$KONA" > "$TMP/r0" 2>&1) &
(cat src/l00.k src/l01.k src/l02.k "$TMP/p1.k" | timeout 30 "$KONA" > "$TMP/r1" 2>&1) &
wait

log "Partition 0 result: $(cat "$TMP/r0" | tr '\n' ' ')"
log "Partition 1 result: $(cat "$TMP/r1" | tr '\n' ' ')"

if [ $fail -eq 0 ]; then
  log "All checks passed"
else
  log "Some checks failed"
fi
log "Log written to $LOG"
exit $fail
