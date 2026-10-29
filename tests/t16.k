/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Layer 16 tests. Parallel partitioned query helpers.

FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
names:`id`val
id:1 2 3 4
val:10 20 30 40
tblr:oTable[names;(id;val)]
tbl:tblr[1]
id2:pIdentity[tbl]
chk["identity"; id2~tbl; 1]
merged:pMerge2[tbl;tbl]
chk["merge ok"; merged[0]; 1]
"ALL PASS"
