/ SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0
/ Copyright Ahmad Ali Parr
/ Layer 17: durable database files with atomic commit and crash
/ recovery, on Layers 5 (store), 8 (WAL) and 9 (transactions).
/ Prefix d. A database is a directory holding one generation g:
/   sG.K   the store as of the last checkpoint
/   wG.K   the write-ahead log since that checkpoint
/   cur.K  the current generation number
/ Commit: every put of the transaction is appended to wG with 5:
/ (Kona msyncs each append), then a commit entry is appended. The
/ commit entry is the commit point: recovery replays only
/ transactions whose commit entry is in the log (tReplay), so a
/ crash before it loses the whole transaction and a crash after it
/ keeps the whole transaction. A torn tail (partial last frame)
/ is cut off by wRepair before replay.
/ Whole-file writes (store, pointer) are atomic: write X.tmp.K,
/ sync, rename over X.K, sync. rename is atomic on POSIX file
/ systems, so a reader sees the old file or the new one, never a
/ mix. Checkpoint writes sG+1 and an empty wG+1, then flips cur.K
/ from G to G+1 in one rename; a crash before the flip leaves
/ generation G intact, a crash after it leaves G+1 complete.
/ Isolation: one writer per directory; a transaction sees the
/ store it began from (Layer 9 snapshot). Consistency: every page
/ is validated on load (Layer 4 checksums), every log frame on
/ replay (Layer 8).
/ The handle is (dir;gen;store;nextTxnId). All public functions
/ return (1;value) or (0;reason). Reasons: type, shape, status,
/ txnid, plus any Layer 5/8/9 reason.
dSh:{[c] ."\\",c; 1}
dPath:{[dir;nm] dir,"/",nm}
dGenNm:{[c;g] c,($g)}
dExists:{[dir;nm] fl:dPath[dir;"flag.txt"]; dSh["test -f ",dPath[dir;nm],".K && echo 1 > ",fl," || echo 0 > ",fl]; 0$(0: fl)[0]}
dDirOk:{[dir] ((-3)=4:dir)&(0<#dir)}
/ Atomic whole-file write: tmp, sync, rename, sync.
dAtomic:{[dir;nm;xs] tp:dPath[dir;nm,".tmp"]; tp 1: xs; dSh["sync"]; dSh["mv -f ",tp,".K ",dPath[dir;nm],".K"]; dSh["sync"]; (1;nm)}
dGen:{[dir] r:1: dPath[dir;"cur"]; r[0]}
dSaveStore:{[dir;g;st] :[sValid[st]; dAtomic[dir;dGenNm["s";g];sFlat[st]]; (0;"valid")]}
dNewWal:{[dir;g] wp:dPath[dir;dGenNm["w";g]]; dSh["rm -f ",wp,".K"]; wCreateFile[wp]}
/ Create generation 0 in an empty directory. cur.K is written last.
dInit:{[dir] dSh["mkdir -p ",dir]; s:dSaveStore[dir;0;sNew]; w:dNewWal[dir;0]; dSh["sync"]; dAtomic[dir;"cur";,0]}
/ Open: create if new, then recover.
dOpen:{[dir] :[dDirOk[dir]; dOpenM[dir;dSh["mkdir -p ",dir]]; (0;"type")]}
dOpenM:{[dir;m] dOpenE[dir;dExists[dir;"cur"]]}
dOpenE:{[dir;ex] :[ex; dRecover[dir]; dOpenI[dir;dInit[dir]]]}
dOpenI:{[dir;r] :[r[0]=0; r; dRecover[dir]]}
/ Recover: load the checkpoint, cut a torn log tail, replay the
/ committed transactions. Leftover .tmp files are removed.
dRecover:{[dir] :[dDirOk[dir]; dRecoverG[dir;dGen[dir]]; (0;"type")]}
dRecoverG:{[dir;g] dSh["rm -f ",dir,"/*.tmp.K"]; w:wRepair[dPath[dir;dGenNm["w";g]]]; :[w[0]=0; w; dRecoverS[dir;g;w[1];sLoad[dPath[dir;dGenNm["s";g]]]]]}
dRecoverS:{[dir;g;wal;sl] :[sl[0]=0; sl; dRecoverR[dir;g;wal;tReplay[sl[1];wal]]]}
dRecoverR:{[dir;g;wal;r] :[r[0]=0; r; (1;(dir;g;r[1];dNextId[wal[1]]))]}
dTxnOf:{[e] e[2]}
dNextId:{[es] :[(0=#es); 0; 1+|/dTxnOf'es]}
dIsDb:{[db] :[(0=4:db)&(4=#db); dDirOk[db[0]]&(1=4:db[1])&(sIsStore[db[2]])&(1=4:db[3]); 0]}
dWalPath:{[db] dPath[db[0];dGenNm["w";db[1]]]}
/ Begin a transaction on the current store with the next id.
dBegin:{[db] :[dIsDb[db]; tBegin[db[2];0;db[3]]; (0;"shape")]}
/ Commit: append the puts, then the commit entry (the commit point).
dCommit:{[db;t] :[dIsDb[db]; dCommitT[db;t]; (0;"shape")]}
dCommitT:{[db;t] :[tIsTxn[t]; :[t[1]=0; dCommitI[db;t]; (0;"status")]; (0;"shape")]}
dCommitI:{[db;t] :[t[0]=db[3]; dCommitW[db;t;dWalPath[db]]; (0;"txnid")]}
dCommitW:{[db;t;wp] r:dPutStep/((,(1;wp)),t[4]); :[r[0]=0; r; dCommitM[db;t;wp]]}
dPutStep:{[acc;e] :[acc[0]=0; acc; wAppendFile[acc[1];e[0];e[1];e[2]]]}
dCommitM:{[db;t;wp] m:wAppendFile[wp;`commit;t[0];!0]; :[m[0]=0; m; (1;(db[0];db[1];t[3];t[0]+1))]}
/ Abort: nothing reaches the log; the id is not reused.
dAbort:{[db;t] :[dIsDb[db]; :[tIsTxn[t]; (1;(db[0];db[1];db[2];1+db[3]|t[0])); (0;"shape")]; (0;"shape")]}
/ Checkpoint: write generation g+1, then flip cur.K in one rename.
dCheckpoint:{[db] :[dIsDb[db]; dCheckpointS[db;db[1]+1;dSaveStore[db[0];db[1]+1;db[2]]]; (0;"shape")]}
dCheckpointS:{[db;g1;s] :[s[0]=0; s; dCheckpointW[db;g1;dNewWal[db[0];g1]]]}
dCheckpointW:{[db;g1;w] :[w[0]=0; w; dCheckpointF[db;g1;dAtomic[db[0];"cur";,g1]]]}
dCheckpointF:{[db;g1;c] dSh["rm -f ",dPath[db[0];dGenNm["s";db[1]]],".K ",dPath[db[0];dGenNm["w";db[1]]],".K"]; (1;(db[0];g1;db[2];0))}
/ Read helpers.
dStore:{[db] :[dIsDb[db]; (1;db[2]); (0;"shape")]}
dRecs:{[db] :[dIsDb[db]; sRecs[db[2]]; (0;"shape")]}
