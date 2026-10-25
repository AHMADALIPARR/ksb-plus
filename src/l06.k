/ Layer 6: columnar engine. A table is stored column by column,
/ not row by row: each column is split into row groups, each group
/ is encoded as a one-column table frame (Layer 3), and the frames
/ are appended to a Layer 5 store with sPut. A manifest records
/ what was written and where, so a column can be read back without
/ touching any other column's pages.
/ Manifest: (names;tags;nrows;addrs). names is a symbol list,
/ tags an int list (1 int, 2 float, 3 char, 4 symbol, matching
/ the Layer 3 column tags), nrows an int, addrs a per-column
/ list of (page;slot) address lists. A column with no rows has
/ no chunks; its type comes from the manifest tag, so a 0-row
/ read returns a correctly typed empty vector.
/ Split: (names;tags;nrows;framesPerCol), the same shape with
/ frames instead of addresses. qSplitTable builds it from a
/ table; qWrite moves it into a store and returns the manifest.
/ Row-group caps are fixed per type and chosen so a chunk frame
/ always fits one page (4076 record bytes): int 400 rows (exact
/ frame 3228 bytes at the longest name), float 150 rows (float
/ decimals are variable-length, so the cap assumes 21 bytes per
/ value, above any decimal Kona's $ prints), char 3000 rows,
/ symbol 25 rows (25 symbols of 128 chars each is the worst
/ case). The caps are validated by fit tests in t06, not just
/ by arithmetic.
/ A column whose element type cannot be inferred (a general
/ empty column, which Layer 2 accepts in a table) is rejected
/ with "type": chunking needs a definite element type, and
/ silently normalizing it to int would break round-trips.
/ Functions return (1;value) or (0;reason) as in earlier layers,
/ except the qIsManifest/qIsSplit predicates, which return raw
/ 0/1. Reasons: type, shape, key, bounds, op, range, plus any
/ Layer 3/4/5 reason a frame, page, or store check produces.
/ LIMITATION (honest): chunking is by fixed row counts, not by
/ measured frame size, so short-symbol columns use more chunks
/ than they need. Reads validate only the pages they touch: a
/ corrupt chunk in an unread column does not fail a read of
/ another column (verified by test), which is the columnar
/ isolation property, not a validation gap.
/ Column type tags (1 int, 2 float, 3 char, 4 symbol).
qTagOf:{[col] :[(-1)=4:col; 1; :[(-2)=4:col; 2; :[(-3)=4:col; 3; :[(-4)=4:col; 4; 0]]]]}
qGroupN:{[tag] :[tag=1; 400; :[tag=2; 150; :[tag=3; 3000; 25]]]}
qEmptyCol:{[tag] :[tag=1; !0; :[tag=2; 0#1.0 2.0; :[tag=3; ""; 0#`a`b]]]}
/ Split one column into row groups. Direct self-recursion only.
/ Precondition: n is a positive int (always qGroupN output here).
qSplit:{[col;n] :[(0=#col); !0; :[~((#col)>n); (,col); (,(n#col)),qSplit[(n _ col);n]]]}
/ Encode one group as a one-column table frame.
qChunkFrame:{[grp;nm] t:oTable[(,nm);(,grp)]; :[t[0]=0; t; cEncode[t[1]]]}
qVal1:{[r] r[1]}
qVals:{[rs] qVal1'rs}
/ Chunk one column: its groups, each as a frame.
qChunkCol:{[col;nm] tag:qTagOf[col]; :[tag=0; (0;"type"); qChunkColG[col;nm;tag]]}
qChunkColG:{[col;nm;tag] gs:qSplit[col;qGroupN[tag]]; rs:qChunkFrame'[gs;(#gs)#nm]; :[cEOk[rs]; (1;qVals[rs]); cEFirstErr[rs]]}
/ Split a whole table into per-column chunk frames.
qSplitTable:{[tab] :[oKind[tab]~`table; qSplitTableV[tab]; (0;"type")]}
qSplitTableV:{[tab] :[oIsValid[tab]; qSplitTableW[tab]; (0;"valid")]}
qSplitTableW:{[tab] ns:tab[1][0]; cs:tab[1][1]; tags:qTagOf'cs; :[&/(0<tags); qSplitTableF[ns;cs;tags]; (0;"type")]}
qSplitTableF:{[ns;cs;tags] fr:qChunkCol'[cs;ns]; :[cEOk[fr]; (1;(ns;tags;#cs[0];qVals[fr])); cEFirstErr[fr]]}
/ Manifest and split validation (structural only; no store I/O).
qIsManifest:{[mn] :[(0=4:mn)&(4=#mn); qIsManifestV[mn]; 0]}
qIsManifestV:{[mn] ns:mn[0]; :[oIsSymList[ns]; qIsManifestN[mn;ns]; 0]}
qIsManifestN:{[mn;ns] tg:mn[1]; :[((-1)=4:tg)&((#ns)=(#tg)); qIsManifestT[mn;ns;tg]; 0]}
qIsManifestT:{[mn;ns;tg] nr:mn[2]; ad:mn[3]; :[(1=4:nr)&(~(nr<0))&((#ns)=(#ad)); :[(0<#ns)&(oUniqueSyms[ns])&(&/(0<tg))&(&/(tg<5)); qAddrsOk[ad]; 0]; 0]}
qAddrOk:{[a] :[(-1)=4:a; :[(2=#a); (~(a[0]<0))&(~(a[1]<0)); 0]; 0]}
qAddrListOk:{[ads] :[(0=#ads); 1; :[(0=4:ads); &/(qAddrOk'ads); 0]]}
qAddrsOk:{[ad] :[(0=#ad); 1; :[(0=4:ad); &/(qAddrListOk'ad); 0]]}
qIsSplit:{[sp] :[(0=4:sp)&(4=#sp); qIsSplitV[sp]; 0]}
qIsSplitV:{[sp] ns:sp[0]; :[oIsSymList[ns]; qIsSplitN[sp;ns]; 0]}
qIsSplitN:{[sp;ns] tg:sp[1]; :[((-1)=4:tg)&((#ns)=(#tg)); qIsSplitT[sp;ns;tg]; 0]}
qIsSplitT:{[sp;ns;tg] nr:sp[2]; fr:sp[3]; :[(1=4:nr)&(~(nr<0))&((#ns)=(#fr)); (0<#ns)&(oUniqueSyms[ns])&(&/(0<tg))&(&/(tg<5))&(qFramesListOk[fr]); 0]}
qFramesListOk:{[fr] :[(0=#fr); 1; :[(0=4:fr); &/(qFrameOk'fr); 0]]}
qFrameOk:{[frs] :[(0=#frs); 1; :[(0=4:frs); &/(bValid'frs); 0]]}
/ Write a split into a store. Returns (1;(store;manifest)).
qWrite:{[st;sp] :[sIsStore[st]; qWriteV[st;sp]; (0;"type")]}
qWriteV:{[st;sp] :[sValid[st]; qWriteW[st;sp]; (0;"valid")]}
qWriteW:{[st;sp] :[qIsSplit[sp]; qWriteC[st;sp]; (0;"shape")]}
qWriteC:{[st;sp] r:qWriteCols[st;sp[3]]; :[r[0]=0; (0;r[1]); (1;(r[1][0];(sp[0];sp[1];sp[2];r[1][1])))]}
qWriteCols:{[st;frs] r:qWriteColStep/((,(1;st;!0)),frs); :[r[0]=0; (0;r[1]); (1;(r[1];r[2]))]}
qWriteColStep:{[acc;frs] :[acc[0]=0; acc; qWriteColStep2[acc;frs]]}
qWriteColStep2:{[acc;frs] r:qWriteFrames[acc[1];frs]; :[r[0]=0; (0;r[1];acc[2]); (1;r[1][0];acc[2],(,(r[1][1])))]}
qWriteFrames:{[st;frs] r:qWriteFrStep/((,(1;st;!0)),frs); :[r[0]=0; (0;r[1]); (1;(r[1];r[2]))]}
qWriteFrStep:{[acc;fr] :[acc[0]=0; acc; qWriteFrStep2[acc;fr]]}
qWriteFrStep2:{[acc;fr] r:sPut[acc[1];fr]; :[r[0]=0; (0;r[1];acc[2]); (1;r[1][0];acc[2],(,((r[1][1];r[1][2]))))]}
/ Read one column back. Only that column's pages are touched.
qColRead:{[st;mn;nm] :[qIsManifest[mn]; qColReadM[st;mn;nm]; (0;"shape")]}
qColReadM:{[st;mn;nm] r:qColAddr[mn;nm]; :[r[0]=0; r; qColReadA[st;r[1]]]}
qColAddr:{[mn;nm] ns:mn[0]; :[(4=4:nm); :[((ns?nm)<#ns); (1;(mn[1][ns?nm];mn[3][ns?nm])); (0;"key")]; (0;"type")]}
qColReadA:{[st;ta] tag:ta[0]; ads:ta[1]; :[(0=#ads); (1;qEmptyCol[tag]); qColReadF[st;ads]]}
qColReadF:{[st;ads] rs:qReadChunk'[ads;(#ads)#(,st)]; :[cEOk[rs]; (1;cESeqBytes[rs]); cEFirstErr[rs]]}
qReadChunk:{[ad;st] r:sGet[st;ad[0];ad[1]]; :[r[0]=0; r; qReadChunkD[r[1]]]}
qReadChunkD:{[fr] d:cDecode[fr]; :[d[0]=0; d; oColAt[d[1];0]]}
/ Read several columns back, in the requested order.
qReadCols:{[st;mn;nms] r:qReadStep/((,(1;st;!0;mn)),nms); :[r[0]=0; (0;r[1]); (1;r[2])]}
qReadStep:{[acc;nm] :[acc[0]=0; acc; qReadStep2[acc;nm]]}
qReadStep2:{[acc;nm] r:qColRead[acc[1];acc[3];nm]; :[r[0]=0; (0;r[1];acc[2];acc[3]); (1;acc[1];acc[2],(,r[1]);acc[3])]}
/ Read a whole table back from a store and a manifest.
qRead:{[st;mn] :[qIsManifest[mn]; qReadM[st;mn]; (0;"shape")]}
qReadM:{[st;mn] cs:qReadCols[st;mn;mn[0]]; :[cs[0]=0; cs; oTable[mn[0];cs[1]]]}
qNames:{[mn] :[qIsManifest[mn]; (1;mn[0]); (0;"shape")]}
qRows:{[mn] :[qIsManifest[mn]; (1;mn[2]); (0;"shape")]}
/ Predicates. op is a symbol: lt, le, eq, ge, gt, ne. Numeric
/ columns take all six; char and symbol columns take eq and ne
/ only (ordering a symbol is meaningless; char ordering is by
/ byte, but only equality is offered here so filters mean the
/ same thing on every column type).
qPredOk:{[col;op] :[(4=4:op); qPredOkT[col;op]; 0]}
qPredOkT:{[col;op] :[(((-1)=4:col)|((-2)=4:col)); ((`lt`le`eq`ge`gt`ne?op)<6); :[(((-3)=4:col)|((-4)=4:col)); ((`eq`ne?op)<2); 0]]}
qValOk:{[col;val] :[(((-1)=4:col)|((-2)=4:col)); ((1=4:val)|(2=4:val)); :[(-3)=4:col; (3=4:val); :[(-4)=4:col; (4=4:val); 0]]]}
qMask:{[col;op;val] :[op~`lt; (1;col<val); :[op~`le; (1;~((val<col))); :[op~`eq; (1;col=val); :[op~`ge; (1;~((col<val))); :[op~`gt; (1;col>val); (1;~((col=val)))]]]]]}
qFilterIdx:{[col;op;val] :[qPredOk[col;op]; qFilterIdxV[col;op;val]; (0;"op")]}
qFilterIdxV:{[col;op;val] :[qValOk[col;val]; qFilterIdxM[col;op;val]; (0;"type")]}
qFilterIdxM:{[col;op;val] m:qMask[col;op;val]; (1;&m[1])}
/ Gather rows by index from raw columns (in-memory).
qGather1:{[c;ix] c[ix]}
qGatherCols:{[cols;ix] qGather1'[cols;(#cols)#(,ix)]}
/ Filter a table's rows by a predicate on one column.
qFilter:{[tab;col;op;val] c:oCol[tab;col]; :[c[0]=0; c; qFilterV[tab;c[1];op;val]]}
qFilterV:{[tab;col;op;val] ix:qFilterIdx[col;op;val]; :[ix[0]=0; ix; qFilterT[tab;ix[1]]]}
qFilterT:{[tab;ix] ns:tab[1][0]; g:qGatherCols[tab[1][1];ix]; oTable[ns;g]}
/ Project a table to a subset of columns, in the given order.
qProject:{[tab;nms] :[oIsSymList[nms]; qProjectV[tab;nms]; (0;"type")]}
qProjectV:{[tab;nms] rs:oCol'[(#nms)#(,tab);nms]; :[cEOk[rs]; oTable[nms;qVals[rs]]; cEFirstErr[rs]]}
/ Filter, then project.
qSelect:{[tab;col;op;val;proj] f:qFilter[tab;col;op;val]; :[f[0]=0; f; qProject[f[1];proj]]}
/ Aggregates. sum is checked for ints (overflow is a failure,
/ never a wrap); count is the row count; min/max use Layer 1
/ and refuse symbols and empty columns; mean is a float, from
/ int or float columns, and refuses empty columns.
qSumStep:{[acc;x] :[acc[0]=0; acc; qSumStep2[acc;x]]}
qSumStep2:{[acc;x] p:kChkAdd[acc[1];x]; :[p[0]=0; p; (1;p[1])]}
qSumInt:{[col] r:qSumStep/((,(1;0)),col); :[r[0]=0; r; (1;r[1])]}
qAggSum:{[col] :[(-1)=4:col; qSumInt[col]; :[(-2)=4:col; :[(0=#col); (1;0.0); (1;+/col)]; (0;"type")]]}
qAggMin:{[col] :[(0=4:col); (0;"type"); :[(0=#col); (0;"empty"); :[(-3)=4:col; (1;col[(<col)[0]]); :[(((-1)=4:col)|((-2)=4:col)); kMin[col]; (0;"type")]]]]}
qAggMax:{[col] :[(0=4:col); (0;"type"); :[(0=#col); (0;"empty"); :[(-3)=4:col; (1;col[(<col)[(#col)-1]]); :[(((-1)=4:col)|((-2)=4:col)); kMax[col]; (0;"type")]]]]}
qAggMean:{[col] :[(-2)=4:col; qMeanF[col]; :[(-1)=4:col; qMeanI[col]; (0;"type")]]}
qMeanF:{[col] :[(0=#col); (0;"empty"); (1;(+/col)%(#col))]}
qMeanI:{[col] s:qSumInt[col]; :[s[0]=0; s; :[(0=#col); (0;"empty"); (1;(s[1]+0.0)%(#col))]]}
qAgg:{[tab;nm;op] c:oCol[tab;nm]; :[c[0]=0; c; qAggV[c[1];op]]}
qAggV:{[col;op] :[op~`count; (1;#col); :[op~`sum; qAggSum[col]; :[op~`min; qAggMin[col]; :[op~`max; qAggMax[col]; :[op~`mean; qAggMean[col]; (0;"op")]]]]]}
/ Pushed-down scan: read only the predicate column, compute
/ matching rows, then read only the projected columns.
qScan:{[st;mn;col;op;val;proj] :[qIsManifest[mn]; qScanM[st;mn;col;op;val;proj]; (0;"shape")]}
qScanM:{[st;mn;col;op;val;proj] c:qColRead[st;mn;col]; :[c[0]=0; c; qScanV[st;mn;c[1];op;val;proj]]}
qScanV:{[st;mn;col;op;val;proj] ix:qFilterIdx[col;op;val]; :[ix[0]=0; ix; qScanG[st;mn;ix[1];proj]]}
qScanG:{[st;mn;ix;proj] :[oIsSymList[proj]; qScanH[st;mn;ix;proj]; (0;"type")]}
qScanH:{[st;mn;ix;proj] cs:qReadCols[st;mn;proj]; :[cs[0]=0; cs; qScanT[proj;cs[1];ix]]}
qScanT:{[proj;cols;ix] g:qGatherCols[cols;ix]; oTable[proj;g]}
