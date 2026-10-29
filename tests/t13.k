/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 13 tests. Run via run-tests.sh, which feeds the layer chain
/ src/l00.k through src/l13.k, then this file to Kona. Each chk
/ prints PASS name or FAIL name. The last line prints ALL PASS
/ only when every check passed. The counter uses indexed assignment
/ on a global 1-element list (see kona-notes: plain assignment
/ inside chk reads an uninitialized local).
/ SQL keywords are case-insensitive; identifiers are
/ case-sensitive. Env is a list of (name;value) pairs; enlist a
/ single pair with ,(...) -- a pair in parens alone is grouping,
/ not enlist (see kona-notes). A two-pair env needs no enlist:
/ ((`t;tab);(`u;rt)) is already a list of two pairs.
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
tab:oTable[`id`val`nm;(10 20 30;1.5 2.5 3.5;`a`b`c)]
tabJ:oTable[`id`val;(10 20 30;1.5 2.5 3.5)]
tabU:oTable[`id`val;(30 10 20;3.5 1.5 2.5)]
rt:oTable[`id`nm;(20 30 40;`b`c`d)]
rt2:oTable[`cid`nm;(20 30;`b`c)]
rtK:oTable[`id`val;(20 30;9.9 8.8)]
env:((`t;tab[1]);(`tj;tabJ[1]);(`u;rt[1]);(`u2;rt2[1]);(`uk;rtK[1]);(`tu;tabU[1]))
envT:(,(`t;tab[1]))
envU:(,(`tu;tabU[1]))
sp:qSplitTable[tab[1]]
wr:qWrite[sNew;sp[1]]
envS:(,(`s;wr[1]))
rtc:oTable[`id`city;(20 30;`x`y)]
envJ:((`s;wr[1]);(`u;rtc[1]))
chk["sql-basic"; zSQL[envT;"SELECT id, val FROM t WHERE val > 2.0"]; (1;oTable[`id`val;(20 30;2.5 3.5)][1])]
chk["sql-case-kw"; zSQL[envT;"SeLeCt id FrOm t"]; (1;oTable[(,`id);(,(10 20 30))][1])]
chk["sql-star"; zSQL[envT;"select * from t"]; (1;tab[1])]
chk["sql-where-and"; zSQL[envT;"select id from t where val > 1.0 and id < 30"]; (1;oTable[(,`id);(,(10 20))][1])]
chk["sql-where-case-and"; zSQL[envT;"select id from t WHERE val > 1.0 AND id < 30"]; (1;oTable[(,`id);(,(10 20))][1])]
chk["sql-where-qual"; zSQL[envT;"select id from t where t.id = 20"]; (1;oTable[(,`id);(,(,20))][1])]
chk["sql-order-asc"; zSQL[envU;"select id from tu order by val"]; (1;oTable[(,`id);(,(10 20 30))][1])]
chk["sql-order-desc"; zSQL[envU;"select id from tu order by val desc"]; (1;oTable[(,`id);(,(30 20 10))][1])]
chk["sql-order-qual"; zSQL[envU;"select id from tu order by tu.val desc"]; (1;oTable[(,`id);(,(30 20 10))][1])]
chk["sql-order-nonselected"; zSQL[envT;"select nm from t order by val desc"]; (1;oTable[(,`nm);(,(`c`b`a))][1])]
chk["sql-order-case"; zSQL[envU;"select id from tu ORDER BY val DESC"]; (1;oTable[(,`id);(,(30 20 10))][1])]
chk["sql-limit"; zSQL[envT;"select id from t limit 2"]; (1;oTable[(,`id);(,(10 20))][1])]
chk["sql-limit-0"; zSQL[envT;"select id from t limit 0"]; (1;oTable[(,`id);(,(!0))][1])]
chk["sql-order-limit"; zSQL[envU;"select id from tu order by val desc limit 2"]; (1;oTable[(,`id);(,(30 20))][1])]
chk["sql-where-order-limit"; zSQL[envT;"select id from t where val > 1.0 order by id desc limit 2"]; (1;oTable[(,`id);(,(30 20))][1])]
chk["sql-qual-cols"; zSQL[envT;"select t.id, t.nm from t"]; (1;oTable[`id`nm;(10 20 30;`a`b`c)][1])]
chk["sql-qual-bad"; zSQL[envT;"select zz.id from t"]; (0;"key")]
chk["sql-where-badqual"; zSQL[envT;"select id from t where zz.id = 1"]; (0;"key")]
chk["sql-order-badqual"; zSQL[envT;"select id from t order by zz.id"]; (0;"key")]
chk["sql-unknown-tab"; zSQL[envT;"select id from zz"]; (0;"key")]
chk["sql-unknown-col"; zSQL[envT;"select zz from t"]; (0;"key")]
chk["sql-unknown-predcol"; zSQL[envT;"select id from t where zz = 1"]; (0;"key")]
chk["sql-unknown-ordercol"; zSQL[envT;"select id from t order by zz"]; (0;"key")]
chk["sql-out-of-order"; zSQL[envT;"select id from t limit 1 order by id"]; (0;"parse")]
chk["sql-trailing"; zSQL[envT;"select id from t foo"]; (0;"parse")]
chk["sql-no-from"; zSQL[envT;"select id"]; (0;"parse")]
chk["sql-limit-neg"; zSQL[envT;"select id from t limit -1"]; (0;"parse")]
chk["sql-limit-float"; zSQL[envT;"select id from t limit 1.5"]; (0;"parse")]
chk["sql-limit-word"; zSQL[envT;"select id from t limit abc"]; (0;"parse")]
chk["sql-case-col"; zSQL[envT;"select ID from t"]; (0;"key")]
chk["sql-case-tab"; zSQL[envT;"SELECT ID FROM T"]; (0;"key")]
chk["sql-bad-agg-mix"; zSQL[envT;"select id, sum(val) from t"]; (0;"parse")]
chk["sql-agg-multi"; zSQL[envT;"select sum(val), count(*) from t"]; (0;"parse")]
chk["sql-agg-order"; zSQL[envT;"select sum(val) from t order by val"]; (0;"parse")]
chk["sql-agg-limit"; zSQL[envT;"select sum(val) from t limit 1"]; (0;"parse")]
chk["sql-sum-star"; zSQL[envT;"select sum(*) from t"]; (0;"parse")]
chk["sql-bad-agg"; zSQL[envT;"select median(val) from t"]; (0;"parse")]
chk["sql-count-star"; zSQL[envT;"select count(*) from t"]; (1;oTable[(,`count);(,(,3))][1])]
chk["sql-count-col"; zSQL[envT;"select count(id) from t"]; (1;oTable[(,`count);(,(,3))][1])]
chk["sql-sum"; zSQL[envT;"select sum(val) from t"]; (1;oTable[(,`sum);(,(,7.5))][1])]
chk["sql-sum-where"; zSQL[envT;"select sum(val) from t where id >= 20"]; (1;oTable[(,`sum);(,(,6.0))][1])]
chk["sql-avg"; zSQL[envT;"select avg(id) from t"]; (1;oTable[(,`avg);(,(,20.0))][1])]
chk["sql-avg-float"; zSQL[envT;"select avg(val) from t"]; (1;oTable[(,`avg);(,(,2.5))][1])]
chk["sql-min-int"; zSQL[envT;"select min(id) from t"]; (1;oTable[(,`min);(,(,10))][1])]
chk["sql-max-float"; zSQL[envT;"select max(val) from t"]; (1;oTable[(,`max);(,(,3.5))][1])]
chk["sql-min-sym-type"; zSQL[envT;"select min(nm) from t"]; (0;"type")]
chk["sql-agg-qual"; zSQL[envT;"select sum(t.val) from t"]; (1;oTable[(,`sum);(,(,7.5))][1])]
chk["sql-agg-badqual"; zSQL[envT;"select sum(zz.val) from t"]; (0;"key")]
chk["sql-agg-badcol"; zSQL[envT;"select sum(zz) from t"]; (0;"key")]
chk["sql-agg-empty-sum"; zSQL[envT;"select sum(val) from t where id > 100"]; (1;oTable[(,`sum);(,(,0.0))][1])]
chk["sql-agg-empty-min"; zSQL[envT;"select min(val) from t where id > 100"]; (0;"empty")]
chk["sql-agg-empty-count"; zSQL[envT;"select count(*) from t where id > 100"]; (1;oTable[(,`count);(,(,0))][1])]
chk["sql-join-basic"; zSQL[env;"select tj.id, u.nm from tj join u on tj.id = u.id"]; (1;oTable[`id`nm;(20 30;`b`c)][1])]
chk["sql-join-rev"; zSQL[env;"select id, nm from tj join u on u.id = tj.id"]; (1;oTable[`id`nm;(20 30;`b`c)][1])]
chk["sql-join-unqual-cols"; zSQL[env;"select id, nm from tj join u on tj.id = u.id"]; (1;oTable[`id`nm;(20 30;`b`c)][1])]
chk["sql-join-where-order"; zSQL[env;"select id, nm from tj join u on tj.id = u.id where val > 2.0 order by nm desc"]; (1;oTable[`id`nm;(30 20;`c`b)][1])]
chk["sql-join-count"; zSQL[env;"select count(*) from tj join u on tj.id = u.id"]; (1;oTable[(,`count);(,(,2))][1])]
chk["sql-join-diffkey"; zSQL[env;"select id, nm from tj join u2 on tj.id = u2.cid"]; (1;oTable[`id`nm;(20 30;`b`c)][1])]
chk["sql-join-dup"; zSQL[env;"select * from t join uk on t.id = uk.id"]; (0;"key")]
chk["sql-join-badkey"; zSQL[env;"select id from tj join u on tj.id = u.zz"]; (0;"key")]
chk["sql-join-ne"; zSQL[env;"select id from tj join u on tj.id <> u.id"]; (0;"parse")]
chk["sql-join-unqual-on"; zSQL[env;"select id from tj join u on id = u.id"]; (0;"parse")]
chk["sql-join-unknown"; zSQL[env;"select id from tj join zz on tj.id = zz.id"]; (0;"key")]
chk["sql-store-scan-order"; zSQL[envS;"select id from s where val > 2.0 order by id desc"]; (1;oTable[(,`id);(,(30 20))][1])]
chk["sql-store-limit"; zSQL[envS;"select * from s where id >= 20 limit 1"]; (1;oTable[`id`val`nm;(,20;,2.5;,`b)][1])]
chk["sql-store-agg"; zSQL[envS;"select sum(val) from s"]; (1;oTable[(,`sum);(,(,7.5))][1])]
chk["sql-store-agg-where"; zSQL[envS;"select count(*) from s where val < 3.0"]; (1;oTable[(,`count);(,(,2))][1])]
chk["sql-store-order-nonselected"; zSQL[envS;"select nm from s order by val"]; (1;oTable[(,`nm);(,(`a`b`c))][1])]
chk["sql-store-join"; zSQL[envJ;"select s.id, u.city from s join u on s.id = u.id"]; (1;oTable[`id`city;(20 30;`x`y)][1])]
chk["sql-store-badcol"; zSQL[envS;"select zz from s"]; (0;"key")]
chk["sql-store-badpred"; zSQL[envS;"select id from s where zz = 1"]; (0;"key")]
:[0=FC[0]; "ALL PASS"; "FAILURES"]
