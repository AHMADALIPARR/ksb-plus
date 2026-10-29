/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 7 tests. Run via run-tests.sh, which feeds the layer chain
/ src/l00.k through src/l07.k, then this file to Kona. Each chk
/ prints PASS name or FAIL name. The last line prints ALL PASS
/ only when every check passed. The counter uses indexed assignment
/ on a global 1-element list: plain assignment inside chk would
/ read an uninitialized local, not the global (see kona-notes).
/ Lookup/range results are in INDEX (sorted-key) order, not row
/ order. Single-element (1;list) expectations are written (1;,x):
/ (1;x) collapses to an int list and would shape-mismatch.
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
uw:{[t] t[1]}
/ Sorted index, int column 30 10 20 10 40. Grade is stable in Kona
/ (probed): <col is 1 3 2 0 4, so keys 10 10 20 30 40, rowids 1 3 2 0 4.
col:30 10 20 10 40
ix:uw[xSortBuild[col]]
chk["sort-keys"; ix[0]; 10 10 20 30 40]
chk["sort-rows"; ix[1]; 1 3 2 0 4]
chk["sort-valid"; xIsSortIdx[ix]; 1]
chk["sort-struct-ok"; xSortStruct[ix]; 1]
chk["sort-unsorted"; xIsSortIdx[(col;!5)]; 0]
chk["sort-badlen"; xIsSortIdx[(10 20;1 2 3)]; 0]
chk["sort-struct-bad"; xSortStruct[(col;1 2)]; 0]
chk["sort-badcol"; xSortBuild[5]; (0;"type")]
chk["look-10"; xSortLookup[ix;10]; (1;1 3)]
chk["look-20"; xSortLookup[ix;20]; (1;,2)]
chk["look-99"; xSortLookup[ix;99]; (1;!0)]
chk["look-badtype"; xSortLookup[ix;`a]; (0;"type")]
chk["look-badix"; xSortLookup[(col;1 2);10]; (0;"shape")]
chk["range-15-35"; xSortRange[ix;15;35]; (1;2 0)]
chk["range-empty"; xSortRange[ix;35;15]; (1;!0)]
chk["range-eq"; xSortRange[ix;20;20]; (1;!0)]
chk["range-badtype"; xSortRange[ix;`a;35]; (0;"type")]
ix2:uw[xSortInsert[ix;25;5]]
chk["ins-keys"; ix2[0]; 10 10 20 25 30 40]
chk["ins-rows"; ix2[1]; 1 3 2 5 0 4]
ix3:uw[xSortInsert[ix2;10;6]]
chk["insdup-keys"; ix3[0]; 10 10 10 20 25 30 40]
chk["insdup-rows"; ix3[1]; 1 3 6 2 5 0 4]
chk["ins-badrow"; xSortInsert[ix;25;-1]; (0;"range")]
chk["ins-badkey"; xSortInsert[ix;`a;5]; (0;"type")]
chk["ins-badrowtype"; xSortInsert[ix;25;`a]; (0;"type")]
ixd:uw[xSortDelete[ix2;10;3]]
chk["del-keys"; ixd[0]; 10 20 25 30 40]
chk["del-rows"; ixd[1]; 1 2 5 0 4]
chk["del-absent-row"; xSortDelete[ix2;10;9]; (0;"key")]
chk["del-absent-key"; xSortDelete[ix2;99;0]; (0;"key")]
chk["del-badkey"; xSortDelete[ix2;`a;0]; (0;"type")]
/ Float index 2.5 1.5 2.5: grade 1 0 2, keys 1.5 2.5 2.5, rows 1 0 2.
fcol:2.5 1.5 2.5
fix:uw[xSortBuild[fcol]]
chk["flt-keys"; fix[0]; 1.5 2.5 2.5]
chk["flt-rows"; fix[1]; 1 0 2]
chk["flt-look"; xSortLookup[fix;2.5]; (1;0 2)]
nn:0.0%0.0
chk["flt-nanlook"; xSortLookup[fix;nn]; (0;"type")]
chk["flt-nanins"; xSortInsert[fix;nn;3]; (0;"type")]
ncol:(1.5;nn;2.5)
nix:uw[xSortBuild[ncol]]
chk["nan-build-valid"; xIsSortIdx[nix]; 1]
chk["nan-build-struct"; xSortStruct[nix]; 1]
chk["nan-look-ok"; xSortLookup[nix;1.5]; (1;,0)]
/ Symbol index `b`a`b: grade 1 0 2, keys `a`b`b, rows 1 0 2.
scol:`b`a`b
six:uw[xSortBuild[scol]]
chk["sym-keys"; six[0]; `a`b`b]
chk["sym-rows"; six[1]; 1 0 2]
chk["sym-look"; xSortLookup[six;`b]; (1;0 2)]
chk["sym-range"; xSortRange[six;`a;`c]; (1;1 0 2)]
/ Char index "cba": grade 2 1 0, keys "abc", rows 2 1 0.
ccol:"cba"
cix:uw[xSortBuild[ccol]]
chk["char-keys"; cix[0]; "abc"]
chk["char-rows"; cix[1]; 2 1 0]
chk["char-look"; xSortLookup[cix;"b"]; (1;,1)]
/ Hash index on the int column, 4 buckets. Within a bucket, rows
/ stay in insertion (row) order: 10 -> rows 1 then 3.
hix:uw[xHashBuild[col;4]]
chk["hash-struct"; xHashStruct[hix]; 1]
chk["hash-place"; xIsHashIdx[hix]; 1]
chk["hash-look"; xHashLookup[hix;10]; (1;1 3)]
chk["hash-look99"; xHashLookup[hix;99]; (1;!0)]
hix2:uw[xHashInsert[hix;25;5]]
chk["hash-ins-struct"; xHashStruct[hix2]; 1]
chk["hash-ins-place"; xIsHashIdx[hix2]; 1]
chk["hash-ins-look"; xHashLookup[hix2;25]; (1;,5)]
hix3:uw[xHashDelete[hix2;10;3]]
chk["hash-del-look"; xHashLookup[hix3;10]; (1;,1)]
chk["hash-del-place"; xIsHashIdx[hix3]; 1]
chk["hash-badn"; xHashBuild[col;0]; (0;"range")]
chk["hash-badcol"; xHashBuild[5;4]; (0;"type")]
chk["hash-badkey"; xHashLookup[hix;`a]; (0;"type")]
chk["hash-del-absent"; xHashDelete[hix;10;9]; (0;"key")]
hixE:uw[xHashBuild[!0;4]]
chk["hash-del-empty"; xHashDelete[hixE;10;0]; (0;"key")]
chk["hash-badix"; xHashLookup[(4;(!0;!0));10]; (0;"shape")]
/ Hash float and symbol lookups, insertion order within a bucket.
hf:uw[xHashBuild[fcol;3]]
chk["hashf-look"; xHashLookup[hf;2.5]; (1;0 2)]
chk["hashf-place"; xIsHashIdx[hf]; 1]
hs:uw[xHashBuild[scol;3]]
chk["hashs-look"; xHashLookup[hs;`b]; (1;0 2)]
chk["hashs-place"; xIsHashIdx[hs]; 1]
/ Sorted index persistence through Layer 6.
sv:xSortSave[sNew;ix]
chk["save-ok"; sv[0]; 1]
ld:xSortLoad[sv[1][0];sv[1][1]]
chk["load-ix"; ld; (1;ix)]
chk["load-look"; xSortLookup[ld[1];10]; (1;1 3)]
chk["save-badshape"; xSortSave[sNew;(col;!5)]; (0;"shape")]
/ Gather and index scan on a small columnar table.
ids:10 20 30 40 50
vals:1.5 2.5 0.5 3.5 2.5
tab:uw[oTable[`id`val;(ids;vals)]]
wr:qWrite[sNew;uw[qSplitTable[tab]]]
st:wr[1][0]
mn:wr[1][1]
chk["gather-order"; xGather[st;mn;3 0;(1#`id)]; (1;uw[oTable[(1#`id);(,40 10)]])]
chk["gather-empty"; xGather[st;mn;!0;(1#`val)]; (1;uw[oTable[(1#`val);(,0#1.0 2.0)]])]
chk["gather-bounds"; xGather[st;mn;,99;(1#`id)]; (0;"bounds")]
chk["gather-badproj"; xGather[st;mn;0 1;(1#`nope)]; (0;"key")]
chk["gather-badix"; xGather[st;mn;`a;(1#`id)]; (0;"type")]
chk["gather-badman"; xGather[st;(1;2;3;4);0 1;(1#`id)]; (0;"shape")]
gix:uw[xSortBuild[ids]]
chk["scanidx"; xScanIdx[st;mn;gix;15;35;(1#`id)]; (1;uw[oTable[(1#`id);(,20 30)]])]
chk["scanidx-2col"; xScanIdx[st;mn;gix;15;35;`id`val]; (1;uw[oTable[`id`val;(20 30;2.5 0.5)]])]
chk["scanidx-none"; xScanIdx[st;mn;gix;100;200;(1#`id)]; (1;uw[oTable[(1#`id);(, !0)]])]
chk["scanidx-badkey"; xScanIdx[st;mn;gix;`a;35;(1#`id)]; (0;"type")]
/ Empty sorted index: declared type comes from the keys vector.
eix:uw[xSortBuild[!0]]
chk["empty-valid"; xIsSortIdx[eix]; 1]
chk["empty-look"; xSortLookup[eix;10]; (1;!0)]
chk["empty-range"; xSortRange[eix;0;100]; (1;!0)]
eix2:uw[xSortInsert[eix;10;0]]
chk["empty-ins-keys"; eix2[0]; ,10]
chk["empty-ins-rows"; eix2[1]; ,0]
/ Placement verification: key 10 deliberately filed in the wrong
/ bucket. Struct still passes, so the failure is placement only.
hb:uw[xHashBucket[10;4]]
wrong:bMod[hb+1;4]
eb:(4#(, (!0;!0)))
eb[wrong]:((,10);(,0))
bad:(4;eb)
chk["hashplace-badstruct"; xHashStruct[bad]; 1]
chk["hashplace-bad"; xIsHashIdx[bad]; 0]
:[0=FC[0]; "ALL PASS"; "FAILURES"]
