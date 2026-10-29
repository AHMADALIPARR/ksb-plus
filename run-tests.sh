# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
#!/bin/sh
# KSB+ Sovereign Binary Database Engine
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

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
