/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 4: pages. A page is the fixed-size unit of storage: exactly
/ 4096 bytes, holding a sequence of Layer 3 frames (records).
/ Layout (all integers big-endian, as in Layers 0-3):
/   bytes 0..2: magic 75 80 71 ("KPG")
/   byte 3: version 1
/   bytes 4..7: u32be page id (0..4294967295)
/   bytes 8..11: u32be record count
/   bytes 12..15: u32be used bytes (header + records, 20..4096)
/   bytes 16..19: u32be checksum (bCksum over bytes 0..15 plus the
/     record bytes; the checksum field itself is not covered)
/   bytes 20..used-1: record bytes (concatenated Layer 0 frames)
/   bytes used..4095: zero padding
/ Records are self-delimiting Layer 0 frames, so a page is read by
/ scanning frames from offset 20 until the used bytes are consumed;
/ no slot directory is needed. The header count must match the
/ scanned frame count, and the padding must be all zeros.
/ A page id is a u32, not a Kona int, so ids above 4294967295 are
/ rejected. Page bytes are int lists; a page is always exactly
/ 4096 bytes, in memory and on disk, so a store is a sequence of
/ pages and page i lives at file offset i*4096 (Layer 5).
/ Functions return (1;value) or (0;reason) as in earlier layers.
/ Reasons: type, length, magic, version, range, limit, bounds,
/ checksum, trailing, count, trunc, short. Frame-level failures
/ propagate the Layer 0 reason (short, magic, version, length,
/ checksum).
/ LIMITATION (honest): pages are byte lists in Kona memory; there
/ is no mmap or direct-disk page I/O in this layer. Persistence
/ is Layer 5's job, on top of Kona's file verbs.
kPAGESZ:4096
kPAGEHDR:20
kPAGEMAX:4076

/ Scan record bytes into a frame list. Direct self-recursion only
/ (see docs/kona-notes.md: no helper between a function and its
/ own recursive call). Accumulator starts as !0 and grows by
/ enlist-then-concat, so an empty scan yields !0 and a nonempty
/ scan yields a general list of frames.
pScan:{[bs;acc] tot:14+bFrameLen[bs]; :[(0=#bs); (1;acc); :[(#bs)<14; (0;"trunc"); :[tot>#bs; (0;"trunc"); :[(bUnframe[tot#bs])[0]=0; (0;(bUnframe[tot#bs])[1]); pScan[(tot _ bs);acc,(,tot#bs)]]]]]}

/ Validate one frame and accumulate its length. Fold step is a
/ leaf: it never recurses, so the over form is safe here.
pFrameOkStep:{[acc;fr] :[acc[0]=0; acc; pFrameOkStep2[acc;fr]]}
pFrameOkStep2:{[acc;fr] :[(-1)=4:fr; :[(bUnframe[fr])[0]=1; (1;acc[1]+#fr); (0;(bUnframe[fr])[1])]; (0;"type")]}
pFramesOk:{[frs] pFrameOkStep/((,(1;0)),frs)}

/ Build a page from a page id and a list of frames.
pBuild:{[id;frs] :[(1=4:id); :[(~(id<0))&(id<4294967296); pBuildF[id;frs]; (0;"range")]; (0;"type")]}
pBuildF:{[id;frs] :[((0=4:frs)|(0=#frs)); pBuildV[id;frs]; (0;"type")]}
pBuildV:{[id;frs] ok:pFramesOk[frs]; :[ok[0]=0; ok; pBuildB[id;frs;ok[1]]]}
pBuildB:{[id;frs;tot] :[tot>kPAGEMAX; (0;"limit"); pBuildP[id;frs;tot]]}
pBuildP:{[id;frs;tot] recs:pJoinFrs[frs]; hdr:(75 80 71),1,bEncU32[id],bEncU32[#frs],bEncU32[20+tot]; body:hdr,recs; ck:bCksum[body]; pg:(16#body),bEncU32[ck],(16 _ body); (1;pg,(kPAGESZ-#pg)#0)}
pJoinFrs:{[frs] :[(0=#frs); !0; ,/frs]}

/ An empty page: header only, count 0, used 20.
pEmpty:{[id] pBuild[id;!0]}

/ Parse and fully validate a page. Success: (1;(id;count;used;
/ frames)). Failure: (0;reason). Checks run in order: type,
/ length, byte range, magic, version, used range, trailing zeros,
/ checksum, frame scan, count match.
pParse:{[pg] :[(-1)=4:pg; pParseL[pg]; (0;"type")]}
pParseL:{[pg] :[(#pg)=kPAGESZ; pParseB[pg]; (0;"length")]}
pParseB:{[pg] :[(&/~(pg<0))&(&/~(255<pg)); pParseM[pg]; (0;"type")]}
pParseM:{[pg] :[~((75 80 71)~3#pg); (0;"magic"); :[~(1=pg[3]); (0;"version"); pParseU[pg]]]}
pParseU:{[pg] u:bDecU32[4#(12 _ pg)]; :[(~(u<20))&(~(kPAGESZ<u)); pParseT[pg;u]; (0;"length")]}
pParseT:{[pg;u] :[(+/ (u _ pg))=0; pParseC[pg;u]; (0;"trailing")]}
pParseC:{[pg;u] rec:(u-20)#(20 _ pg); :[bDecU32[4#(16 _ pg)]=bCksum[(16#pg),rec]; pParseS[pg;u;rec]; (0;"checksum")]}
pParseS:{[pg;u;rec] r:pScan[rec;!0]; :[r[0]=0; r; pParseN[pg;u;r[1]]]}
pParseN:{[pg;u;frs] cnt:bDecU32[4#(8 _ pg)]; :[(#frs)=cnt; (1;((bDecU32[4#(4 _ pg)];cnt;u;frs))); (0;"count")]}

/ Full validation as 0/1.
pValid:{[pg] (pParse[pg])[0]=1}

/ Field accessors. Each validates the whole page first, so a
/ corrupt page never yields a lying id, count, or frame.
pId:{[pg] r:pParse[pg]; :[r[0]=0; r; (1;r[1][0])]}
pCnt:{[pg] r:pParse[pg]; :[r[0]=0; r; (1;r[1][1])]}
pUsed:{[pg] r:pParse[pg]; :[r[0]=0; r; (1;r[1][2])]}
pFree:{[pg] r:pParse[pg]; :[r[0]=0; r; (1;kPAGESZ-r[1][2])]}
pRead:{[pg] r:pParse[pg]; :[r[0]=0; r; (1;r[1][3])]}
pGet:{[pg;i] r:pParse[pg]; :[r[0]=0; r; pGetF[r[1][3];i]]}
pGetF:{[frs;i] :[(1=4:i); :[(~(i<0))&(i<#frs); (1;frs[i]); (0;"bounds")]; (0;"type")]}

/ Append one frame to a page. The page is rebuilt (same id,
/ count + 1), so a failed append leaves the input page
/ untouched; the caller keeps the old page on (0;reason).
pAppend:{[pg;fr] r:pParse[pg]; :[r[0]=0; r; pAppendF[r[1];fr]]}
pAppendF:{[q;fr] u:bUnframe[fr]; :[u[0]=0; (0;u[1]); pAppendB[q;fr]]}
pAppendB:{[q;fr] :[(q[2]+#fr)>kPAGESZ; (0;"limit"); pBuild[q[0];q[3],(,fr)]]}
