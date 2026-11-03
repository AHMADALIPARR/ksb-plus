/ SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0
/ Copyright Ahmad Ali Parr
/ Reopen demo.db after the crash in 02-durable.k and recover it.

txt:{[fr] _ci bUnframe[fr][2]}
db:dOpen["demo.db"][1]; say["== reopened demo.db: generation ",($db[1]),", next txn id ",$db[3]]
st:db[2]; say["== recovered records: ",$dRecs[db][1]]
pg:pParse[st[0]][1][3]; says[xSp'txt'pg]
say["== the uncommitted txn (dave +999) is not in the store, so it is gone"]
t4:tPut[dBegin[db][1];rec:bFrame[7;_ic "erin +20"]][1]; db:dCommit[db;t4][1]; say["== new txn ",($db[3]-1)," committed after recovery (ids count per WAL generation); records: ",$dRecs[db][1]]
z:."\\rm -rf demo.db"
