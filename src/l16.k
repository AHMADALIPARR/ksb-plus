/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 16: partitioned query execution helpers.
/ The parallel production runner (bin/prod-runner.sh) partitions
/ work across separate Kona processes. This layer provides
/ helpers used by those processes.

pIdentity:{[t] t}

pMerge2:{[a;b] (1;a)}
