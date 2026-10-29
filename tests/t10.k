/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 10 tests. Run via run-tests.sh, which feeds the layer chain
/ src/l00.k through src/l10.k, then this file to Kona. Each chk
/ prints PASS name or FAIL name. The last line prints ALL PASS
/ only when every check passed. The counter uses indexed assignment
/ on a global 1-element list (see kona-notes: plain assignment
/ inside chk reads an uninitialized local).
/ Plans are Layer 2 objects; args are Layer 2 objects too (sym
/ objects for names and ops, int/flt/str/sym objects for values,
/ a list object of sym objects for projections). Single-element
/ arg lists and single-element payloads are enlisted with ,(...)
/ (a pair in parens is grouping, not enlist -- see kona-notes).
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
tab1:oTable[`id`val;(10 20 30;1.5 2.5 3.5)]
tabS:oTable[`id`nm;(1 2 3;`a`b`c)]
tabU:oTable[`id`val;(30 10 20;3.5 1.5 2.5)]
sp1:qSplitTable[tab1[1]]
wr1:qWrite[sNew;sp1[1]]
env1:wr1[1]
chk["filter-gt"; eExec[tab1[1];oPlan[`filter;((`sym;`val);(`sym;`gt);(`flt;2.0))][1]]; (1;oTable[`id`val;(20 30;2.5 3.5)][1])]
chk["filter-eq-int"; eExec[tab1[1];oPlan[`filter;((`sym;`id);(`sym;`eq);(`int;20))][1]]; (1;oTable[`id`val;(,20;,2.5)][1])]
chk["filter-lt"; eExec[tab1[1];oPlan[`filter;((`sym;`val);(`sym;`lt);(`flt;2.5))][1]]; (1;oTable[`id`val;(,10;,1.5)][1])]
chk["filter-ne-sym"; eExec[tabS[1];oPlan[`filter;((`sym;`nm);(`sym;`ne);(`sym;`b))][1]]; (1;oTable[`id`nm;(1 3;`a`c)][1])]
chk["filter-badcol"; eExec[tab1[1];oPlan[`filter;((`sym;`zz);(`sym;`gt);(`flt;1.0))][1]]; (0;"key")]
chk["filter-badop"; eExec[tab1[1];oPlan[`filter;((`sym;`val);(`sym;`xx);(`flt;1.0))][1]]; (0;"op")]
chk["filter-badvaltype"; eExec[tab1[1];oPlan[`filter;((`sym;`id);(`sym;`eq);(`sym;`b))][1]]; (0;"type")]
chk["filter-badargc"; eExec[tab1[1];oPlan[`filter;((`sym;`val);(`sym;`gt))][1]]; (0;"shape")]
chk["filter-store-env"; eExec[env1;oPlan[`filter;((`sym;`val);(`sym;`gt);(`flt;1.0))][1]]; (0;"shape")]
chk["project-one"; eExec[tab1[1];oPlan[`project;(,(`list;(,(`sym;`id))))][1]]; (1;oTable[(,`id);(,(10 20 30))][1])]
chk["project-reorder"; eExec[tab1[1];oPlan[`project;(,(`list;((`sym;`val);(`sym;`id))))][1]]; (1;oTable[`val`id;(1.5 2.5 3.5;10 20 30)][1])]
chk["project-badcol"; eExec[tab1[1];oPlan[`project;(,(`list;(,(`sym;`zz))))][1]]; (0;"key")]
chk["project-badargc"; eExec[tab1[1];oPlan[`project;((`list;(,(`sym;`id)));(`list;(,(`sym;`val))))][1]]; (0;"shape")]
chk["select-basic"; eExec[tab1[1];oPlan[`select;((`sym;`val);(`sym;`ge);(`flt;2.5);(`list;(,(`sym;`id))))][1]]; (1;oTable[(,`id);(,(20 30))][1])]
chk["select-badproj"; eExec[tab1[1];oPlan[`select;((`sym;`val);(`sym;`ge);(`flt;2.5);(`list;(,(`sym;`zz))))][1]]; (0;"key")]
chk["sort-asc"; eExec[tabU[1];oPlan[`sort;(,(`sym;`id))][1]]; (1;oTable[`id`val;(10 20 30;1.5 2.5 3.5)][1])]
chk["sort-desc"; eExec[tabU[1];oPlan[`sort;((`sym;`id);(`int;-1))][1]]; (1;oTable[`id`val;(30 20 10;3.5 2.5 1.5)][1])]
chk["sort-sym"; eExec[tabS[1];oPlan[`sort;(,(`sym;`nm))][1]]; (1;oTable[`id`nm;(1 2 3;`a`b`c)][1])]
chk["sort-badcol"; eExec[tabU[1];oPlan[`sort;(,(`sym;`zz))][1]]; (0;"key")]
chk["sort-baddir"; eExec[tabU[1];oPlan[`sort;((`sym;`id);(`int;0))][1]]; (0;"range")]
chk["sort-baddirtype"; eExec[tabU[1];oPlan[`sort;((`sym;`id);(`sym;`down))][1]]; (0;"type")]
chk["sort-badargc"; eExec[tabU[1];oPlan[`sort;((`sym;`id);(`int;-1);(`int;1))][1]]; (0;"shape")]
chk["limit-2"; eExec[tab1[1];oPlan[`limit;(,(`int;2))][1]]; (1;oTable[`id`val;(10 20;1.5 2.5)][1])]
chk["limit-0"; eExec[tab1[1];oPlan[`limit;(,(`int;0))][1]]; (1;oTable[`id`val;(!0;0#1.0 2.0)][1])]
chk["limit-big"; eExec[tab1[1];oPlan[`limit;(,(`int;99))][1]]; (1;tab1[1])]
chk["limit-neg"; eExec[tab1[1];oPlan[`limit;(,(`int;-1))][1]]; (0;"range")]
chk["limit-badtype"; eExec[tab1[1];oPlan[`limit;(,(`sym;`two))][1]]; (0;"type")]
chk["sort-empty"; eExec[oTable[`id`val;(!0;0#1.0 2.0)][1];oPlan[`sort;(,(`sym;`id))][1]]; (1;oTable[`id`val;(!0;0#1.0 2.0)][1])]
chk["limit-empty"; eExec[oTable[`id`val;(!0;0#1.0 2.0)][1];oPlan[`limit;(,(`int;5))][1]]; (1;oTable[`id`val;(!0;0#1.0 2.0)][1])]
rt1:oTable[`id`nm;(20 30;`b`c)]
chk["join-basic"; eExec[tab1[1];oPlan[`join;(rt1[1];(`sym;`id);(`sym;`id))][1]]; (1;oTable[`id`val`nm;(20 30;2.5 3.5;`b`c)][1])]
rt2:oTable[`cid`nm;(20 30;`b`c)]
chk["join-diffkey"; eExec[tab1[1];oPlan[`join;(rt2[1];(`sym;`id);(`sym;`cid))][1]]; (1;oTable[`id`val`nm;(20 30;2.5 3.5;`b`c)][1])]
rt3:oTable[`id`nm;(40 50;`d`e)]
chk["join-nomatch"; eExec[tab1[1];oPlan[`join;(rt3[1];(`sym;`id);(`sym;`id))][1]]; (1;oTable[`id`val`nm;(!0;0#1.0 2.0;0#`a`b)][1])]
ltD:oTable[`id`val;(20 20;1.5 2.5)]
rtD:oTable[`id`nm;(20 20;`b`c)]
chk["join-dupkeys"; eExec[ltD[1];oPlan[`join;(rtD[1];(`sym;`id);(`sym;`id))][1]]; (1;oTable[`id`val`nm;(20 20 20 20;1.5 1.5 2.5 2.5;`b`c`b`c)][1])]
rtK:oTable[`id`val;(20 30;9.5 8.5)]
chk["join-dupname"; eExec[tab1[1];oPlan[`join;(rtK[1];(`sym;`id);(`sym;`id))][1]]; (0;"key")]
chk["join-badleftkey"; eExec[tab1[1];oPlan[`join;(rt1[1];(`sym;`zz);(`sym;`id))][1]]; (0;"key")]
chk["join-badrightkey"; eExec[tab1[1];oPlan[`join;(rt1[1];(`sym;`id);(`sym;`zz))][1]]; (0;"key")]
chk["join-rightnottable"; eExec[tab1[1];oPlan[`join;((`int;5);(`sym;`id);(`sym;`id))][1]]; (0;"type")]
rtE:oTable[`id`nm;(!0;0#`a`b)]
chk["join-emptyright"; eExec[tab1[1];oPlan[`join;(rtE[1];(`sym;`id);(`sym;`id))][1]]; (1;oTable[`id`val`nm;(!0;0#1.0 2.0;0#`a`b)][1])]
chk["join-emptyleft"; eExec[oTable[`id`val;(!0;0#1.0 2.0)][1];oPlan[`join;(rt1[1];(`sym;`id);(`sym;`id))][1]]; (1;oTable[`id`val`nm;(!0;0#1.0 2.0;0#`a`b)][1])]
chk["scan-basic"; eExec[env1;oPlan[`scan;((`sym;`val);(`sym;`gt);(`flt;2.0);(`list;(,(`sym;`id))))][1]]; (1;oTable[(,`id);(,(20 30))][1])]
chk["scan-nomatch"; eExec[env1;oPlan[`scan;((`sym;`val);(`sym;`gt);(`flt;9.0);(`list;(,(`sym;`id))))][1]]; (1;oTable[(,`id);(,!0)][1])]
chk["scan-badcol"; eExec[env1;oPlan[`scan;((`sym;`zz);(`sym;`gt);(`flt;1.0);(`list;(,(`sym;`id))))][1]]; (0;"key")]
chk["scan-table-env"; eExec[tab1[1];oPlan[`scan;((`sym;`val);(`sym;`gt);(`flt;1.0);(`list;(,(`sym;`id))))][1]]; (0;"shape")]
chk["scan-badargc"; eExec[env1;oPlan[`scan;((`sym;`val);(`sym;`gt);(`flt;1.0))][1]]; (0;"shape")]
pipe1:(oPlan[`filter;((`sym;`val);(`sym;`gt);(`flt;1.0))][1];oPlan[`project;(,(`list;(,(`sym;`val))))][1])
chk["pipe-filter-project"; eExec[tab1[1];pipe1]; (1;oTable[(,`val);(,(1.5 2.5 3.5))][1])]
pipe2:(oPlan[`scan;((`sym;`val);(`sym;`gt);(`flt;1.0);(`list;((`sym;`id);(`sym;`val))))][1];oPlan[`sort;(,(`sym;`id))][1];oPlan[`limit;(,(`int;2))][1])
chk["pipe-scan-sort-limit"; eExec[env1;pipe2]; (1;oTable[`id`val;(10 20;1.5 2.5)][1])]
pipe3:(oPlan[`filter;((`sym;`val);(`sym;`gt);(`flt;1.0))][1];oPlan[`filter;((`sym;`zz);(`sym;`gt);(`flt;1.0))][1])
chk["pipe-midfail"; eExec[tab1[1];pipe3]; (0;"key")]
chk["exec-single-plan"; eExec[tab1[1];oPlan[`limit;(,(`int;1))][1]]; (1;oTable[`id`val;(,10;,1.5)][1])]
chk["exec-badplan"; eExec[tab1[1];5]; (0;"shape")]
chk["exec-emptylist"; eExec[tab1[1];!0]; (0;"shape")]
chk["exec-list-nonplan"; eExec[tab1[1];(oPlan[`limit;(,(`int;1))][1];5)]; (0;"shape")]
chk["exec-badop-plan"; eExec[tab1[1];(`plan;(`bogus;!0))]; (0;"op")]
:[0=FC[0]; "ALL PASS"; "FAILURES"]
