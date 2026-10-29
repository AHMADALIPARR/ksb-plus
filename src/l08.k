/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 8: WAL/recovery. A WAL (write-ahead log) is the redo log
/ for a Layer 5 store: a sequence of entries, each a Layer 0
/ frame, so a store lost to a crash can be rebuilt by replaying
/ the log. Entries are (seq;op;txn;data): seq is a u32 sequence
/ number starting at 0 and increasing by exactly 1 per entry, op
/ is a symbol (`put, `commit, `abort, `ckpt), txn is the owning
/ transaction id (-1 for a non-transactional entry; Layer 9
/ interprets txn ids), data is a store frame for `put and empty
/ for markers. A WAL value is (nextSeq;entries): nextSeq is the
/ seq the next appended entry gets, entries the entry list.
/ File format: a WAL file holds ONE FLAT BYTE LIST, the entry
/ frames concatenated in seq order, no header of its own. An
/ entry frame has type byte 87 and payload
/   u32be seq, 1 op-code byte, i32be txn, data bytes.
/ Op codes: put 1, commit 2, abort 3, ckpt 4.
/ RECOVERY SEMANTICS (read before trusting a replay): wRecover
/ scans frames in order and returns the longest valid prefix
/ plus a clean flag. A frame that fails to parse (short, length,
/ checksum, magic, version) ends the scan as a TORN TAIL: the
/ prefix is returned with clean 0, because a torn write can
/ damage any part of the final frame, and once a frame fails to
/ parse nothing after it can even be located. A frame that
/ parses (checksum passes) but carries a wrong type byte, a
/ wrong seq, an unknown op code, a short payload, or a bad put
/ payload is NOT a torn write -- its checksum proves it was
/ fully written as-is -- so it fails recovery with a hard
/ reason (type, gap, op, length, valid). wVerify is the strict
/ form: 1 only for a fully clean log.
/ DURABILITY BOUNDARY (honest, grounded in Kona's source,
/ src/0.c): WAL appends use 5: dyadic, whose implementation
/ calls _5d_(x,y,1) -- dosync 1 -- and msyncs MS_SYNC after the
/ append, including on first creation (missing file falls back
/ to _1d_write with dosync 1). A returned wAppendFile is
/ therefore a synced append by Kona's own mechanism. WAL full
/ rewrites use 1: dyadic (wSave), whose write path calls
/ _1d_write with dosync 0 and does NOT msync; a crash during a
/ rewrite can leave a torn file, which wLoad recovers by prefix
/ replay. No claim beyond Kona's mechanism is made. After a
/ wAppendFile, always wLoad again before reading: Kona's source
/ notes a variable holding an earlier 1: map may not see the
/ append, so no loaded value is ever reused across an append.
/ Appending to a torn log is refused with "torn": repair first
/ (wRepair rewrites the file to the valid prefix), so an append
/ can never strand entries behind undecodable bytes.
/ Functions return (1;value) or (0;reason) as in earlier layers,
/ except wIsWal/wSeqOk/wVerify, which return raw 0/1. Reasons:
/ type, shape, op, valid, gap, length, torn, plus any Layer 0/5
/ reason a frame or store check produces. Loading a missing
/ file is a Kona-level error (DOE), not a tagged failure, and is
/ a caller error by contract, as with sLoad: documented, not
/ tested.
wFTYPE:87

/ Op codes and symbols.
wOpCode:{[op] :[op~`put; 1; :[op~`commit; 2; :[op~`abort; 3; :[op~`ckpt; 4; 0]]]]}
wOpSym:{[c] :[c=1; `put; :[c=2; `commit; :[c=3; `abort; :[c=4; `ckpt; `bad]]]]}
wOpOk:{[op] (4=4:op)&((wOpCode[op])>0)}

/ The empty WAL: next seq 0, no entries.
wNew:(0;!0)

/ WAL structure validation (not seq consecutiveness; see wSeqOk).
wIsWal:{[w] :[(0=4:w)&(2=#w); wIsWalV[w]; 0]}
wIsWalV:{[w] :[(1=4:w[0])&(~(w[0]<0)); wIsWalE[w[1]]; 0]}
wIsWalE:{[es] :[(0=#es); 1; :[(0=4:es); &/(wEntryOk'es); 0]]}
wEntryOk:{[e] :[(0=4:e)&(4=#e); wEntryOkV[e]; 0]}
wEntryOkV:{[e] :[(1=4:e[0])&(~(e[0]<0)); :[(4=4:e[1])&(wOpOk[e[1]]); :[(1=4:e[2])&(~(e[2]< -1)); :[((-1)=4:e[3])|(0=#e[3]); wEntryData[e]; 0]; 0]; 0]; 0]}
wEntryData:{[e] :[e[1]~`put; (bUnframe[e[3]])[0]=1; (0=#e[3])]}

/ Seq consecutiveness: seqs are exactly 0..nextSeq-1 in order.
wSeqOk:{[w] :[wIsWal[w]; wSeqOkV[w]; 0]}
wSeqOkV:{[w] es:w[1]; :[(0=#es); w[0]=0; (w[0]=#es)&(&/({[e;i] e[0]=i}'[es;!#es]))]}

/ Append one entry. The seq is assigned, never supplied.
wAppend:{[w;op;txn;data] :[wIsWal[w]; wAppendV[w;op;txn;data]; (0;"shape")]}
wAppendV:{[w;op;txn;data] :[(4=4:op); :[wOpOk[op]; wAppendT[w;op;txn;data]; (0;"op")]; (0;"type")]}
wAppendT:{[w;op;txn;data] :[(1=4:txn)&(~(txn< -1)); wAppendD[w;op;txn;data]; (0;"type")]}
wAppendD:{[w;op;txn;data] :[(((-1)=4:data)|(0=#data)); wAppendE[w;op;txn;data]; (0;"type")]}
wAppendE:{[w;op;txn;data] :[op~`put; :[(bUnframe[data])[0]=1; (1;(w[0]+1;w[1],(,(w[0];op;txn;data)))); (0;"valid")]; :[(0=#data); (1;(w[0]+1;w[1],(,(w[0];op;txn;data)))); (0;"shape")]]}

/ Entry bytes and frames.
wEntryBytes:{[e] bEncU32[e[0]],(,wOpCode[e[1]]),bEncI32[e[2]],e[3]}
wFrameEntry:{[e] bFrame[wFTYPE;wEntryBytes[e]]}
wBytes:{[w] :[wIsWal[w]; (1;wBytesF[w[1]]); (0;"shape")]}
wBytesF:{[es] :[(0=#es); !0; ,/(wFrameEntry'es)]}

/ Decode one parsed frame into an entry, or a hard reason. A
/ leaf: it never recurses and never calls wScan, so wScan can
/ call it before its own direct recursive call.
wEntryOf:{[u;exp] :[~(u[1]~wFTYPE); (0;"type"); wEntryOfP[u;exp]]}
wEntryOfP:{[u;exp] pl:u[2]; :[(#pl)<9; (0;"length"); wEntryOfS[u;exp;pl]]}
wEntryOfS:{[u;exp;pl] :[bDecU32[4#pl]=exp; wEntryOfO[u;exp;pl]; (0;"gap")]}
wEntryOfO:{[u;exp;pl] op:wOpSym[pl[4]]; :[op~`bad; (0;"op"); wEntryOfD[u;exp;pl;op]]}
wEntryOfD:{[u;exp;pl;op] txn:bDecI32[4#(5 _ pl)]; dt:9 _ pl; :[(txn< -1); (0;"type"); :[op~`put; :[(bUnframe[dt])[0]=1; (1;(exp;op;txn;dt)); (0;"valid")]; :[(0=#dt); (1;(exp;op;txn;dt)); (0;"shape")]]]}

/ Scan bytes into entries. Direct self-recursion ONLY: this
/ function calls itself directly as the final branch value; no
/ helper sits between wScan and its recursive call (Kona voids
/ branch calls that repeat through another function). Locals
/ tot, u, e are computed before the chain and read only as
/ branch conditions and recursive-call arguments, never after
/ a recursive call. Computing u and e up front is safe: on
/ short or torn input bUnframe returns a failure triple, and
/ wEntryOf fails fast on the non-87 type byte a failure triple
/ carries, without indexing missing fields.
wScan:{[bs;acc;exp] tot:14+bFrameLen[bs]; u:bUnframe[tot#bs]; e:wEntryOf[u;exp]; :[(0=#bs); (1;((exp;acc);1)); :[(#bs)<14; (1;((exp;acc);0)); :[tot>#bs; (1;((exp;acc);0)); :[u[0]=0; (1;((exp;acc);0)); :[e[0]=0; e; wScan[(tot _ bs);acc,(,e[1]);exp+1]]]]]]}

/ Recover a WAL from flat bytes. Success is (1;(wal;clean)):
/ clean 1 means every byte parsed as consecutive entries, clean
/ 0 means replay stopped at a torn tail and wal holds the valid
/ prefix. Hard reasons (type, gap, op, length, valid, shape)
wRecover:{[bs] :[((-1)=4:bs)|(0=#bs); wScan[bs;!0;0]; (0;"type")]}
wVerify:{[bs] r:wRecover[bs]; :[r[0]=0; 0; r[1][1]]}

/ Apply every `put entry of a WAL to a store, in log order.
/ Markers are skipped: Layer 8 replay is unfiltered, and
/ Layer 9 adds transaction-aware filtering on top.
wApply:{[st;w] :[sIsStore[st]; wApplyV[st;w]; (0;"type")]}
wApplyV:{[st;w] :[wIsWal[w]; wApplyF[st;w[1]]; (0;"shape")]}
wApplyF:{[st;es] r:wApplyStep/((,(1;st)),es); :[r[0]=0; r; (1;r[1])]}
wApplyStep:{[acc;e] :[acc[0]=0; acc; wApplyStep2[acc;e]]}
wApplyStep2:{[acc;e] :[e[1]~`put; wApplyPut[acc;e]; acc]}
wApplyPut:{[acc;e] r:sPut[acc[1];e[3]]; :[r[0]=0; r; (1;r[1][0])]}

/ Checkpoint: fold the log into the store, return a fresh log.
wCheckpoint:{[st;w] :[sIsStore[st]; wCheckpointV[st;w]; (0;"type")]}
wCheckpointV:{[st;w] :[wIsWal[w]; wCheckpointF[st;w]; (0;"shape")]}
wCheckpointF:{[st;w] r:wApply[st;w]; :[r[0]=0; r; (1;(r[1];wNew))]}

/ Paths are symbols or char lists, as in Layer 5.
wPathOk:{[path] ((4=4:path)|((-3)=4:path))}

/ Save a WAL: full rewrite via 1: dyadic (not synced; see the
/ durability boundary in the header). Returns (1;path).
wSave:{[w;path] :[wIsWal[w]; wSaveV[w;path]; (0;"type")]}
wSaveV:{[w;path] :[wPathOk[path]; wSaveW[w;path]; (0;"type")]}
wSaveW:{[w;path] b:wBytes[w]; :[b[0]=0; b; wSaveP[path;b[1]]]}
wSaveP:{[path;bs] path 1: bs; (1;path)}

/ Load a WAL. The file must exist (caller error otherwise, as
/ with sLoad). Success is (1;(wal;clean)), the wRecover shape.
wLoad:{[path] :[wPathOk[path]; wLoadR[path]; (0;"type")]}
wLoadR:{[path] flat:1: path; wLoadV[flat]}
wLoadV:{[flat] :[((-1)=4:flat)|(0=#flat); wRecover[flat]; (0;"type")]}

/ Create an empty WAL file. 5: dyadic creates a missing file
/ and appends nothing to an existing one, so this is
/ idempotent; the file is synced by Kona's mechanism (header).
wCreateFile:{[path] :[wPathOk[path]; wCreateFileW[path]; (0;"type")]}
wCreateFileW:{[path] path 5: !0; (1;path)}

/ Append one entry to a WAL file via 5: dyadic (synced, see
/ header). The seq comes from the file's own log, so the file
/ must exist and its log must be clean: appending behind a
/ torn tail is refused with "torn" (repair first). Always
/ wLoad again after appending; never reuse a loaded value.
wAppendFile:{[path;op;txn;data] :[wPathOk[path]; wAppendFileL[path;op;txn;data]; (0;"type")]}
wAppendFileL:{[path;op;txn;data] ld:wLoad[path]; :[ld[0]=0; ld; wAppendFileC[path;op;txn;data;ld[1]]]}
wAppendFileC:{[path;op;txn;data;lc] :[lc[1]=1; wAppendFileW[path;op;txn;data;lc[0]]; (0;"torn")]}
wAppendFileW:{[path;op;txn;data;wal] r:wAppend[wal;op;txn;data]; :[r[0]=0; r; wAppendFileA[path;wal;op;txn;data]]}
wAppendFileA:{[path;wal;op;txn;data] e:(wal[0];op;txn;data); path 5: bFrame[wFTYPE;wEntryBytes[e]]; (1;path)}

/ Repair a torn WAL file: rewrite it to its valid prefix.
/ A clean file is left untouched. Returns (1;wal).
wRepair:{[path] :[wPathOk[path]; wRepairV[path]; (0;"type")]}
wRepairV:{[path] ld:wLoad[path]; :[ld[0]=0; ld; :[ld[1][1]=1; (1;ld[1][0]); wRepairW[path;ld[1][0]]]]}
wRepairW:{[path;wal] r:wSave[wal;path]; :[r[0]=0; r; (1;wal)]}
