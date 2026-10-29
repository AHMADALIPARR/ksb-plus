/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 9: transactions/concurrency. A transaction is a value
/ (id;status;snapVer;work;entries): id is an int >= 0, status is
/ 0 open, 1 committed, 2 aborted, snapVer is the store version
/ the transaction began on, work is the transaction's private
/ working store, entries are its buffered `put records as
/ (op;txn;data) triples (no seq; seqs are assigned when the
/ entries reach the global WAL at commit).
/ CONCURRENCY MODEL (single-writer optimistic concurrency, no
/ locks): the shared store carries a version counter, bumped
/ exactly on commit. A transaction reads from its snapshot
/ (the store as of begin) plus its own buffered writes, so reads
/ never block and never see another transaction's uncommitted
/ work. At commit, the transaction's snapshot version must
/ still equal the shared version; otherwise the commit fails
/ with "conflict" and the transaction's work is discarded --
/ first committer wins, at whole-store version granularity.
/ That granularity is coarse on purpose: any concurrent commit
/ conflicts, even one touching different records. It is
/ serializable and simple to reason about, and the loser retries
/ by beginning again on the new version. Kona is
/ single-threaded, so "concurrent" here means interleaved
/ begins and commits in one session, not threads; there is no
/ lock manager to build, and none is pretended.
/ A transaction's puts reach the global WAL only at commit
/ (buffered entries plus a `commit marker, in that order). An
/ abort appends only an `abort marker: the aborted puts never
/ reached the shared store, so there is nothing to undo. A
/ crashed transaction -- puts in the log with no commit marker
/ -- is likewise dropped by replay. tReplay is therefore the
/ atomicity proof: it applies non-transactional puts always,
/ transactional puts only for txn ids that have a `commit
/ marker anywhere in the log (two passes, so marker position
/ does not matter), and drops everything else.
/ CALLER CONTRACT: thread (store;version;wal) together. A
/ version match is the guard that the store is unchanged since
/ begin; mixing a store from one lineage with a version from
/ another breaks the guard and is a caller error, not a tagged
/ failure. A committed or aborted transaction value is dead:
/ puts and commits on it fail with "status"; only abort on an
/ open transaction succeeds, and aborting a dead one fails too.
/ Functions return (1;value) or (0;reason) as in earlier layers,
/ except tIsTxn, which returns raw 0/1. Reasons: type, shape,
/ status, conflict, valid, plus any Layer 5/8 reason a store or
/ WAL check produces. tCommit returns (1;(txn;store;version;
/ wal)): the committed transaction value (status 1), the new
/ shared store (the transaction's work store), the bumped
/ version, and the WAL with the transaction's puts plus its
/ commit marker appended.

/ Transaction structure validation. Entries are `put triples
/ owned by this txn, each carrying a valid frame.
tIsTxn:{[t] :[(0=4:t)&(5=#t); tIsTxnV[t]; 0]}
tIsTxnV:{[t] :[(1=4:t[0]); :[~(t[0]<0); tIsTxnV1[t]; 0]; 0]}
tIsTxnV1:{[t] :[(1=4:t[1]); :[ (~(t[1]<0))&(~(2<t[1])); tIsTxnV2[t]; 0]; 0]}
tIsTxnV2:{[t] :[(1=4:t[2]); :[~(t[2]<0); :[sIsStore[t[3]]; tIsTxnE[t[4];t[0]]; 0]; 0]; 0]}
tIsTxnE:{[es;id] :[(0=#es); 1; :[(0=4:es); &/(tEntryOk'[es;(#es)#id]); 0]]}
tEntryOk:{[e;id] :[(0=4:e)&(3=#e); tEntryOkV[e;id]; 0]}
tEntryOkV:{[e;id] :[e[0]~`put; :[(1=4:e[1]); :[e[1]=id; :[((-1)=4:e[2]); (bUnframe[e[2]])[0]=1; 0]; 0]; 0]; 0]}

/ Begin: snapshot the store and version, empty work entries.
tBegin:{[st;ver;id] :[sIsStore[st]; tBeginV[st;ver;id]; (0;"type")]}
tBeginV:{[st;ver;id] :[(1=4:ver); :[~(ver<0); tBeginW[st;ver;id]; (0;"type")]; (0;"type")]}
tBeginW:{[st;ver;id] :[(1=4:id); :[~(id<0); (1;(id;0;ver;st;!0)); (0;"type")]; (0;"type")]}

/ Accessors. Each validates the transaction first.
tId:{[t] :[tIsTxn[t]; (1;t[0]); (0;"shape")]}
tStatus:{[t] :[tIsTxn[t]; (1;t[1]); (0;"shape")]}
tVer:{[t] :[tIsTxn[t]; (1;t[2]); (0;"shape")]}

/ Buffer a put: apply it to the private work store (so reads
/ see the transaction's own writes) and record the entry. The
/ shared store is untouched until commit.
tPut:{[t;fr] :[tIsTxn[t]; tPutV[t;fr]; (0;"shape")]}
tPutV:{[t;fr] :[t[1]=0; tPutW[t;fr]; (0;"status")]}
tPutW:{[t;fr] :[((-1)=4:fr)|(0=#fr); tPutX[t;fr]; (0;"type")]}
tPutX:{[t;fr] :[(bUnframe[fr])[0]=1; tPutY[t;fr]; (0;"valid")]}
tPutY:{[t;fr] r:sPut[t[3];fr]; :[r[0]=0; r; (1;(t[0];0;t[2];r[1][0];t[4],(,(`put;t[0];fr))))]}

/ Reads see the snapshot plus the transaction's own writes.
tGet:{[t;pg;slot] :[tIsTxn[t]; sGet[t[3];pg;slot]; (0;"shape")]}
tRecs:{[t] :[tIsTxn[t]; sRecs[t[3]]; (0;"shape")]}

/ Commit: version guard, then append buffered puts plus the
/ commit marker to the WAL, and adopt the work store.
tCommit:{[t;st;ver;wal] :[tIsTxn[t]; tCommitV[t;st;ver;wal]; (0;"shape")]}
tCommitV:{[t;st;ver;wal] :[sIsStore[st]; tCommitW[t;st;ver;wal]; (0;"type")]}
tCommitW:{[t;st;ver;wal] :[(1=4:ver); tCommitX[t;st;ver;wal]; (0;"type")]}
tCommitX:{[t;st;ver;wal] :[wIsWal[wal]; tCommitY[t;st;ver;wal]; (0;"shape")]}
tCommitY:{[t;st;ver;wal] :[t[1]=0; tCommitZ[t;st;ver;wal]; (0;"status")]}
tCommitZ:{[t;st;ver;wal] :[ver=t[2]; tCommitC[t;st;ver;wal]; (0;"conflict")]}
tCommitC:{[t;st;ver;wal] :[sValid[t[3]]; tCommitF[t;st;ver;wal]; (0;"valid")]}
tCommitF:{[t;st;ver;wal] r:tCommitFold[t;wal]; :[r[0]=0; r; tCommitM[t;st;ver;r[1]]]}
tCommitFold:{[t;wal] tCommitStep/((,(1;wal)),t[4])}
tCommitStep:{[acc;e] :[acc[0]=0; acc; wAppend[acc[1];e[0];e[1];e[2]]]}
tCommitM:{[t;st;ver;wal] m:wAppend[wal;`commit;t[0];!0]; :[m[0]=0; m; (1;((t[0];1;t[2];t[3];t[4]);t[3];ver+1;m[1]))]}

/ Abort: mark the transaction dead and audit the abort in the
/ WAL. The buffered puts are discarded, never appended.
tAbort:{[t;wal] :[tIsTxn[t]; tAbortV[t;wal]; (0;"shape")]}
tAbortV:{[t;wal] :[wIsWal[wal]; tAbortW[t;wal]; (0;"shape")]}
tAbortW:{[t;wal] :[t[1]=0; tAbortX[t;wal]; (0;"status")]}
tAbortX:{[t;wal] m:wAppend[wal;`abort;t[0];!0]; :[m[0]=0; m; (1;((t[0];2;t[2];t[3];t[4]);m[1]))]}

/ Replay a WAL into a store, transaction-aware. Pass 1 collects
/ committed txn ids; pass 2 applies non-transactional puts
/ always and transactional puts only for committed ids.
tReplay:{[st;wal] :[sIsStore[st]; tReplayV[st;wal]; (0;"type")]}
tReplayV:{[st;wal] :[wIsWal[wal]; tReplayF[st;wal]; (0;"shape")]}
tReplayF:{[st;wal] comm:tCommitted[wal[1]]; r:tReplayStep/((,(1;st;comm)),wal[1]); :[r[0]=0; (0;r[1]); (1;r[1])]}
tCommitted:{[es] tCommStep/((,!0),es)}
tCommStep:{[acc;e] :[e[1]~`commit; acc,(,e[2]); acc]}
tReplayStep:{[acc;e] :[acc[0]=0; acc; tReplayStep2[acc;e]]}
tReplayStep2:{[acc;e] :[e[1]~`put; tReplayStep3[acc;e]; acc]}
tReplayStep3:{[acc;e] :[(e[2]=-1)|(((acc[2]?e[2])<#acc[2])); tReplayPut[acc;e]; acc]}
tReplayPut:{[acc;e] r:sPut[acc[1];e[3]]; :[r[0]=0; (0;r[1];acc[2]); (1;r[1][0];acc[2])]}
