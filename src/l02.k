/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 2: object model. Every object is a general pair (kind;payload)
/ with a symbol kind code from the registry below. Constructors
/ validate their inputs and return (1;object) on success or
/ (0;reason) on failure; reasons are type, limit, shape, key,
/ valid, range, bounds, empty, op, overflow. Validators (oIsValid)
/ return 0/1 and check a whole object tree, including nesting
/ depth (kMAXDEPTH). Accessors return (1;value) or (0;reason) and
/ check kind plus the shape they touch; a fully untrusted object
/ must pass oIsValid first, since a hand-built pair with a right
/ kind code but a malformed payload is rejected by validators, not
/ by every accessor.
/ Kind codes are symbols, not ints, because K collapses
/ homogeneous pairs: (1;5) is an int list, not a general pair, so
/ an int kind code would make every int-atom object an int list
/ and break the object test. A symbol kind keeps every object
/ genuinely general, except one case: a symbol object (`sym;`ab)
/ is itself a symbol list. oIsObjPair therefore accepts a
/ 2-symbol list whose first element is a kind symbol as an
/ object. That reading is ambiguous by construction: the same
/ value as a dict key list or table name list is just symbols.
/ Callers must use oKind/oIsValid for objects and oIsSymList for
/ name lists, never both on the same value.
/ Depth is enforced by oIsValid, not by constructors: a
/ constructor validates each element from that element's own root,
/ and only a top-down oIsValid walk knows the final tree depth.
/ Length limits use the shared constants from Layer 1 (kMAXLEN,
/ kMAXCOLS, kMAXNAME, kMAXPAYLOAD, kMAXDEPTH).
/ Empty-collection typing is a Kona literal fact, not a choice:
/ !0 types as an int list, 0#1.0 2.0 as a float list, "" as a char
/ list, 0#`a`b as a symbol list, and no literal produces an empty
/ general list. Typed validators are therefore strict (an int
/ vector payload must be type -1), while general-list payloads
/ (object lists, dict values, plan args, txn ops) accept any empty
/ payload, since empty is empty regardless of its literal type.
/ Copy semantics: oCopy is identity. Kona copies on indexed
/ assignment (verified for lists and for pairs), so mutating a
/ copy never affects the original; oCopy documents that, it does
/ not implement a copy loop.
/ Dictionaries hold objects (tagged pairs) as values; tables hold
/ raw typed vectors as columns. That asymmetry is deliberate: a
/ dict is heterogeneous, a table column is homogeneous.
/ LIMITATION (honest): Kona manages all memory. There is no
/ custom physical-memory allocator in this layer, and none is
/ claimed: resource limits here are counts (lengths, columns,
/ names, payloads, depth), enforced by validation, not by
/ allocation control.
/ Kind registry: int, flt, str, sym, intvec, fltvec, list, dict,
/ table, time, intmat, fltmat, schema, plan, ref, txn.
oKInt:`int
oKFlt:`flt
oKStr:`str
oKSym:`sym
oKIntVec:`intvec
oKFltVec:`fltvec
oKList:`list
oKDict:`dict
oKTable:`table
oKTime:`time
oKIntMat:`intmat
oKFltMat:`fltmat
oKSchema:`schema
oKPlan:`plan
oKRef:`ref
oKTxn:`txn
oKindSyms:`int`flt`str`sym`intvec`fltvec`list`dict`table`time`intmat`fltmat`schema`plan`ref`txn
oKindLo:`int`flt`str`sym`intvec`fltvec`list`dict
oPlanOps:`select`filter`project`join`sort`limit`scan
/ Structural helpers. oKind is structural only: it reports the
/ kind symbol of a well-shaped pair, or `bad. Full validity is
/ oIsValid, which also checks payloads.
oIsPair:{[x] (0=4:x)&(2=#x)}
oIsTriple:{[x] (0=4:x)&(3=#x)}
oIsPair2:{[x] (2=#x)&(((0=4:x)|((-1)=4:x)))}
oIsTriple3:{[x] (3=#x)&(((0=4:x)|((-1)=4:x)))}
oIsObjPair:{[x] :[(0=4:x); (2=#x); :[(-4)=4:x; (2=#x)&(((oKindSyms?x[0])<16)); 0]]}
oKind:{[x] :[oIsObjPair[x]; oKindP[x]; `bad]}
oKindP:{[x] :[(4=4:x[0]); :[((oKindSyms?x[0])<16); x[0]; `bad]; `bad]}
oIsSymList:{[xs] :[(0=#xs); 1; (-4)=4:xs]}
oUniqueSyms:{[xs] (#xs)=#(?xs)}
oSymLens:{[ks] {#($x)}'ks}
oIsVecRawT:{[t] (t=-1)|(t=-2)|(t=-3)|(t=-4)}
oIsVecRaw:{[xs] :[(0=#xs); 1; oIsVecRawT[4:xs]]}
oAllValidStep:{[acc;x] :[acc[0]=0; acc; (oIsValidD[x;acc[1]];acc[1])]}
oAllValid:{[xs;d] (oAllValidStep/((,(1;d)),xs))[0]}
oIsValidD:{[x;d] :[d>kMAXDEPTH; 0; oIsValidK[oKind[x];x;d]]}
oIsValid:{[x] oIsValidD[x;0]}
oIsValidK:{[k;x;d] :[((oKindLo?k)<8); oIsValidLo[k;x;d]; oIsValidHi[k;x;d]]}
oIsValidLo:{[k;x;d] :[k~`int; vInt[x]; :[k~`flt; vFlt[x]; :[k~`str; vStr[x]; :[k~`sym; vSym[x]; :[k~`intvec; vIntVec[x]; :[k~`fltvec; vFltVec[x]; :[k~`list; vListD[x;d]; :[k~`dict; vDictD[x;d]; 0]]]]]]]]}
oIsValidHi:{[k;x;d] :[k~`table; vTable[x]; :[k~`time; vTime[x]; :[k~`intmat; vIntMat[x]; :[k~`fltmat; vFltMat[x]; :[k~`schema; vSchema[x]; :[k~`plan; vPlanD[x;d]; :[k~`ref; vRef[x]; :[k~`txn; vTxnD[x;d]; 0]]]]]]]]}
/ Validators. Each assumes oKind already reported its kind, so
/ x is a pair and x[1] exists. Comparisons and arithmetic sit
/ behind lazy type guards, because Kona & does not short-circuit.
vInt:{[x] (1=4:x[1])}
vFlt:{[x] (2=4:x[1])}
vStr:{[x] (-3)=4:x[1]}
vSym:{[x] (4=4:x[1])&(~(kMAXNAME<#($x[1])))}
vIntVec:{[x] (-1)=4:x[1]}
vFltVec:{[x] (-2)=4:x[1]}
vListD:{[x;d] :[(0=#x[1]); 1; :[(0=4:x[1]); oAllValid[x[1];d+1]; 0]]}
vDictD:{[x;d] :[oIsPair[x[1]]; vDictRest[x;d]; 0]}
vDictRest:{[x;d] ks:x[1][0]; vs:x[1][1]; :[~((4:ks)>0); vDictRestL[ks;vs;d]; 0]}
vDictRestL:{[ks;vs;d] (oIsSymList[ks])&(oUniqueSyms[ks])&((#ks)=(#vs))&(~(kMAXLEN<#ks))&(vDictKeyLens[ks])&(vDictVals[vs;d])}
vDictKeyLens:{[ks] :[(0=#ks); 1; ~((|/oSymLens[ks])>kMAXNAME)]}
vDictVals:{[vs;d] :[(0=#vs); 1; :[(0=4:vs); oAllValid[vs;d+1]; 0]]}
vTable:{[x] :[oIsPair[x[1]]; vTableRest[x]; 0]}
vTableRest:{[x] ns:x[1][0]; cs:x[1][1]; :[~((4:ns)>0); vTableRestL[ns;cs]; 0]}
vTableRestL:{[ns;cs] (oIsSymList[ns])&(oUniqueSyms[ns])&((#ns)=(#cs))&(~(0=#ns))&(~(kMAXCOLS<#ns))&(vDictKeyLens[ns])&(vTableCols[cs])}
vTableCols:{[cs] :[(0=#cs); 0; (oAllVecRaw[cs])&(oColsSameLen[cs])&(oColsLenOk[cs])]}
oAllVecRaw:{[cs] &/(oIsVecRaw'cs)}
oColsSameLen:{[cs] ls:{#x}'cs; (&/ls)=(|/ls)}
oColsLenOk:{[cs] ~((|/{#x}'cs)>kMAXLEN)}
vTime:{[x] :[oIsPair2[x[1]]; vTimeRest[x]; 0]}
vTimeRest:{[x] s:x[1][0]; v:x[1][1]; :[(1=4:s)&(1=4:v); :[(~(s<0))&(~(2<s)); :[(s=2); (~(v<0))&(v<86400000000000); 1]; 0]; 0]}
vIntMat:{[x] :[oIsTriple[x[1]]; vIntMatT[x[1]]; 0]}
vIntMatT:{[t] r:t[0]; c:t[1]; dt:t[2]; :[(1=4:r)&(1=4:c)&((-1)=4:dt); vIntMatRC[r;c;dt]; 0]}
vIntMatRC:{[r;c;dt] p:kChkMul[r;c]; :[p[0]=0; 0; :[(~(r<1))&(~(c<1)); :[(#dt)=p[1]; :[~((#dt)>kMAXLEN); 1; 0]; 0]; 0]]}
vFltMat:{[x] :[oIsTriple[x[1]]; vFltMatT[x[1]]; 0]}
vFltMatT:{[t] r:t[0]; c:t[1]; dt:t[2]; :[(1=4:r)&(1=4:c)&((-2)=4:dt); vFltMatRC[r;c;dt]; 0]}
vFltMatRC:{[r;c;dt] p:kChkMul[r;c]; :[p[0]=0; 0; :[(~(r<1))&(~(c<1)); :[(#dt)=p[1]; :[~((#dt)>kMAXLEN); 1; 0]; 0]; 0]]}
vSchema:{[x] fs:x[1]; :[((0=4:fs)|(0=#fs)); :[(0<#fs); :[~((#fs)>kMAXCOLS); :[oAllFields[fs]; :[((#({x[0]}'fs))=#(?({x[0]}'fs))); 1; 0]; 0]; 0]; 0]; 0]}
oFieldStep:{[acc;f] :[acc=0; 0; vField[f]]}
oAllFields:{[fs] oFieldStep/((,1),fs)}
vField:{[f] :[oIsTriple[f]; vFieldRest[f]; 0]}
vFieldRest:{[f] n:f[0]; t:f[1]; u:f[2]; :[(4=4:n)&(4=4:t)&(1=4:u); vFieldVals[n;t;u]; 0]}
vFieldVals:{[n;t;u] (~(kMAXNAME<#($n)))&(((oKindSyms?t)<16))&((u=0)|(u=1))}
vPlanD:{[x;d] :[oIsPair[x[1]]; vPlanRest[x;d]; 0]}
vPlanRest:{[x;d] op:x[1][0]; a:x[1][1]; :[(4=4:op); :[((oPlanOps?op)<7); :[((0=4:a)|(0=#a)); oAllValid[a;d+1]; 0]; 0]; 0]}
vRef:{[x] :[oIsTriple3[x[1]]; vRefRest[x]; 0]}
vRefRest:{[x] s:x[1][0]; o:x[1][1]; l:x[1][2]; :[(1=4:s)&(1=4:o)&(1=4:l); :[(~(s<0))&(~(o<0))&(~(l<0)); :[~(kMAXPAYLOAD<l); 1; 0]; 0]; 0]}
vTxnD:{[x;d] :[oIsTriple[x[1]]; vTxnRest[x;d]; 0]}
vTxnRest:{[x;d] id:x[1][0]; ops:x[1][1]; st:x[1][2]; :[(1=4:id)&(1=4:st); :[(~(id<0))&(~(st<0))&(~(2<st)); :[((0=4:ops)|(0=#ops)); oAllValid[ops;d+1]; 0]; 0]; 0]}
/ Constructors. Each returns (1;object) or (0;reason).
oInt:{[v] :[(1=4:v); (1;(oKInt;v)); (0;"type")]}
oFlt:{[v] :[(2=4:v); (1;(oKFlt;v)); (0;"type")]}
oStr:{[s] :[(-3)=4:s; :[~((#s)>kMAXLEN); (1;(oKStr;s)); (0;"limit")]; (0;"type")]}
oSym:{[y] :[(4=4:y); :[~((#($y))>kMAXNAME); (1;(oKSym;y)); (0;"limit")]; (0;"type")]}
oIntVec:{[xs] :[(-1)=4:xs; :[~((#xs)>kMAXLEN); (1;(oKIntVec;xs)); (0;"limit")]; (0;"type")]}
oFltVec:{[xs] :[(-2)=4:xs; :[~((#xs)>kMAXLEN); (1;(oKFltVec;xs)); (0;"limit")]; (0;"type")]}
oList:{[xs] :[((0=4:xs)|(0=#xs)); :[~((#xs)>kMAXLEN); :[oAllValid[xs;1]; (1;(oKList;xs)); (0;"valid")]; (0;"limit")]; (0;"type")]}
oDict:{[ks;vs] :[oIsSymList[ks]; :[((#ks)=(#vs)); :[~((#ks)>kMAXLEN); :[oUniqueSyms[ks]; :[vDictKeyLens[ks]; :[((0=4:vs)|(0=#vs)); :[oAllValid[vs;1]; (1;(oKDict;(ks;vs))); (0;"valid")]; (0;"type")]; (0;"limit")]; (0;"key")]; (0;"limit")]; (0;"shape")]; (0;"type")]}
oTable:{[ns;cs] :[oIsSymList[ns]; :[((#ns)=(#cs)); :[((0=4:cs)|(0=#cs)); :[(0<#ns); :[~((#ns)>kMAXCOLS); :[oUniqueSyms[ns]; :[vDictKeyLens[ns]; :[vTableCols[cs]; (1;(oKTable;(ns;cs))); (0;"shape")]; (0;"limit")]; (0;"key")]; (0;"limit")]; (0;"empty")]; (0;"type")]; (0;"shape")]; (0;"type")]}
oTime:{[s;v] :[(1=4:s)&(1=4:v); :[(~(s<0))&(~(2<s)); :[(s=2); :[(~(v<0))&(v<86400000000000); (1;(oKTime;(s;v))); (0;"range")]; (1;(oKTime;(s;v)))]; (0;"range")]; (0;"type")]}
oIntMat:{[r;c;dt] :[(1=4:r)&(1=4:c)&((-1)=4:dt); oIntMatC[r;c;dt]; (0;"type")]}
oIntMatC:{[r;c;dt] p:kChkMul[r;c]; :[p[0]=0; (0;"overflow"); :[(~(r<1))&(~(c<1)); :[((#dt)=p[1]); :[~((#dt)>kMAXLEN); (1;(oKIntMat;(r;c;dt))); (0;"limit")]; (0;"shape")]; (0;"range")]]}
oFltMat:{[r;c;dt] :[(1=4:r)&(1=4:c)&((-2)=4:dt); oFltMatC[r;c;dt]; (0;"type")]}
oFltMatC:{[r;c;dt] p:kChkMul[r;c]; :[p[0]=0; (0;"overflow"); :[(~(r<1))&(~(c<1)); :[((#dt)=p[1]); :[~((#dt)>kMAXLEN); (1;(oKFltMat;(r;c;dt))); (0;"limit")]; (0;"shape")]; (0;"range")]]}
oSchema:{[fs] :[((0=4:fs)|(0=#fs)); :[(0<#fs); :[~((#fs)>kMAXCOLS); :[oAllFields[fs]; :[((#({x[0]}'fs))=#(?({x[0]}'fs))); (1;(oKSchema;fs)); (0;"key")]; (0;"valid")]; (0;"limit")]; (0;"empty")]; (0;"type")]}
oPlan:{[op;a] :[(4=4:op); :[((oPlanOps?op)<7); :[((0=4:a)|(0=#a)); :[oAllValid[a;1]; (1;(oKPlan;(op;a))); (0;"valid")]; (0;"type")]; (0;"op")]; (0;"type")]}
oRef:{[s;o;l] :[(1=4:s)&(1=4:o)&(1=4:l); :[(~(s<0))&(~(o<0))&(~(l<0)); :[~(kMAXPAYLOAD<l); (1;(oKRef;(s;o;l))); (0;"limit")]; (0;"range")]; (0;"type")]}
oTxn:{[id;ops;st] :[(1=4:id)&(1=4:st); :[(~(id<0))&(~(st<0))&(~(2<st)); :[((0=4:ops)|(0=#ops)); :[oAllValid[ops;1]; (1;(oKTxn;(id;ops;st))); (0;"valid")]; (0;"type")]; (0;"range")]; (0;"type")]}
/ Accessors. Each returns (1;value) or (0;reason).
oLen:{[x] oLenK[oKind[x];x]}
oLenK:{[k;x] :[(k~`intvec)|(k~`fltvec)|(k~`str)|(k~`list); oLenV[x]; :[k~`dict; oLenDict[x]; :[k~`table; oLenTable[x]; (0;"type")]]]}
oLenV:{[x] v:x[1]; :[(((-1)=4:v)|((-2)=4:v)|((-3)=4:v)|(0=4:v)|(0=#v)); (1;#v); (0;"shape")]}
oLenDict:{[x] :[oIsPair[x[1]]; (1;#x[1][0]); (0;"shape")]}
oLenTable:{[x] :[oIsPair[x[1]]; oLenTableC[x]; (0;"shape")]}
oLenTableC:{[x] cs:x[1][1]; :[((0=4:cs)|(0=#cs)); :[(0=#cs); (1;0); (1;#cs[0])]; (0;"shape")]}
oGet:{[x;i] oGetK[oKind[x];x;i]}
oGetK:{[k;x;i] :[(k~`intvec)|(k~`fltvec)|(k~`str)|(k~`list); oGetV[x;i]; (0;"type")]}
oGetV:{[x;i] v:x[1]; :[(((-1)=4:v)|((-2)=4:v)|((-3)=4:v)|(0=4:v)|(0=#v)); :[(1=4:i); :[(~(i<0))&(i<#v); (1;v[i]); (0;"bounds")]; (0;"type")]; (0;"shape")]}
oDictGet:{[x;key] :[oKind[x]~`dict; :[oIsPair[x[1]]; oDictGetK[x;key]; (0;"shape")]; (0;"type")]}
oDictGetK:{[x;key] ks:x[1][0]; vs:x[1][1]; :[(oIsSymList[ks])&((0=4:vs)|(0=#vs))&((#ks)=(#vs)); :[(4=4:key); :[((ks?key)<#ks); (1;vs[ks?key]); (0;"key")]; (0;"type")]; (0;"shape")]}
oCol:{[x;nm] :[oKind[x]~`table; :[oIsPair[x[1]]; oColK[x;nm]; (0;"shape")]; (0;"type")]}
oColK:{[x;nm] ns:x[1][0]; cs:x[1][1]; :[(oIsSymList[ns])&((0=4:cs)|(0=#cs))&((#ns)=(#cs)); :[(4=4:nm); :[((ns?nm)<#ns); (1;cs[ns?nm]); (0;"key")]; (0;"type")]; (0;"shape")]}
oColAt:{[x;j] :[oKind[x]~`table; :[oIsPair[x[1]]; oColAtK[x;j]; (0;"shape")]; (0;"type")]}
oColAtK:{[x;j] cs:x[1][1]; :[((0=4:cs)|(0=#cs)); :[(1=4:j); :[(~(j<0))&(j<#cs); (1;cs[j]); (0;"bounds")]; (0;"type")]; (0;"shape")]}
oRow:{[x;i] :[oKind[x]~`table; :[oIsPair[x[1]]; oRowK[x;i]; (0;"shape")]; (0;"type")]}
oRowK:{[x;i] cs:x[1][1]; :[((0=4:cs)|(0=#cs)); :[(1=4:i); :[(0=#cs); (0;"empty"); :[(~(i<0)); oRowB[x;i]; (0;"bounds")]]; (0;"type")]; (0;"shape")]}
oRowB:{[x;i] cs:x[1][1]; :[(oAllVecRaw[cs])&(oColsSameLen[cs]); :[(i<#cs[0]); (1;({[col;j] col[j]}'[cs;(#cs)#i])); (0;"bounds")]; (0;"shape")]}
oMatAt:{[x;r;c] :[(oKind[x]~`intmat)|(oKind[x]~`fltmat); oMatAtK[x;r;c]; (0;"type")]}
oMatAtK:{[x;r;c] t:x[1]; :[oIsTriple[t]; :[(1=4:r)&(1=4:c); oMatAtRC[t;r;c]; (0;"type")]; (0;"shape")]}
oMatAtRC:{[t;r;c] nr:t[0]; nc:t[1]; dt:t[2]; :[(1=4:nr)&(1=4:nc); :[(~(r<0))&(~(c<0))&(r<nr)&(c<nc); oMatAtIdx[dt;r;nc;c]; (0;"bounds")]; (0;"shape")]}
oMatAtIdx:{[dt;r;nc;c] p:kChkMul[r;nc]; :[p[0]=0; (0;"overflow"); oMatAtIdx2[dt;p[1];c]]}
oMatAtIdx2:{[dt;base;c] q:kChkAdd[base;c]; :[q[0]=0; (0;"overflow"); oMatAtIdx3[dt;q[1]]]}
oMatAtIdx3:{[dt;idx] :[(((-1)=4:dt)|((-2)=4:dt)|(0=4:dt)|(0=#dt)); :[(~(idx<0))&(idx<#dt); (1;dt[idx]); (0;"bounds")]; (0;"shape")]}
oMatShape:{[x] :[(oKind[x]~`intmat)|(oKind[x]~`fltmat); :[oIsTriple[x[1]]; (1;(x[1][0];x[1][1])); (0;"shape")]; (0;"type")]}
oField:{[x;nm] :[oKind[x]~`schema; oFieldK[x;nm]; (0;"type")]}
oFieldK:{[x;nm] fs:x[1]; :[((0=4:fs)|(0=#fs)); :[(4=4:nm); oFieldFind[fs;nm]; (0;"type")]; (0;"shape")]}
oFieldFind:{[fs;nm] :[(0=#fs); (0;"key"); :[oIsTriple[fs[0]]; oFieldHead[fs;nm]; (0;"shape")]]}
oFieldHead:{[fs;nm] f:fs[0]; :[(4=4:f[0]); :[f[0]~nm; (1;(f[1];f[2])); oFieldFind[1 _ fs;nm]]; (0;"shape")]}
oPlanOp:{[x] :[oKind[x]~`plan; :[oIsPair[x[1]]; (1;x[1][0]); (0;"shape")]; (0;"type")]}
oPlanArgs:{[x] :[oKind[x]~`plan; :[oIsPair[x[1]]; (1;x[1][1]); (0;"shape")]; (0;"type")]}
oRefParts:{[x] :[oKind[x]~`ref; :[oIsTriple3[x[1]]; (1;x[1]); (0;"shape")]; (0;"type")]}
oTxnParts:{[x] :[oKind[x]~`txn; :[oIsTriple[x[1]]; (1;x[1]); (0;"shape")]; (0;"type")]}
oTimeParts:{[x] :[oKind[x]~`time; :[oIsPair2[x[1]]; (1;x[1]); (0;"shape")]; (0;"type")]}
oSymStr:{[x] :[oKind[x]~`sym; (1;$x[1]); (0;"type")]}
oStrVal:{[x] :[oKind[x]~`str; (1;x[1]); (0;"type")]}
/ Transforms. oCopy is identity: Kona copies on indexed
/ assignment, so a copy is independent by the language.
/ oMapInt requires a total function on the vector elements; a
/ function that errors on an element fails the whole call.
oCopy:{[x] x}
oAppendVec:{[a;b] :[(oKind[a]~oKind[b])&(~(oKind[a]~`bad)); oAppendVecK[a;b]; (0;"type")]}
oAppendVecK:{[a;b] k:a[0]; va:a[1]; vb:b[1]; :[((k~`intvec)&((-1)=4:va)&((-1)=4:vb))|((k~`fltvec)&((-2)=4:va)&((-2)=4:vb))|((k~`str)&((-3)=4:va)&((-3)=4:vb)); :[~(((#va)+(#vb))>kMAXLEN); (1;(k;va,vb)); (0;"limit")]; (0;"type")]}
oAppendList:{[a;b] :[(oKind[a]~`list)&(oKind[b]~`list); oAppendListK[a;b]; (0;"type")]}
oAppendListK:{[a;b] va:a[1]; vb:b[1]; :[((0=4:va)|(0=#va))&((0=4:vb)|(0=#vb)); :[~(((#va)+(#vb))>kMAXLEN); (1;(`list;va,vb)); (0;"limit")]; (0;"type")]}
oSlice:{[x;a;b] oSliceK[oKind[x];x;a;b]}
oSliceK:{[k;x;a;b] :[(k~`intvec)|(k~`fltvec)|(k~`str)|(k~`list); oSliceV[x;a;b]; (0;"type")]}
oSliceV:{[x;a;b] v:x[1]; :[(((-1)=4:v)|((-2)=4:v)|((-3)=4:v)|(0=4:v)|(0=#v)); :[(1=4:a)&(1=4:b); :[(~(a<0))&(~(b<a))&(~((#v)<b)); (1;(x[0];(b-a)#(a _ v))); (0;"bounds")]; (0;"type")]; (0;"shape")]}
oRev:{[x] oRevK[oKind[x];x]}
oRevK:{[k;x] :[(k~`intvec)|(k~`fltvec)|(k~`str)|(k~`list); oRevV[x]; (0;"type")]}
oRevV:{[x] v:x[1]; :[(((-1)=4:v)|((-2)=4:v)|((-3)=4:v)|(0=4:v)|(0=#v)); (1;(x[0];|v)); (0;"shape")]}
oMapInt:{[x;f] :[oKind[x]~`intvec; :[(-1)=4:x[1]; oMapIntK[x;f]; (0;"type")]; (0;"type")]}
oMapIntK:{[x;f] r:f'x[1]; :[(-1)=4:r; (1;(`intvec;r)); (0;"type")]}
