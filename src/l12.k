/ Layer 12: Q interface. Query text -> Layer 10 plan pipelines -> eExec.
/ Grammar. Keywords are lowercase and case-sensitive; identifiers are
/ case-sensitive. A query is one of:
/   select [cols] from t [where p,p,...]   cols: * or c1,c2,...; absent = *
/   exec col from t [where p,p,...]        returns the column raw vector
/   p := name op value
/   op := < <= = >= > != <>   (all map to Layer 10 predicate ops)
/   value := [-]int | [-]float | "string" | `symbol
/ Env is a list of (name;value) pairs; a value is a table object or a
/ (store;manifest) pair. Store envs push the first predicate down via
/ a Layer 10 scan plan; a store env with no predicate reads fully.
/ Errors: "parse" for rejected query text; "key" for an unknown table
/ name; every execution reason passes through from Layers 6/10.
/ Limits, all documented honestly: no escapes in string literals;
/ int literals at most 18 digits (a longer digit run is "parse");
/ floats need a leading digit (".5" is "parse"); no sort or limit
/ clause in Q text (use Layer 10 plans directly, or the SQL layer);
/ string predicate values parse but fail "type" at execution, because
/ Layer 6 has no string column type (see the Layer 10 limits).
/ Parsing is segment-based, not recursive descent: clause boundaries
/ are found by scanning for keywords, segments are sliced and
/ validated, so no mutual recursion exists in this layer at all.
/ Token values: word/string values are char lists; int/float values
/ are atoms; symbol values are symbols; punct values are char lists
/ (single-char puncts are enlisted at scan time, so every punct
/ comparison is list-to-list and can never shape-error).
uP_LT:(,"<")
uP_LE:"<="
uP_EQ:(,"=")
uP_GT:(,">")
uP_GE:">="
uP_NE:"!="
uP_NED:"<>"
uP_COMMA:(,",")
uP_LP:(,"(")
uP_RP:(,")")
uP_STAR:(,"*")
uP_DOT:(,".")
uP_MINUS:(,"-")
uDQ:_ci 34
uBT:_ci 96
uIsWs:{[c] d:_ic c; (d=9)|(d=10)|(d=13)|(d=32)}
uIsAlpha:{[c] d:_ic c; ((((~(d<65))&(~(90<d)))|((~(d<97))&(~(122<d))))|(d=95))}
uIsAlnum:{[c] (uIsAlpha[c])|(cIsDigit[c])}
uSkipWs:{[s;i] :[(i<#s); :[uIsWs[s[i]]; uSkipWs[s;i+1]; i]; i]}
uSpanN:{[nz;rest] :[(0=#nz); #rest; nz[0]]}
uSpanDig:{[s;i] rest:i _ s; ks:cIsDigit'rest; nz:&(~ks); n:uSpanN[nz;rest]; ((n#rest);i+n)}
uSpanId:{[s;i] rest:i _ s; ks:uIsAlnum'rest; nz:&(~ks); n:uSpanN[nz;rest]; ((n#rest);i+n)}
uStrEnd:{[s;i] rest:(i+1) _ s; qs:{[c] c=uDQ}'rest; ix:&qs; :[(0=#ix); #s; (i+1)+ix[0]]}
uScanStr:{[s;i] j:uStrEnd[s;i]; :[(j=#s); (0;"parse"); uScanStrV[s;i;j]]}
uScanStrV:{[s;i;j] c:(j-(i+1))#((i+1) _ s); (1;((`s;c);j+1))}
uScanSym:{[s;i] r:uSpanId[s;i+1]; :[(0=#r[0]); (0;"parse"); uScanSymV[r]]}
uScanSymV:{[r] y:`$r[0]; (1;((`y;y);r[1]))}
uScanNum:{[s;i] d:uSpanDig[s;i]; uScanNumF[s;d]}
uScanNumF:{[s;d] :[(d[1]<#s); :[s[d[1]]="."; uScanNumD[s;d]; uScanNumE[s;d[0];d[1]]]; uScanNumE[s;d[0];d[1]]]}
uScanNumD:{[s;d] f:uSpanDig[s;d[1]+1]; uScanNumE[s;(d[0],".",f[0]);f[1]]}
uScanNumE:{[s;mant;j] :[(j<#s); :[uIsExpStart[s[j]]; uScanNumX[s;mant;j]; uScanNumC[mant;j]]; uScanNumC[mant;j]]}
uIsExpStart:{[c] (c="e")|(c="E")}
uIsExpSign:{[c] (c="+")|(c="-")}
uScanNumX:{[s;mant;j] k:j+1; :[(k<#s); :[uIsExpSign[s[k]]; uScanNumX2[s;mant;j;k+1]; uScanNumX2[s;mant;j;k]]; uScanNumC[mant;j]]}
uScanNumX2:{[s;mant;j;k] d:uSpanDig[s;k]; :[(0=#d[0]); uScanNumC[mant;j]; uScanNumC[mant,((d[1]-j)#(j _ s));d[1]]]}
uScanNumC:{[mant;j] :[uHasDotExp[mant]; uScanNumFlt[mant;j]; uScanNumInt[mant;j]]}
uHasDotExp:{[m] ((m?".")<#m)|((m?"e")<#m)|((m?"E")<#m)}
uScanNumFlt:{[mant;j] v:cStrToFlt[mant]; :[v[0]=0; (0;"parse"); (1;((`f;v[1]);j))]}
uScanNumInt:{[mant;j] :[(#mant)>18; (0;"parse"); (1;((`i;cDigitsVal[mant]);j))]}
uScanWord:{[s;i] r:uSpanId[s;i]; (1;((`w;r[0]);r[1]))}
uScanOp:{[s;i] c:s[i]; :[c=","; (1;((`p;uP_COMMA);i+1)); :[c="("; (1;((`p;uP_LP);i+1)); :[c=")"; (1;((`p;uP_RP);i+1)); :[c="*"; (1;((`p;uP_STAR);i+1)); :[c="<"; uScanOpLt[s;i]; :[c=">"; uScanOpGt[s;i]; :[c="="; (1;((`p;uP_EQ);i+1)); :[c="!"; uScanOpNe[s;i]; :[c="-"; (1;((`p;uP_MINUS);i+1)); :[c="."; (1;((`p;uP_DOT);i+1)); (0;"parse")]]]]]]]]]]}
uScanOpLt:{[s;i] :[((i+1)<#s); :[s[i+1]="="; (1;((`p;uP_LE);i+2)); :[s[i+1]=">"; (1;((`p;uP_NED);i+2)); (1;((`p;uP_LT);i+1))]]; (1;((`p;uP_LT);i+1))]}
uScanOpGt:{[s;i] :[((i+1)<#s); :[s[i+1]="="; (1;((`p;uP_GE);i+2)); (1;((`p;uP_GT);i+1))]; (1;((`p;uP_GT);i+1))]}
uScanOpNe:{[s;i] :[((i+1)<#s); :[s[i+1]="="; (1;((`p;uP_NE);i+2)); (0;"parse")]; (0;"parse")]}
uTokOne:{[s;i] c:s[i]; :[c=uDQ; uScanStr[s;i]; :[c=uBT; uScanSym[s;i]; :[cIsDigit[c]; uScanNum[s;i]; :[uIsAlpha[c]; uScanWord[s;i]; uScanOp[s;i]]]]]}
uTokLoop:{[s;i;acc] i2:uSkipWs[s;i]; :[(i2<#s); uTokLoopS[s;i2;acc]; (1;acc)]}
uTokLoopS:{[s;i;acc] r:uTokOne[s;i]; :[r[0]=0; r; uTokLoop[s;r[1][1];acc,(,r[1][0])]]}
uTok:{[s] :[(3=4:s); uTokLoop[(,s);0;!0]; :[(-3)=4:s; uTokLoop[s;0;!0]; (0;"parse")]]}
uLowerC:{[c] d:_ic c; :[((~(d<65))&(~(90<d))); _ci d+32; c]}
uLower:{[s] uLowerC's}
uWordEq:{[t;w;ci] :[(t[0]~`w); :[ci=1; (uLower[t[1]])~w; t[1]~w]; 0]}
uFindWord:{[t;i;w;ci] :[(i<#t); :[uWordEq[t[i];w;ci]; i; uFindWord[t;i+1;w;ci]]; #t]}
uPC:{[p] :[(3=4:p); (,p); p]}
uIsWord:{[t;w] :[(t[0]~`w); t[1]~w; 0]}
uIsPunct:{[t;p] :[(t[0]~`p); t[1]~(uPC[p]); 0]}
uOpFor:{[p] q:uPC[p]; :[q~uP_LT; (1;`lt); :[q~uP_LE; (1;`le); :[q~uP_EQ; (1;`eq); :[q~uP_GE; (1;`ge); :[q~uP_GT; (1;`gt); :[q~uP_NE; (1;`ne); :[q~uP_NED; (1;`ne); (0;"parse")]]]]]]]}
uIsSep:{[tok;kind] :[kind~`comma; uIsPunct[tok;uP_COMMA]; uIsAnd[tok]]}
uIsAnd:{[tok] uWordEq[tok;"and";1]}
uSplitStep:{[acc;tok] :[uIsSep[tok;acc[2]]; (acc[0],(,acc[1]);!0;acc[2]); (acc[0];acc[1],(,tok);acc[2])]}
uSplitSep:{[toks;kind] r:uSplitStep/((,( !0;!0;kind)),toks); (r[0],(,r[1]))}
uLitObj:{[tok] :[(tok[0]~`i); oInt[tok[1]]; :[(tok[0]~`f); oFlt[tok[1]]; :[(tok[0]~`s); oStr[tok[1]]; :[(tok[0]~`y); oSym[tok[1]]; (0;"parse")]]]]}
uLitObjP:{[tok] r:uLitObj[tok]; :[r[0]=0; (0;"parse"); r]}
uPredVal:{[toks] :[(#toks)=1; uLitObjP[toks[0]]; :[(#toks)=2; uPredValNeg[toks]; (0;"parse")]]}
uPredValNeg:{[toks] :[uIsPunct[toks[0];uP_MINUS]; uPredValNegV[toks[1]]; (0;"parse")]}
uPredValNegV:{[tok] :[(tok[0]~`i); oInt[-(tok[1])]; :[(tok[0]~`f); oFlt[-(tok[1])]; (0;"parse")]]}
uPredGroup:{[g] n:#g; :[((n=3)|(n=4)|(n=5)|(n=6)); uPredGroupV[g;n]; (0;"parse")]}
uPredGroupV:{[g;n] :[uIsPunct[g[1];uP_DOT]; uPredGroupQ[g;n]; uPredGroupU[g;n]]}
uPredGroupQ:{[g;n] :[(g[0][0]~`w); :[(g[2][0]~`w); uPredGroupQ2[g;n]; (0;"parse")]; (0;"parse")]}
uPredGroupQ2:{[g;n] :[(g[3][0]~`p); uPredGroupQ3[g;n]; (0;"parse")]}
uPredGroupQ3:{[g;n] r:uOpFor[g[3][1]]; :[r[0]=0; r; uPredGroupQ4[g;n;r[1]]]}
uPredGroupQ4:{[g;n;op] rest:(n-4)#(4 _ g); v:uPredVal[rest]; :[v[0]=0; v; (1;(((`$g[0][1];`$g[2][1]);op;v[1])))]}
uPredGroupU:{[g;n] :[(g[0][0]~`w); uPredGroupU2[g;n]; (0;"parse")]}
uPredGroupU2:{[g;n] :[(g[1][0]~`p); uPredGroupU3[g;n]; (0;"parse")]}
uPredGroupU3:{[g;n] r:uOpFor[g[1][1]]; :[r[0]=0; r; uPredGroupU4[g;n;r[1]]]}
uPredGroupU4:{[g;n;op] rest:(n-2)#(2 _ g); v:uPredVal[rest]; :[v[0]=0; v; (1;(((0;`$g[0][1]);op;v[1])))]}
uParsePreds:{[groups] rs:uPredGroup'groups; :[cEOk[rs]; (1;qVals[rs]); cEFirstErr[rs]]}
uAllWordT:{[ts] :[(0=#ts); 1; &/(uIsWordT'ts)]}
uIsWordT:{[t] t[0]~`w}
uAllPunctC:{[ts] :[(0=#ts); 1; &/(uIsPunctC'ts)]}
uIsPunctC:{[t] uIsPunct[t;uP_COMMA]}
uSymOf:{[t] `$t[1]}
uParseColsQ:{[seg] :[(0=#seg); (0;"parse"); uParseColsQ1[seg]]}
uParseColsQ1:{[seg] :[((#seg)=1)&(uIsPunct[seg[0];uP_STAR]); (1;`allcols); uParseColsQV[seg]]}
uParseColsQV:{[seg] n:#seg; odd:(n-(2*(n%2)))=1; :[odd; uParseColsQW[seg]; (0;"parse")]}
uParseColsQW:{[seg] idx:!#seg; ev:{[p] (p-(2*(p%2)))=0}'idx; nm:seg[&ev]; cm:seg[&(1-ev)]; :[(uAllWordT[nm])&(uAllPunctC[cm]); (1;uSymOf'nm); (0;"parse")]}
uParseQ:{[toks] :[(0=#toks); (0;"parse"); uParseQ1[toks]]}
uParseQ1:{[toks] :[uIsWord[toks[0];"select"]; uParseQSel[toks]; :[uIsWord[toks[0];"exec"]; uParseQExec[toks]; (0;"parse")]]}
uParseQSel:{[toks] fi:uFindWord[toks;1;"from";0]; :[(fi<#toks); uParseQSel2[toks;fi]; (0;"parse")]}
uParseQSel2:{[toks;fi] seg:(fi-1)#(1 _ toks); :[(0=#seg); uParseQSel3[toks;fi;`allcols]; uParseQSelC[toks;fi;seg]]}
uParseQSelC:{[toks;fi;seg] r:uParseColsQ[seg]; :[r[0]=0; r; uParseQSel3[toks;fi;r[1]]]}
uParseQSel3:{[toks;fi;cols] ti:fi+1; :[(ti<#toks); uParseQSel4[toks;ti;cols]; (0;"parse")]}
uParseQSel4:{[toks;ti;cols] :[(toks[ti][0]~`w); uParseQSel5[toks;ti;cols]; (0;"parse")]}
uParseQSel5:{[toks;ti;cols] tab:`$toks[ti][1]; ri:ti+1; :[(ri=#toks); (1;((`select;tab;cols;!0;0))); :[uIsWord[toks[ri];"where"]; uParseQSelW[toks;ri;tab;cols]; (0;"parse")]]}
uParseQSelW:{[toks;ri;tab;cols] seg:(ri+1) _ toks; :[(0=#seg); (0;"parse"); uParseQSelW2[seg;tab;cols]]}
uParseQSelW2:{[seg;tab;cols] gs:uSplitSep[seg;`comma]; r:uParsePreds[gs]; :[r[0]=0; r; uParseQSelW3[r[1];tab;cols]]}
uParseQSelW3:{[preds;tab;cols] qs:uPredQCol'preds; :[cEOk[qs]; (1;((`select;tab;cols;qVals[qs];0))); cEFirstErr[qs]]}
uPredQCol:{[p] :[(1=4:p[0][0]); (1;(p[0][1];p[1];p[2])); (0;"parse")]}
uParseQExec:{[toks] :[(#toks)<4; (0;"parse"); uParseQExec2[toks]]}
uParseQExec2:{[toks] :[(toks[1][0]~`w); :[uIsWord[toks[2];"from"]; :[(toks[3][0]~`w); uParseQExec3[toks]; (0;"parse")]; (0;"parse")]; (0;"parse")]}
uParseQExec3:{[toks] col:`$toks[1][1]; tab:`$toks[3][1]; ri:4; :[(ri=#toks); (1;((`exec;tab;`allcols;!0;col))); :[uIsWord[toks[ri];"where"]; uParseQExecW[toks;ri;tab;col]; (0;"parse")]]}
uParseQExecW:{[toks;ri;tab;col] seg:(ri+1) _ toks; :[(0=#seg); (0;"parse"); uParseQExecW2[seg;tab;col]]}
uParseQExecW2:{[seg;tab;col] gs:uSplitSep[seg;`comma]; r:uParsePreds[gs]; :[r[0]=0; r; uParseQExecW3[r[1];tab;col]]}
uParseQExecW3:{[preds;tab;col] qs:uPredQCol'preds; :[cEOk[qs]; (1;((`exec;tab;`allcols;qVals[qs];col))); cEFirstErr[qs]]}
uEnvFind:{[env;nm] :[(0=#env); (0;"key"); :[(env[0][0]~nm); (1;env[0][1]); uEnvFind[1 _ env;nm]]]}
uMkFilter:{[p] cs:oSym[p[0]]; os:oSym[p[1]]; :[cs[0]=0; cs; :[os[0]=0; os; oPlan[`filter;(cs[1];os[1];p[2])]]]}
uMkFilters:{[preds] rs:uMkFilter'preds; :[cEOk[rs]; (1;qVals[rs]); cEFirstErr[rs]]}
uMkProject:{[cols] rs:oSym'cols; :[cEOk[rs]; uMkProject2[qVals[rs]]; cEFirstErr[rs]]}
uMkProject2:{[syms] lo:oList[syms]; :[lo[0]=0; lo; oPlan[`project;(,lo[1])]]}
uMkScan:{[p;mncols] cs:oSym[p[0]]; os:oSym[p[1]]; :[cs[0]=0; cs; :[os[0]=0; os; uMkScan2[cs[1];os[1];p[2];mncols]]]}
uMkScan2:{[co;oo;vo;mncols] rs:oSym'mncols; :[cEOk[rs]; uMkScan3[co;oo;vo;qVals[rs]]; cEFirstErr[rs]]}
uMkScan3:{[co;oo;vo;syms] lo:oList[syms]; :[lo[0]=0; lo; oPlan[`scan;(co;oo;vo;lo[1])]]}
uIsScanPlan:{[p] :[(oKind[p]~`plan); uIsScanPlan2[p]; 0]}
uIsScanPlan2:{[p] r:oPlanOp[p]; :[r[0]=0; 0; r[1]~`scan]}
uRunEnv:{[envval;plans] :[(oKind[envval]~`table); :[(0=#plans); (1;envval); eExec[envval;plans]]; :[eIsStoreEnv[envval]; uRunStore[envval;plans]; (0;"shape")]]}
uRunStore:{[envval;plans] :[(0=#plans); qRead[envval[0];envval[1]]; :[uIsScanPlan[plans[0]]; eExec[envval;plans]; uRunStoreRead[envval;plans]]]}
uRunStoreRead:{[envval;plans] r:qRead[envval[0];envval[1]]; :[r[0]=0; r; eExec[r[1];plans]]}
uCompileQ:{[envval;parsed] kind:parsed[0]; :[kind~`select; uCompileSel[envval;parsed]; :[kind~`exec; uCompileExec[envval;parsed]; (0;"parse")]]}
uCompileSel:{[envval;parsed] cols:parsed[2]; preds:parsed[3]; :[(oKind[envval]~`table); uCompileTab[envval;cols;preds]; uCompileStore[envval;cols;preds]]}
uCompileTab:{[envval;cols;preds] f:uMkFilters[preds]; :[f[0]=0; f; uCompileTab2[f[1];cols]]}
uCompileTab2:{[fplans;cols] :[(4:cols)=4; (1;(fplans;0)); uCompileTab3[fplans;cols]]}
uCompileTab3:{[fplans;cols] p:uMkProject[cols]; :[p[0]=0; p; (1;(fplans,(,p[1]);0))]}
uCompileStore:{[envval;cols;preds] :[(0=#preds); uCompileStoreNP[envval;cols]; uCompileStoreP[envval;cols;preds]]}
uCompileStoreNP:{[envval;cols] :[(4:cols)=4; (1;(!0;0)); uCompileStoreNP2[envval;cols]]}
uCompileStoreNP2:{[envval;cols] p:uMkProject[cols]; :[p[0]=0; p; (1;((,p[1]);0))]}
uCompileStoreP:{[envval;cols;preds] mn:qNames[envval[1]]; :[mn[0]=0; mn; uCompileStoreP2[envval;cols;preds;mn[1]]]}
uCompileStoreP2:{[envval;cols;preds;mncols] s:uMkScan[preds[0];mncols]; :[s[0]=0; s; uCompileStoreP3[envval;cols;preds;s[1]]]}
uCompileStoreP3:{[envval;cols;preds;scan] f:uMkFilters[1 _ preds]; :[f[0]=0; f; uCompileStoreP4[cols;f[1];scan]]}
uCompileStoreP4:{[cols;fplans;scan] :[(4:cols)=4; (1;(((,scan),fplans);0)); uCompileStoreP5[cols;fplans;scan]]}
uCompileStoreP5:{[cols;fplans;scan] p:uMkProject[cols]; :[p[0]=0; p; (1;(((,scan),fplans,(,p[1]));0))]}
uCompileExec:{[envval;parsed] preds:parsed[3]; col:parsed[4]; :[(oKind[envval]~`table); uCompileExecT[envval;preds;col]; uCompileExecS[envval;preds;col]]}
uCompileExecT:{[envval;preds;col] f:uMkFilters[preds]; :[f[0]=0; f; (1;(f[1];col))]}
uCompileExecS:{[envval;preds;col] :[(0=#preds); (1;(!0;col)); uCompileExecS2[envval;preds;col]]}
uCompileExecS2:{[envval;preds;col] mn:qNames[envval[1]]; :[mn[0]=0; mn; uCompileExecS3[envval;preds;col;mn[1]]]}
uCompileExecS3:{[envval;preds;col;mncols] s:uMkScan[preds[0];mncols]; :[s[0]=0; s; uCompileExecS4[preds;col;s[1]]]}
uCompileExecS4:{[preds;col;scan] f:uMkFilters[1 _ preds]; :[f[0]=0; f; (1;(((,scan),f[1]);col))]}
uQRun:{[env;parsed] v:uEnvFind[env;parsed[1]]; :[v[0]=0; v; uQRunV[v[1];parsed]]}
uQRunV:{[envval;parsed] c:uCompileQ[envval;parsed]; :[c[0]=0; c; uQRunE[envval;c[1]]]}
uQRunE:{[envval;cp] r:uRunEnv[envval;cp[0]]; :[r[0]=0; r; uQRunX[r[1];cp[1]]]}
uQRunX:{[tab;execcol] :[(1=4:execcol); (1;tab); oCol[tab;execcol]]}
uQ:{[env;query] r:uTok[query]; :[r[0]=0; r; uQ2[env;r[1]]]}
uQ2:{[env;toks] p:uParseQ[toks]; :[p[0]=0; p; uQRun[env;p[1]]]}
