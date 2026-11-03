#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.

# Load every KSB+ layer into Kona, then run K files or stdin.
#
#   scripts/ksb.sh examples/01-tables.k     layers + one file
#   echo '2+2' | scripts/ksb.sh -           layers + stdin
#
# Kona's \l is unreliable for this code base, so the layers are fed
# on stdin, in order. Runs under timeout (KSB_TIMEOUT, default 120 s)
# because a K parse error leaves Kona waiting at a continuation prompt.
# Kona prints its prompt as leading spaces when stdin is not a
# terminal; those leading spaces are trimmed from every line.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${KONA:-}" ] && [ -x "${KONA:-}" ]; then :
elif [ -x "$ROOT/tools/kona/k" ]; then KONA="$ROOT/tools/kona/k"
elif [ -x "$HOME/workspace/.tools/kona/k" ]; then KONA="$HOME/workspace/.tools/kona/k"
else KONA="$(command -v kona || command -v k)" || { echo "Kona not found; run make kona" >&2; exit 2; }
fi
[ $# -gt 0 ] || set -- -
# shellcheck disable=SC2046
cat "$ROOT"/src/l*.k "$@" | timeout "${KSB_TIMEOUT:-120}" "$KONA" 2>&1 | sed "s/^ *//" | head -c 2000000
