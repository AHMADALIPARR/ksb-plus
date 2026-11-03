/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 18 tests: size-aware chunks and direct page reads.
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
md:{[a;b] a-b*(a%b)}
flen:{[f] #f}
fits:{[frs] &/(flen'frs)<(kPAGEMAX+1)}
allfit:{[sp] &/fits'sp[3]}
rt:{[tab] sp:gSplitTable[tab][1]; w:qWrite[sNew;sp][1]; qRead[w[0];w[1]]}
/ short symbols: Layer 6 uses 25 rows per chunk, sized for the
/ longest symbol; measured sizes pack many more per chunk
tS:oTable[,`s;,`a`bb`ccc[md[!2000;3]]][1]
spQ:qSplitTable[tS][1]
spG:gSplitTable[tS][1]
chk["sym-short-l6"; gChunks[spQ][1]; ,80]
chk["sym-short-l18"; gChunks[spG][1]; ,3]
chk["sym-short-fit"; allfit[spG]; 1]
chk["sym-short-rt"; rt[tS]; (1;tS)]
/ long symbols still fit one page per chunk
s128:`$128#"x"
tL:oTable[,`s;,200#s128][1]
spL:gSplitTable[tL][1]
chk["sym-long-chunks"; gChunks[spL][1]; ,7]
chk["sym-long-fit"; allfit[spL]; 1]
chk["sym-long-rt"; rt[tL]; (1;tL)]
/ mixed symbol lengths
tM:oTable[,`s;,(`a;s128;`bc;`$100#"y")[md[!300;4]]][1]
spM:gSplitTable[tM][1]
chk["sym-mixed-fit"; allfit[spM]; 1]
chk["sym-mixed-rt"; rt[tM]; (1;tM)]
chk["sym-too-long"; gSplitTable[oTable[,`s;,(`a;`$129#"z")][1]]; (0;"limit")]
/ ints, floats, chars, and a whole table
n:3000
tI:oTable[`i`f`c`s;(!n;0.25*!n;"abcd"[md[!n;4]];`p`q[md[!n;2]])][1]
spI:gSplitTable[tI][1]
chk["table-fit"; allfit[spI]; 1]
chk["table-rt"; rt[tI]; (1;tI)]
chk["int-chunks"; gChunks[spI][1][0]; 6]
chk["char-chunks"; gChunks[spI][1][2]; 1]
chk["fewer-chunks"; (+/gChunks[spI][1])<(+/gChunks[qSplitTable[tI][1]][1]); 1]
fs:(1.5;-2.0;0.1;1e300;-0.0;0n;0i+0.0)
tF:oTable[,`f;,600#fs][1]
chk["flt-special-rt"; rt[tF]; (1;tF)]
chk["flt-fit"; allfit[gSplitTable[tF][1]]; 1]
/ empty table, bad input, a value larger than a page
tE:oTable[`a`b;(!0;0#`a`b)][1]
chk["empty-chunks"; gChunks[gSplitTable[tE][1]][1]; 0 0]
chk["empty-rt"; rt[tE]; (1;tE)]
chk["split-type"; gSplitTable[5]; (0;"type")]
chk["chunks-shape"; gChunks[5]; (0;"shape")]
chk["cut-limit"; gCut[!3;10 5000 10;4000]; (0;"limit")]
chk["starts"; gStarts[3 4 5 2 9 1;10]; 0 2 4]
/ direct page reads from a saved store file
w:qWrite[sNew;spI][1]
st:w[0]
mn:w[1]
sv:sSave[st;"g18store"]
chk["npages"; gNPages["g18store"]; (1;#st)]
pgEq:{[i] gPage["g18store";i]~(1;st[i])}
chk["page-each"; &/pgEq'!#st; 1]
chk["page-bounds"; gPage["g18store";#st]; (0;"bounds")]
chk["page-neg"; gPage["g18store";-1]; (0;"bounds")]
chk["page-type"; gPage["g18store";`a]; (0;"type")]
chk["page-missing"; gPage["g18nofile";0]; (0;"missing")]
chk["get"; gGet["g18store";0;0]; sGet[st;0;0]]
chk["col-i"; gColRead["g18store";mn;`i]; (1;!n)]
chk["col-s"; gColRead["g18store";mn;`s]; qColRead[st;mn;`s]]
chk["col-f"; gColRead["g18store";mn;`f]; (1;0.25*!n)]
chk["col-key"; gColRead["g18store";mn;`zz]; (0;"key")]
chk["col-shape"; gColRead["g18store";5;`i]; (0;"shape")]
/ corrupt one byte in the page of column c: reading c fails its
/ checksum, reading i (other pages) still works
pc:mn[3][2][0][0]
bad:sFlat[st]
bad[(pc*kPAGESZ)+100]:255-bad[(pc*kPAGESZ)+100]
a1:"g18bad" 1: bad
chk["corrupt-col"; gColRead["g18bad";mn;`c][0]; 0]
chk["corrupt-other"; gColRead["g18bad";mn;`i]; (1;!n)]
a2:."\\rm -f g18store.K g18bad.K"
:[0=FC[0]; "ALL PASS"; "FAILURES"]
