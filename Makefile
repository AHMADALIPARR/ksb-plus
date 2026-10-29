# KSB+ Makefile
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.

KONA ?= k
export KONA

.PHONY: test test-parallel prod figures walkthrough clean

test:
	sh run-tests.sh

test-parallel:
	sh bin/run-tests-parallel.sh

prod:
	sh bin/prod-runner.sh

figures:
	sh bin/make-figures.sh

walkthrough: figures
	@echo "Walkthrough at docs/WALKTHROUGH.md"

clean:
	rm -rf /tmp/ksb-prod-* /tmp/ksb-parts-* docs/figures/*.png docs/figures/*.gif 2>/dev/null || true
