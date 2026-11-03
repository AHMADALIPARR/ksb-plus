/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Make a table, store it in pages, query it with Q and SQL.
/ Run: scripts/ksb.sh examples/show.k examples/01-tables.k

t:oTable[`id`px`sym;(1 2 3 4 5;10.5 11.0 9.75 12.25 10.0;`ibm`msft`ibm`aapl`msft)][1]
sp:qSplitTable[t][1]; w:qWrite[sNew;sp][1]; say["== table (Layer 2 object, kind ",($oKind[t]),")"]
show[t]
say["== stored column by column: ",($#sp[3])," column chunk lists, ",($#w[0])," page(s) of 4096 bytes"]
say["read back equals original: ",$qRead[w[0];w[1]][1]~t]
env:(,(`trades;t))
say["== Q:   select id,px from trades where px>10.0"]
show[uQ[env;"select id,px from trades where px>10.0"][1]]
say["== Q:   exec sym from trades where px<11.0"]
say[xJoin[$uQ[env;"exec sym from trades where px<11.0"][1]]]
say["== SQL: SELECT sym, px FROM trades WHERE px > 10.0 ORDER BY px DESC LIMIT 2"]
show[zSQL[env;"SELECT sym, px FROM trades WHERE px > 10.0 ORDER BY px DESC LIMIT 2"][1]]
say["== SQL: SELECT AVG(px) FROM trades"]
show[zSQL[env;"SELECT AVG(px) FROM trades"][1]]
say["== SQL error comes back as a value: ",$zSQL[env;"SELECT nope FROM trades"][1]]
