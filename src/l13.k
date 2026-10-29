/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 13: SQL subset (z prefix). Keywords case-insensitive,
/ identifiers case-sensitive. Fixed clause order:
/
/   SELECT collist FROM t [JOIN u ON q1.c1 = q2.c2]
/     [WHERE p [AND p ...]] [ORDER BY [q.]c [ASC|DESC]]
/     [LIMIT n]
/
/ collist is * alone, or comma-separated [q.]col items, or a
/ single aggregate COUNT|SUM|AVG|MIN|MAX([q.]col|*). An
/ aggregate must be the only item, and rejects ORDER BY and
/ LIMIT. JOIN is an inner equi-join via the Layer 10 join
/ plan; ON needs qualified names on both sides and = only,
/ in either order. WHERE predicates are AND-separated and
/ reuse the Layer 12 pred-group parser (qualified or not).
/ A qualifier must name a table in scope (FROM, or JOIN with
/ a join) or the query fails "key"; unknown tables fail
/ "key"; anything out of order or trailing fails "parse".
/ LIMIT n needs a non-negative int token (minus or float
/ fails "parse"). Aggregates map to Layer 6 ops
/ (COUNT count, SUM sum, AVG mean, MIN min, MAX max) and
/ return a 1-row 1-column table named count/sum/avg/min/max.
/ COUNT(*) uses oLen (row count); other aggregates use qAgg
/ on the post-pipeline table. Aggregate queries materialize
/ (no scan pushdown); plain queries push the first predicate
/ down via the Layer 12 store path. ORDER BY sorts before
/ projection, so it may name any filtered-table column.
/ Columns literally named like clause keywords (from, join,
/ where, order, limit, select) are not addressable in the
/ positions where the parser scans for those keywords.
/ Self-join by one name is rejected ("parse"): without
/ aliases the two sides are indistinguishable. Env form is
/ the Layer 12 env: a list of (name;value) pairs, values
/ table objects or (store;manifest) pairs.
zStF:{[st;ft] (`sql;ft;st[2];st[3];st[4];st[5];st[6];st[7];st[8])}
zStC:{[st;cols] (`sql;st[1];cols;st[3];st[4];st[5];st[6];st[7];st[8])}
zStP:{[st;preds] (`sql;st[1];st[2];preds;st[4];st[5];st[6];st[7];st[8])}
zStJ:{[st;jt;on] (`sql;st[1];st[2];st[3];jt;on;st[6];st[7];st[8])}
zStO:{[st;ob;dir] (`sql;st[1];st[2];st[3];st[4];st[5];ob;dir;st[8])}
zStL:{[st;lim] (`sql;st[1];st[2];st[3];st[4];st[5];st[6];st[7];lim)}
zAggSym:{[t] :[uWordEq[t;"count";1]; `count; :[uWordEq[t;"sum";1]; `sum; :[uWordEq[t;"avg";1]; `avg; :[uWordEq[t;"min";1]; `min; :[uWordEq[t;"max";1]; `max; 0]]]]]}
zParseColItem:{[it] n:#it; :[n=1; zParseColItemW[it]; :[n=3; zParseColItemQ[it]; :[(n=4)|(n=6); zParseColItemA[it;n]; (0;"parse")]]]}
zParseColItemW:{[it] :[(it[0][0]~`w); (1;(`col;0;`$it[0][1])); (0;"parse")]}
zParseColItemQ:{[it] :[(it[0][0]~`w); :[uIsPunct[it[1];uP_DOT]; :[(it[2][0]~`w); (1;(`col;`$it[0][1];`$it[2][1])); (0;"parse")]; (0;"parse")]; (0;"parse")]}
zParseColItemA:{[it;n] a:zAggSym[it[0]]; :[(4:a)=1; (0;"parse"); :[uIsPunct[it[1];uP_LP]; zParseColItemA2[it;n;a]; (0;"parse")]]}
zParseColItemA2:{[it;n;a] :[uIsPunct[it[n-1];uP_RP]; zParseColItemA3[it;n;a]; (0;"parse")]}
zParseColItemA3:{[it;n;a] :[n=4; zParseColItemA4[it;a]; zParseColItemA6[it;a]]}
zParseColItemA4:{[it;a] mid:it[2]; :[uIsPunct[mid;uP_STAR]; :[(a~`count); (1;(`agg;a;0;`star)); (0;"parse")]; :[(mid[0]~`w); (1;(`agg;a;0;`$mid[1])); (0;"parse")]]}
zParseColItemA6:{[it;a] :[(it[2][0]~`w); :[uIsPunct[it[3];uP_DOT]; :[(it[4][0]~`w); (1;(`agg;a;`$it[2][1];`$it[4][1])); (0;"parse")]; (0;"parse")]; (0;"parse")]}
zParseCols:{[seg] :[((#seg)=1)&(uIsPunct[seg[0];uP_STAR]); (1;`allcols); zParseColsL[seg]]}
zParseColsL:{[seg] items:uSplitSep[seg;`comma]; rs:zParseColItem'items; :[cEOk[rs]; zParseCols2[qVals[rs]]; cEFirstErr[rs]]}
zParseCols2:{[items] ag:zHasAgg[items]; :[ag; zParseColsAgg[items]; (1;(`cols;items))]}
zHasAgg:{[items] :[(0=#items); 0; |/({[it] it[0]~`agg}'items)]}
zParseColsAgg:{[items] :[(#items)=1; (1;items[0]); (0;"parse")]}
zNormOn:{[toks;ft;jt] :[(ft~jt); (0;"parse"); zNormOn2[toks;ft;jt]]}
zNormOn2:{[toks;ft;jt] q1:`$toks[0][1]; c1:`$toks[2][1]; q2:`$toks[4][1]; c2:`$toks[6][1]; :[(q1~ft)&(q2~jt); (1;(c1;c2)); :[(q1~jt)&(q2~ft); (1;(c2;c1)); zNormOn3[q1;q2;ft;jt]]]}
zNormOn3:{[q1;q2;ft;jt] :[((q1~ft)|(q1~jt))&((q2~ft)|(q2~jt)); (0;"parse"); (0;"key")]}
zScopePred:{[p;ctx] ft:ctx[0]; jt:ctx[1]; q:p[0][0]; :[(4:q)=1; (1;(p[0][1];p[1];p[2])); :[(q~ft); (1;(p[0][1];p[1];p[2])); :[((4:jt)=4)&(q~jt); (1;(p[0][1];p[1];p[2])); (0;"key")]]]}
zScopePreds:{[preds;ft;jt] ctxs:(#preds)#(,(ft;jt)); rs:zScopePred'[preds;ctxs]; :[cEOk[rs]; (1;qVals[rs]); cEFirstErr[rs]]}
zScopeCol:{[q;ft;jt] :[(4:q)=1; 1; :[(q~ft); 1; :[((4:jt)=4)&(q~jt); 1; 0]]]}
zColsStep:{[acc;it] :[acc[0]=0; acc; zColsStep2[acc;it]]}
zColsStep2:{[acc;it] q:it[1]; ok:zScopeCol[q;acc[2];acc[3]]; :[ok; (1;acc[1],(,it[2]);acc[2];acc[3]); (0;"key")]}
zColsToQ:{[cols;ft;jt] :[(4:cols)=4; (1;`allcols); zColsToQ2[cols[1];ft;jt]]}
zColsToQ2:{[items;ft;jt] r:zColsStep/((,(1;!0;ft;jt)),items); :[r[0]=0; (0;r[1]); (1;r[1])]}
zParseSQL:{[toks] :[(0=#toks); (0;"parse"); zParseSQL1[toks]]}
zParseSQL1:{[toks] :[uWordEq[toks[0];"select";1]; zPSel[toks;1;(`sql;0;0;!0;0;0;0;1;-1)]; (0;"parse")]}
zPSel:{[toks;i;st] fi:uFindWord[toks;i;"from";1]; :[(fi<#toks); zPSel2[toks;i;fi;st]; (0;"parse")]}
zPSel2:{[toks;i;fi;st] seg:(fi-i)#(i _ toks); :[(0=#seg); (0;"parse"); zPSel3[toks;fi;seg;st]]}
zPSel3:{[toks;fi;seg;st] r:zParseCols[seg]; :[r[0]=0; r; zPFrom[toks;fi+1;zStC[st;r[1]]]]}
zPFrom:{[toks;i;st] :[(i<#toks); :[(toks[i][0]~`w); zPJoinOrWhere[toks;i+1;zStF[st;`$toks[i][1]]]; (0;"parse")]; (0;"parse")]}
zPJoinOrWhere:{[toks;i;st] :[(i<#toks); :[uWordEq[toks[i];"join";1]; zPJoin[toks;i+1;st]; zPWhere[toks;i;st]]; zPWhere[toks;i;st]]}
zPJoin:{[toks;i;st] :[~((#toks)<(i+9)); zPJoin2[toks;i;st]; (0;"parse")]}
zPJoin2:{[toks;i;st] :[(toks[i][0]~`w); :[uWordEq[toks[i+1];"on";1]; zPJoinOn[toks;i;st]; (0;"parse")]; (0;"parse")]}
zPJoinOn:{[toks;i;st] ot:(7)#((i+2) _ toks); :[(ot[0][0]~`w); :[uIsPunct[ot[1];uP_DOT]; :[(ot[2][0]~`w); :[uIsPunct[ot[3];uP_EQ]; :[(ot[4][0]~`w); :[uIsPunct[ot[5];uP_DOT]; :[(ot[6][0]~`w); zPJoinOnN[toks;i;st;ot]; (0;"parse")]; (0;"parse")]; (0;"parse")]; (0;"parse")]; (0;"parse")]; (0;"parse")]; (0;"parse")]}
zPJoinOnN:{[toks;i;st;ot] r:zNormOn[ot;st[1];`$toks[i][1]]; :[r[0]=0; r; zPWhere[toks;i+9;zStJ[st;`$toks[i][1];r[1]]]]}
zPWhere:{[toks;i;st] :[(i<#toks); :[uWordEq[toks[i];"where";1]; zPWhere2[toks;i;st]; zPOrder[toks;i;st]]; zPOrder[toks;i;st]]}
zPWhere2:{[toks;i;st] oi:uFindWord[toks;i+1;"order";1]; li:uFindWord[toks;i+1;"limit";1]; end:((oi&li)&#toks); seg:(end-(i+1))#((i+1) _ toks); :[(0=#seg); (0;"parse"); zPWhere3[toks;end;seg;st]]}
zPWhere3:{[toks;end;seg;st] gs:uSplitSep[seg;`and]; r:uParsePreds[gs]; :[r[0]=0; r; zPWhere4[toks;end;r[1];st]]}
zPWhere4:{[toks;end;preds;st] r:zScopePreds[preds;st[1];st[4]]; :[r[0]=0; r; zPOrder[toks;end;zStP[st;r[1]]]]}
zPOrder:{[toks;i;st] :[(i<#toks); :[uWordEq[toks[i];"order";1]; zPOrder2[toks;i;st]; zPLimit[toks;i;st]]; zPLimit[toks;i;st]]}
zPOrder2:{[toks;i;st] :[~((#toks)<(i+2)); :[uWordEq[toks[i+1];"by";1]; zPOrder3[toks;i+2;st]; (0;"parse")]; (0;"parse")]}
zPOrder3:{[toks;i;st] :[(toks[i][0]~`w); zPOrder4[toks;i;st]; (0;"parse")]}
zPOrder4:{[toks;i;st] :[((i+1)<#toks); :[uIsPunct[toks[i+1];uP_DOT]; zPOrderQ[toks;i;st]; zPOrderD[toks;i+1;st;`$toks[i][1]]]; zPOrderD[toks;i+1;st;`$toks[i][1]]]}
zPOrderQ:{[toks;i;st] :[~((#toks)<(i+3)); :[(toks[i+2][0]~`w); zPOrderQ2[toks;i;st]; (0;"parse")]; (0;"parse")]}
zPOrderQ2:{[toks;i;st] q:`$toks[i][1]; :[zScopeCol[q;st[1];st[4]]; zPOrderD[toks;i+3;st;`$toks[i+2][1]]; (0;"key")]}
zPOrderD:{[toks;i;st;col] zPOrderD2[toks;i;st;col]}
zPOrderD2:{[toks;i;st;col] :[(i<#toks); :[uWordEq[toks[i];"asc";1]; zPLimit[toks;i+1;zStO[st;col;1]]; :[uWordEq[toks[i];"desc";1]; zPLimit[toks;i+1;zStO[st;col;-1]]; zPLimit[toks;i;zStO[st;col;1]]]]; zPLimit[toks;i;zStO[st;col;1]]]}
zPLimit:{[toks;i;st] :[(i<#toks); :[uWordEq[toks[i];"limit";1]; zPLimit2[toks;i;st]; zPEnd[toks;i;st]]; zPEnd[toks;i;st]]}
zPLimit2:{[toks;i;st] :[((i+1)<#toks); :[(toks[i+1][0]~`i); zPEnd[toks;i+2;zStL[st;toks[i+1][1]]]; (0;"parse")]; (0;"parse")]}
zPEnd:{[toks;i;st] :[(i=#toks); zPEnd2[st]; (0;"parse")]}
zPEnd2:{[st] :[zIsAgg[st[2]]; :[((4:st[6])=1)&(st[8]=-1); (1;st); (0;"parse")]; (1;st)]}
zIsAgg:{[cols] :[(4:cols)=4; 0; cols[0]~`agg]}
zMkSort:{[col;dir] cs:oSym[col]; :[cs[0]=0; cs; zMkSort2[cs[1];dir]]}
zMkSort2:{[co;dir] :[dir=1; oPlan[`sort;(,co)]; zMkSort3[co;dir]]}
zMkSort3:{[co;dir] ds:oInt[dir]; :[ds[0]=0; ds; oPlan[`sort;(co;ds[1])]]}
zMkSortOpt:{[ob;dir] :[(4:ob)=1; (1;0); zMkSort[ob;dir]]}
zMkLimit:{[n] ni:oInt[n]; :[ni[0]=0; ni; oPlan[`limit;(,ni[1])]]}
zMkLimitOpt:{[lim] :[lim=-1; (1;0); zMkLimit[lim]]}
zMkJoin:{[rt;on] lk:oSym[on[0]]; :[lk[0]=0; lk; zMkJoin2[rt;on;lk[1]]]}
zMkJoin2:{[rt;on;lkc] rk:oSym[on[1]]; :[rk[0]=0; rk; oPlan[`join;(rt;lkc;rk[1])]]}
zCat:{[plans;p] :[(1=4:p); plans; plans,(,p)]}
zToTable:{[v] :[(oKind[v]~`table); (1;v); :[eIsStoreEnv[v]; qRead[v[0];v[1]]; (0;"shape")]]}
zBuildTab:{[cols;preds;ob;dir;lim] f:uMkFilters[preds]; :[f[0]=0; f; zBuildTabS[f[1];cols;ob;dir;lim]]}
zBuildTabS:{[fplans;cols;ob;dir;lim] s:zMkSortOpt[ob;dir]; :[s[0]=0; s; zBuildTabP[zCat[fplans;s[1]];cols;lim]]}
zBuildTabP:{[plans;cols;lim] :[(4:cols)=4; zBuildTabL[plans;lim]; zBuildTabP2[plans;cols;lim]]}
zBuildTabP2:{[plans;cols;lim] p:uMkProject[cols]; :[p[0]=0; p; zBuildTabL[zCat[plans;p[1]];lim]]}
zBuildTabL:{[plans;lim] l:zMkLimitOpt[lim]; :[l[0]=0; l; (1;zCat[plans;l[1]])]}
zBuildStore:{[envval;cols;preds;ob;dir;lim] :[(0=#preds); zBuildStoreNP[cols;ob;dir;lim]; zBuildStoreP[envval;cols;preds;ob;dir;lim]]}
zBuildStoreNP:{[cols;ob;dir;lim] s:zMkSortOpt[ob;dir]; :[s[0]=0; s; zBuildStoreNPS[s[1];cols;lim]]}
zBuildStoreNPS:{[splan;cols;lim] plans:zCat[!0;splan]; :[(4:cols)=4; zBuildTabL[plans;lim]; zBuildStoreNPP[plans;cols;lim]]}
zBuildStoreNPP:{[plans;cols;lim] p:uMkProject[cols]; :[p[0]=0; p; zBuildTabL[zCat[plans;p[1]];lim]]}
zBuildStoreP:{[envval;cols;preds;ob;dir;lim] mn:qNames[envval[1]]; :[mn[0]=0; mn; zBuildStoreP2[envval;cols;preds;ob;dir;lim;mn[1]]]}
zBuildStoreP2:{[envval;cols;preds;ob;dir;lim;mncols] s:uMkScan[preds[0];mncols]; :[s[0]=0; s; zBuildStoreP3[cols;preds;ob;dir;lim;s[1]]]}
zBuildStoreP3:{[cols;preds;ob;dir;lim;scan] f:uMkFilters[1 _ preds]; :[f[0]=0; f; zBuildStoreP4[cols;ob;dir;lim;scan;f[1]]]}
zBuildStoreP4:{[cols;ob;dir;lim;scan;fplans] plans:(,scan),fplans; s:zMkSortOpt[ob;dir]; :[s[0]=0; s; zBuildStoreP5[cols;lim;zCat[plans;s[1]]]]}
zBuildStoreP5:{[cols;lim;plans] :[(4:cols)=4; zBuildTabL[plans;lim]; zBuildStoreP6[cols;lim;plans]]}
zBuildStoreP6:{[cols;lim;plans] p:uMkProject[cols]; :[p[0]=0; p; zBuildTabL[zCat[plans;p[1]];lim]]}
zBuildPlans:{[envval;cols;preds;ob;dir;lim] :[(oKind[envval]~`table); zBuildTab[cols;preds;ob;dir;lim]; zBuildStore[envval;cols;preds;ob;dir;lim]]}
zRunPlain:{[envval;st] r:zColsToQ[st[2];st[1];st[4]]; :[r[0]=0; r; zRunPlain2[envval;st;r[1]]]}
zRunPlain2:{[envval;st;cols] b:zBuildPlans[envval;cols;st[3];st[6];st[7];st[8]]; :[b[0]=0; b; uRunEnv[envval;b[1]]]}
zRunJoin:{[ltval;rtval;st] lt:zToTable[ltval]; :[lt[0]=0; lt; zRunJoin2[lt[1];rtval;st]]}
zRunJoin2:{[lt;rtval;st] rt:zToTable[rtval]; :[rt[0]=0; rt; zRunJoin3[lt;rt[1];st]]}
zRunJoin3:{[lt;rt;st] jp:zMkJoin[rt;st[5]]; :[jp[0]=0; jp; zRunJoin4[lt;jp[1];st]]}
zRunJoin4:{[lt;jplan;st] f:uMkFilters[st[3]]; :[f[0]=0; f; zRunJoin5[lt;(,jplan),f[1];st]]}
zRunJoin5:{[lt;plans;st] s:zMkSortOpt[st[6];st[7]]; :[s[0]=0; s; zRunJoin6[lt;zCat[plans;s[1]];st]]}
zRunJoin6:{[lt;plans;st] r:zColsToQ[st[2];st[1];st[4]]; :[r[0]=0; r; zRunJoin7[lt;plans;st;r[1]]]}
zRunJoin7:{[lt;plans;st;cols] :[(4:cols)=4; zRunJoinL[lt;plans;st]; zRunJoinP[lt;plans;st;cols]]}
zRunJoinP:{[lt;plans;st;cols] p:uMkProject[cols]; :[p[0]=0; p; zRunJoinL[lt;zCat[plans;p[1]];st]]}
zRunJoinL:{[lt;plans;st] l:zMkLimitOpt[st[8]]; :[l[0]=0; l; eExec[lt;zCat[plans;l[1]]]]}
zAggBaseJoin:{[ltval;rtval;on;preds] lt:zToTable[ltval]; :[lt[0]=0; lt; zAggBaseJoin2[lt[1];rtval;on;preds]]}
zAggBaseJoin2:{[lt;rtval;on;preds] rt:zToTable[rtval]; :[rt[0]=0; rt; zAggBaseJoin3[lt;rt[1];on;preds]]}
zAggBaseJoin3:{[lt;rt;on;preds] jp:zMkJoin[rt;on]; :[jp[0]=0; jp; zAggBaseJoin4[lt;jp[1];preds]]}
zAggBaseJoin4:{[lt;jplan;preds] f:uMkFilters[preds]; :[f[0]=0; f; eExec[lt;(,jplan),f[1]]]}
zAggBasePlain:{[envval;preds] :[(oKind[envval]~`table); zAggBaseTab[envval;preds]; zAggBaseStore[envval;preds]]}
zAggBaseTab:{[envval;preds] :[(0=#preds); (1;envval); zAggBaseTabF[envval;preds]]}
zAggBaseTabF:{[envval;preds] f:uMkFilters[preds]; :[f[0]=0; f; eExec[envval;f[1]]]}
zAggBaseStore:{[envval;preds] r:qRead[envval[0];envval[1]]; :[r[0]=0; r; zAggBaseTab[r[1];preds]]}
zAggWrap:{[tab;agg] ai:agg[0]; :[zScopeCol[ai[2];agg[1];agg[2]]; zAggWrap2[tab;ai[1];ai[3]]; (0;"key")]}
zAggWrap2:{[tab;aggsym;arg] :[(arg~`star); zAggWrapS[tab;aggsym]; zAggWrapC[tab;aggsym;arg]]}
zAggWrapS:{[tab;aggsym] n:oLen[tab]; :[n[0]=0; n; zAggWrapT[aggsym;n[1]]]}
zAggOp:{[s] :[s~`avg; `mean; s]}
zAggWrapC:{[tab;aggsym;arg] v:qAgg[tab;arg;zAggOp[aggsym]]; :[v[0]=0; v; zAggWrapT[aggsym;v[1]]]}
zAggWrapT:{[aggsym;val] tb:oTable[(,aggsym);(,(,val))]; :[tb[0]=0; tb; (1;tb[1])]}
zRunAggJ:{[envval;rtval;st] b:zAggBaseJoin[envval;rtval;st[5];st[3]]; :[b[0]=0; b; zAggWrap[b[1];(st[2];st[1];st[4])]]}
zRunAggP:{[envval;st] b:zAggBasePlain[envval;st[3]]; :[b[0]=0; b; zAggWrap[b[1];(st[2];st[1];st[4])]]}
zRun:{[env;st] v:uEnvFind[env;st[1]]; :[v[0]=0; v; zRun2[env;v[1];st]]}
zRun2:{[env;envval;st] :[zIsAgg[st[2]]; zRunAggV[env;envval;st]; :[(4:st[4])=4; zRunJoinV[env;envval;st]; zRunPlain[envval;st]]]}
zRunAggV:{[env;envval;st] :[(4:st[4])=4; zRunAggJ2[env;envval;st]; zRunAggP[envval;st]]}
zRunAggJ2:{[env;envval;st] v:uEnvFind[env;st[4]]; :[v[0]=0; v; zRunAggJ[envval;v[1];st]]}
zRunJoinV:{[env;envval;st] v:uEnvFind[env;st[4]]; :[v[0]=0; v; zRunJoin[envval;v[1];st]]}
zSQL:{[env;query] r:uTok[query]; :[r[0]=0; r; zSQL2[env;r[1]]]}
zSQL2:{[env;toks] p:zParseSQL[toks]; :[p[0]=0; p; zRun[env;p[1]]]}
