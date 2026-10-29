#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Generate figures from real KSB+ runs.
# Requires gnuplot or falls back to text summary.

KONA="${KONA:-k}"
cd "$(dirname "$0")/.." || exit 1
mkdir -p docs/figures

echo "Running timed layer tests..."
: > docs/figures/times.txt
for t in tests/t0*.k tests/t1*.k; do
  [ -f "$t" ] || continue
  n=$(basename "$t" .k)
  num=${n#t}
  srcs=""
  for s in src/l*.k; do
    sn=$(basename "$s" .k)
    snum=${sn#l}
    if [ "$snum" \> "$num" ]; then break; fi
    srcs="$srcs $s"
  done
  start=$(date +%s%N)
  cat $srcs "$t" | timeout 90 "$KONA" >/dev/null 2>&1
  end=$(date +%s%N)
  ms=$(( (end - start) / 1000000 ))
  echo "$num $ms" >> docs/figures/times.txt
done

if command -v gnuplot >/dev/null 2>&1; then
  gnuplot << 'GP'
set terminal png size 800,400
set output "docs/figures/layer-times.png"
set title "KSB+ Layer Test Times (ms)"
set xlabel "Layer"
set ylabel "Time (ms)"
set style data histogram
set style fill solid
plot "docs/figures/times.txt" using 2:xtic(1) title "time"
GP
  echo "Wrote docs/figures/layer-times.png"
else
  echo "gnuplot not found; times written to docs/figures/times.txt"
fi

# Simple GIF placeholder via convert if available
if command -v convert >/dev/null 2>&1 && [ -f docs/figures/layer-times.png ]; then
  convert -delay 100 docs/figures/layer-times.png docs/figures/layer-times.png docs/figures/run.gif
  echo "Wrote docs/figures/run.gif"
fi
