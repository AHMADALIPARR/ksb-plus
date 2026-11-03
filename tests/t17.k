/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 17 tests: durable commit, atomic file replace, recovery.
/ Each "restart" below drops the in-memory handle and rebuilds it
/ from the files only (dRecover). tests/t17.sh does the same with
/ real process kills (kill -9) between write and recovery.
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
fr:{[s] bFrame[7;_ic s]}
a0:."\\rm -rf d17db"
o:dOpen["d17db"]
chk["open-new"; (o[0];o[1][1];o[1][3];sRecs[o[1][2]]); (1;0;0;(1;0))]
chk["files"; (dExists["d17db";"cur"];dExists["d17db";"s0"];dExists["d17db";"w0"]); 1 1 1]
db:o[1]
t:dBegin[db][1]
t:tPut[t;fr["a1"]][1]
t:tPut[t;fr["a2"]][1]
c:dCommit[db;t]
chk["commit"; c[0]; 1]
db:c[1]
chk["commit-recs"; dRecs[db]; (1;2)]
/ restart: rebuild from files only
r:dRecover["d17db"]
chk["recover-1"; r[1][2]; db[2]]
chk["recover-1-next"; r[1][3]; 1]
/ a second transaction, then an uncommitted one written to the
/ log without its commit entry (a crash before the commit point)
t2:tPut[dBegin[db][1];fr["b1"]][1]
db:dCommit[db;t2][1]
t3:tPut[dBegin[db][1];fr["lost"]][1]
w:wAppendFile[dWalPath[db];`put;t3[0];fr["lost"]]
r2:dRecover["d17db"]
chk["uncommitted-dropped"; r2[1][2]; db[2]]
chk["uncommitted-recs"; sRecs[r2[1][2]]; (1;3)]
/ the id of the lost txn is never reused after recovery
chk["next-after-lost"; r2[1][3]; 3]
db:r2[1]
/ wrong txn id, closed txn
chk["commit-badid"; dCommit[db;tBegin[db[2];0;0][1]]; (0;"txnid")]
chk["commit-shape"; dCommit[5;t]; (0;"shape")]
ab:dAbort[db;dBegin[db][1]]
chk["abort-next"; ab[1][3]; 4]
chk["abort-store"; ab[1][2]; db[2]]
db:ab[1]
/ torn tail: half a frame appended to the log
t4:tPut[dBegin[db][1];fr["c1"]][1]
db:dCommit[db;t4][1]
tp:dWalPath[db]
bad:10#bFrame[87;20#0]
a3:tp 5: bad
r3:dRecover["d17db"]
chk["torn-recovered"; r3[1][2]; db[2]]
chk["torn-cut"; wLoad[tp][1][1]; 1]
/ checkpoint: new generation, empty log, same data
k:dCheckpoint[db]
chk["ckpt"; (k[0];k[1][1];k[1][3]); 1 1 0]
chk["ckpt-files"; (dExists["d17db";"s1"];dExists["d17db";"w1"];dExists["d17db";"s0"];dExists["d17db";"w0"]); 1 1 0 0]
r4:dRecover["d17db"]
chk["ckpt-recover"; r4[1][2]; db[2]]
chk["ckpt-gen"; r4[1][1]; 1]
db:r4[1]
/ crash inside a checkpoint before the pointer flip: generation 2
/ files and a stray tmp exist, cur.K still says 1
t5:tPut[dBegin[db][1];fr["d1"]][1]
db:dCommit[db;t5][1]
s2:dSaveStore["d17db";2;sNew]
a5:"d17db/cur.tmp" 1: ,2
r5:dRecover["d17db"]
chk["mid-ckpt-gen"; r5[1][1]; 1]
chk["mid-ckpt-data"; r5[1][2]; db[2]]
chk["mid-ckpt-tmp-gone"; dExists["d17db";"cur.tmp"]; 0]
/ then a full checkpoint over the stale generation-2 files
k2:dCheckpoint[r5[1]]
r6:dRecover["d17db"]
chk["ckpt2"; (r6[1][1];sRecs[r6[1][2]]); (2;(1;5))]
chk["ckpt2-data"; r6[1][2]; db[2]]
/ atomic replace: the old file stays whole until the rename
a1:dAtomic["d17db";"af";1 2 3]
a4:"d17db/af.tmp" 1: 9 9
chk["atomic-old-intact"; 1: "d17db/af"; 1 2 3]
a2:dAtomic["d17db";"af";4 5]
chk["atomic-new"; 1: "d17db/af"; 4 5]
chk["open-existing"; dOpen["d17db"][1][2]; db[2]]
chk["open-badtype"; dOpen[5]; (0;"type")]
a0:."\\rm -rf d17db"
:[0=FC[0]; "ALL PASS"; "FAILURES"]
