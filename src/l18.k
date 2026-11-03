/ SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0
/ Copyright Ahmad Ali Parr
/ Layer 18: size-aware column chunks and direct page reads.
/ Prefix g.
/ Size-aware chunking: Layer 6 cuts a column into fixed row
/ counts chosen for the worst case. gSplitTable instead measures
/ the encoded size of every value (int 8 bytes, char 1, symbol
/ 4 + its bytes, float its Layer 3 encoding) and cuts a new chunk
/ only when the next value would push the chunk frame past one
/ page (kPAGEMAX). Short symbols therefore share chunks and long
/ ones still fit. A symbol longer than kMAXNAME is refused
/ (limit), since Layer 3 would refuse to decode it. The result has the Layer 6 split shape, so
/ qWrite, qRead, qColRead and qScan work on it unchanged.
/ Direct page reads: a store saved by sSave or Layer 17 is one
/ Kona int file (32-byte header, then 8 bytes per page byte).
/ gPage reads one page from the file with Kona's offset read
/ (dyadic 1: on (file;offset;length)), which maps only that
/ range of the file; the rest of the store is never loaded.
/ gColRead reads one column of a chunked table that way: only the
/ pages holding that column's chunks are read, and each page is
/ validated (Layer 4 checksum) when it is read.
/ Functions return (1;value) or (0;reason). Reasons: type, shape,
/ limit, bounds, missing, plus any Layer 3/4/6 reason.
gBUD:4076
gStep:{[s;c] :[(s+c)>gBUD; c; s+c]}
gSymCost:{[s] 4+#_ic $s}
gFltCost:{[x] #cEncFltE[x][1]}
gCosts:{[col;tag] :[tag=1; (#col)#8; :[tag=3; (#col)#1; :[tag=4; gSymCost'col; gFltCost'col]]]}
gOver:{[nm;tag] #cEncode[oTable[(,nm);(,qEmptyCol[tag])][1]][1]}
/ Start index of every chunk for costs cs under budget b.
gStarts:{[cs;b] gBUD::b; r:1 _ 0 gStep\ cs; &r=cs}
gCut:{[col;cs;b] :[(|/cs)>b; (0;"limit"); (1;(gStarts[cs;b]) _ col)]}
gChunkCol:{[col;nm] tag:qTagOf[col]; :[tag=0; (0;"type"); :[(0=#col); (1;()); gChunkColG[col;nm;tag]]]}
gChunkColG:{[col;nm;tag] cs:gCosts[col;tag]; :[(tag=4)&((|/cs)>(4+kMAXNAME)); (0;"limit"); gChunkColC[col;nm;tag;cs]]}
gChunkColC:{[col;nm;tag;cs] g:gCut[col;cs;kPAGEMAX-gOver[nm;tag]]; :[g[0]=0; g; gChunkFr[g[1];nm]]}
gChunkFr:{[gs;nm] rs:qChunkFrame'[gs;(#gs)#nm]; :[cEOk[rs]; (1;qVals[rs]); cEFirstErr[rs]]}
gSplitTable:{[tab] :[oKind[tab]~`table; gSplitTableV[tab]; (0;"type")]}
gSplitTableV:{[tab] :[oIsValid[tab]; gSplitTableW[tab]; (0;"valid")]}
gSplitTableW:{[tab] ns:tab[1][0]; cs:tab[1][1]; tags:qTagOf'cs; :[&/(0<tags); gSplitTableF[ns;cs;tags]; (0;"type")]}
gSplitTableF:{[ns;cs;tags] fr:gChunkCol'[cs;ns]; :[cEOk[fr]; (1;(ns;tags;#cs[0];qVals[fr])); cEFirstErr[fr]]}
/ Chunk counts per column of a split (for inspection).
gCount1:{[frs] #frs}
gChunks:{[sp] :[qIsSplit[sp]; (1;gCount1'sp[3]); (0;"shape")]}
/ File checks. A missing file must be caught before any read.
gExists:{[p] fl:p,".flag"; dSh["test -f ",p,".K && echo 1 > ",fl," || echo 0 > ",fl]; r:0$(0: fl)[0]; dSh["rm -f ",fl]; r}
gHdr:{[p] (("j";,8) 1: (p,".K";16;16))[0]}
gNPages:{[p] h:gHdr[p]; :[h[0]=(-1); :[0=h[1]!kPAGESZ; (1;h[1]%kPAGESZ); (0;"length")]; (0;"type")]}
/ One page by id, read and validated without loading the store.
gPage:{[p;id] :[((-3)=4:p)&(0<#p); :[gExists[p]; gPageN[p;id;gNPages[p]]; (0;"missing")]; (0;"type")]}
gPageN:{[p;id;n] :[n[0]=0; n; :[(1=4:id); :[(~(id<0))&(id<n[1]); gPageR[p;id]; (0;"bounds")]; (0;"type")]]}
gPageR:{[p;id] pg:(("j";,8) 1: (p,".K";32+id*8*kPAGESZ;8*kPAGESZ))[0]; r:pParse[pg]; :[r[0]=0; r; (1;pg)]}
gGet:{[p;id;slot] r:gPage[p;id]; :[r[0]=0; r; pGet[r[1];slot]]}
/ One column of a chunked table, reading only its own pages.
gColRead:{[p;mn;nm] :[qIsManifest[mn]; gColReadM[p;mn;nm]; (0;"shape")]}
gColReadM:{[p;mn;nm] a:qColAddr[mn;nm]; :[a[0]=0; a; :[(0=#a[1][1]); (1;qEmptyCol[a[1][0]]); gColReadF[p;a[1][1]]]]}
gColReadF:{[p;ads] rs:gReadChunk'[(#ads)#(,p);ads]; :[cEOk[rs]; (1;cESeqBytes[rs]); cEFirstErr[rs]]}
gReadChunk:{[p;ad] r:gGet[p;ad[0];ad[1]]; :[r[0]=0; r; qReadChunkD[r[1]]]}
