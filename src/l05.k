/ Layer 5: storage manager. A store is a list of pages (Layer 4
/ byte lists), indexed by page id: page id is the index into the
/ list, so sCreate appends an empty page and its id is the old
/ page count. All store operations build new stores; Kona copies
/ on indexed assignment, so an old store never changes when a
/ new store is derived from it (verified by test).
/ Records are addressed as (page id;slot), where slot is the
/ record index inside the page. sPut appends to the last page
/ and allocates a fresh page when the record does not fit;
/ sAppendTo appends to a named page and fails with "limit" when
/ it does not fit. A single frame larger than a page (record
/ bytes over 4076) fits nowhere and fails with "limit".
/ PERSISTENCE (read this before trusting a save): a store is
/ saved as ONE FLAT BYTE LIST, never as a list of pages. Kona's
/ 1: monadic read of a nested structure (a general list holding
/ large int vectors) returns objects that break traversal:
/ probed 2026-10-25, a single-element general list holding a
/ 1000-int vector segfaulted Kona deterministically (3/3) on
/ whole-object match after a write/read round trip, and the
/ same shape with a 4096-int vector matched 0 despite identical
/ sampled bytes, while the same object matched 1 in memory and
/ a two-element list matched 1. Flat int lists round-trip
/ exactly (verified: 8192-byte two-page flat list split back
/ into two valid pages). Layer 5 therefore flattens pages on
/ save and splits on load, and sLoad validates every page; no
/ whole-store match is ever used to verify persistence.
/ File semantics (from Kona's source, src/0.c, and probes):
/ sSave writes with 1: dyadic, which truncates and rewrites the
/ whole file (a second save replaces, never appends — the 5:
/ append path is deliberately not used, since appending a store
/ to a store file would corrupt it). Kona appends ".K" to the
/ path unless the path already ends in ".K"; save and load must
/ use the same path value. sLoad requires an existing file
/ created by sSave: loading a missing file is a Kona-level
/ error (DOE), not a tagged failure, and is a caller error by
/ contract — it is documented, not tested, because testing it
/ derails the Kona session. Durability boundary (honest): the
/ 1: write path mmaps, writes, and munmaps without msync, so a
/ returned save is a complete file replacement, not a proven
/ durable commit; no durable-commit claim is made.
/ Functions return (1;value) or (0;reason) as in earlier layers,
/ except sValid, which returns raw 0/1 like oIsValid. Reasons:
/ type, valid, bounds, limit, length, plus any Layer 0/4 reason
/ a frame or page check produces.
/ The empty store is !0. A store is a general list of pages, or
/ empty; anything else is a type failure, never silently treated
/ as a store.
sNew:!0

/ Store predicates and counts.
sIsStore:{[st] ((0=4:st)|(0=#st))}
sValid:{[st] :[sIsStore[st]; sValidL[st]; 0]}
sValidL:{[st] :[(0=#st); 1; &/(pValid'st)]}
sCount:{[st] :[sIsStore[st]; (1;#st); (0;"type")]}
sRecsStep:{[acc;pg] :[acc[0]=0; acc; sRecsStep2[acc;pg]]}
sRecsStep2:{[acc;pg] c:pCnt[pg]; :[c[0]=0; c; (1;acc[1]+c[1])]}
sRecs:{[st] :[sIsStore[st]; sRecsStep/((,(1;0)),st); (0;"type")]}

/ Create a page. Returns (1;(store;id)).
sCreate:{[st] :[sIsStore[st]; sCreateV[st]; (0;"type")]}
sCreateV:{[st] id:#st; r:pEmpty[id]; :[r[0]=0; r; (1;(st,(,r[1]);id))]}

/ Fetch a page by id.
sPage:{[st;id] :[sIsStore[st]; sPageB[st;id]; (0;"type")]}
sPageB:{[st;id] :[(1=4:id); :[(~(id<0))&(id<#st); (1;st[id]); (0;"bounds")]; (0;"type")]}

/ Fetch a record by (page id;slot).
sGet:{[st;id;slot] r:sPage[st;id]; :[r[0]=0; r; pGet[r[1];slot]]}

/ Replace one page in a store. The input store is untouched:
/ Kona copies on indexed assignment.
sReplace:{[st;id;pg] st2:st; st2[id]:pg; st2}

/ Append a frame to a named page. No auto-spill: a full page
/ fails with "limit" and the store is unchanged.
sAppendTo:{[st;id;fr] r:sPage[st;id]; :[r[0]=0; r; sAppendToP[st;id;fr;r[1]]]}
sAppendToP:{[st;id;fr;pg] np:pAppend[pg;fr]; :[np[0]=0; np; (1;sReplace[st;id;np[1]])]}

/ Append a frame to the store. Appends to the last page, or to
/ a fresh page when the last page is full or the store is empty.
/ Returns (1;(store;page id;slot)). The store must be valid and
/ the frame must be a valid frame; with both guards in place,
/ the only way the last-page append can fail is "limit", so no
/ failure reason is ever inspected here.
sPut:{[st;fr] :[sIsStore[st]; sPutV[st;fr]; (0;"type")]}
sPutV:{[st;fr] :[sValid[st]; sPutF[st;fr]; (0;"valid")]}
sPutF:{[st;fr] u:bUnframe[fr]; :[u[0]=0; (0;u[1]); sPutG[st;fr]]}
sPutG:{[st;fr] :[(0=#st); sPutNew[st;fr]; sPutLast[st;fr]]}
sPutNew:{[st;fr] id:#st; r:pBuild[id;(,fr)]; :[r[0]=0; r; (1;(st,(,r[1]);id;0))]}
sPutLast:{[st;fr] id:(#st)-1; pg:st[id]; np:pAppend[pg;fr]; :[np[0]=0; sPutNew[st;fr]; (1;(sReplace[st;id;np[1]];id;(pCnt[pg])[1]))]}

/ Flatten a store to one byte list for saving.
sFlat:{[st] :[(0=#st); !0; ,/st]}

/ Split flat bytes back into pages on load.
sSplit:{[flat;i] kPAGESZ#((i*kPAGESZ) _ flat)}

/ Save a store. Full rewrite via 1: dyadic (never append).
/ Returns (1;path).
sSave:{[st;path] :[sIsStore[st]; sSaveV[st;path]; (0;"type")]}
sSaveV:{[st;path] :[sValid[st]; sSaveP[st;path]; (0;"valid")]}
sSaveP:{[st;path] :[((4=4:path)|((-3)=4:path)); sSaveW[st;path]; (0;"type")]}
sSaveW:{[st;path] flat:sFlat[st]; path 1: flat; (1;path)}

/ Load a store. The file must exist (see header: a missing file
/ is a Kona-level error, not a tagged failure). Success is
/ (1;store); a non-page file is (0;"type"), a bad length is
/ (0;"length"), and any invalid page is (0;"valid").
sLoad:{[path] :[((4=4:path)|((-3)=4:path)); sLoadR[path]; (0;"type")]}
sLoadR:{[path] flat:1: path; sLoadV[flat]}
sLoadV:{[flat] :[(-1)=4:flat; sLoadM[flat]; (0;"type")]}
sLoadM:{[flat] :[bMod[#flat;kPAGESZ]=0; sLoadS[flat]; (0;"length")]}
sLoadS:{[flat] n:(#flat)%kPAGESZ; st:sSplit[flat]'!n; :[(0=#st); (1;!0); :[sValid[st]; (1;st); (0;"valid")]]}
