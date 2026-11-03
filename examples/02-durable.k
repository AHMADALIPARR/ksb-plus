/ SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0
/ Copyright Ahmad Ali Parr
/ Durable database directory: transactions, WAL, commit, crash.
/ Run: scripts/ksb.sh examples/show.k examples/02-durable.k
/ then: ls demo.db; scripts/ksb.sh examples/show.k examples/03-recover.k

rec:{[s] bFrame[7;_ic s]}
txt:{[fr] _ci bUnframe[fr][2]}
z:."\\rm -rf demo.db"
db:dOpen["demo.db"][1]; say["== opened demo.db, generation ",($db[1]),", next txn id ",$db[3]]
t1:tPut[dBegin[db][1];rec["alice +100"]][1]; t1:tPut[t1;rec["bob +50"]][1]; say["== txn 0 holds 2 records, not committed yet"]
db:dCommit[db;t1][1]; say["== txn 0 committed (commit record written and synced to demo.db/w0.K)"]
t2:tPut[dBegin[db][1];rec["carol +75"]][1]; db:dCommit[db;t2][1]; say["== txn 1 committed; records in store: ",$dRecs[db][1]]
db:dCheckpoint[db][1]; say["== checkpoint: store saved as generation ",($db[1]),", WAL restarted"]
t3:tPut[dBegin[db][1];rec["dave +999"]][1]; say["== txn 0 of generation 1 started but never committed; now the process stops (crash)"]
