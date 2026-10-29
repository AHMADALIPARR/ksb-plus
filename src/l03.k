/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 3: canonical value format. A value encodes as one Layer 0
/ frame: bFrame[tag;payload], where tag is the kind registry byte
/ (1..16 for the Layer 2 kinds, 17 for null) and payload is the
/ kind-specific encoding below. Nested values carry an inline tag
/ byte plus payload (no per-object frames: the outer frame's
/ checksum covers all nested bytes). All integers are big-endian,
/ all counts and lengths are u32be, and no pointers, addresses,
/ or machine words appear anywhere, so the format is
/ machine-independent.
/ Payload layouts (after the tag):
/ int: 8 bytes i64be. flt: class byte (kFClass codes 0 NaN,
/ 1 +Inf, 2 -Inf, 3 zero, 4 finite) plus, for class 4 only, a
/ length-prefixed decimal string. str: length-prefixed bytes.
/ sym: length-prefixed bytes of the symbol name. intvec: u32
/ count plus 8 bytes per element. fltvec: u32 count plus one
/ float encoding (class plus optional decimal) per element.
/ list: u32 count plus one tagged value per element. dict: u32
/ count plus that many symbol encodings (length-prefixed names,
/ no tag) plus that many tagged values. table: u32 column count
/ plus per column a symbol encoding (name), a column-tag byte
/ (1 int, 2 float, 3 char, 4 symbol), a u32 row count, and the
/ column data. time: sub byte plus 8 bytes i64be. intmat: u32
/ rows, u32 columns, then 8 bytes per element. fltmat: rows,
/ columns, then one float encoding per element. schema: u32
/ field count plus per field a symbol encoding (name), a
/ typecode byte (the kind tag 1..16), and a nullable byte. plan:
/ symbol encoding (operator), u32 argument count, then one
/ tagged value per argument. ref: three i64be values. txn: i64be
/ id, u32 operation count, one tagged value per operation, then
/ a state byte. null: empty payload.
/ Floats encode as Kona's $ decimal, and encoding VERIFIES the
/ round trip: if parsing the decimal back does not reproduce the
/ value exactly, encoding fails with (0;"float") instead of
/ silently storing a lossy value. Kona's $ prints about 7
/ significant digits, so values needing more digits (max float,
/ 1%3) and subnormals are refused, never corrupted. Ordinary
/ magnitudes with short decimals (1.5, 0.1, 1e10) round-trip.
/ Strings are byte strings (Kona chars are bytes), exactly as in
/ Layer 0; no UTF-8 validation is applied to Layer 3 payloads.
/ Decoders are structural (tags, lengths, bounds, per-field
/ ranges) plus a final oIsValid gate in cDecode, so a payload
/ that decodes structurally but is semantically invalid (dup
/ dict keys, mismatched table columns) fails with (0;"valid").
/ Reasons in this layer: type, limit, shape, key, valid, range,
/ bounds, op, overflow, depth, tag, trunc, trailing, float.
/ LIMITATION (honest): byte assembly uses concat folds, which
/ copy quadratically, so encoding or decoding very large values
/ (around 10^5 elements and up) is slow. Vectors up to 10^4
/ elements are tested; the 10^6 object-level limit from Layer 2
/ is not re-tested at the byte level here.
/ Null is a Layer 3 value, not a Layer 2 object: it is the pair
/ (`null;!0). It round-trips through encode and decode but is
/ not oIsValid, by design.
/ Kona recursion rules (probe-verified 2026-10-25, miniatures in
/ the work notes, not in this repo): direct self-recursion is
/ safe (nest, wrapn, cE, cDL); mutual recursion is not. Proven
/ failures: (1) mutual frames leak locals (inner assignments
/ overwrite outer locals/params); (2) a dyadic verb evaluated
/ after a recursive call returns becomes a projection; (3) a
/ :[...] branch call that transitively repeats its own function
/ through another function returns void, even through a
/ pass-through helper; (4) assigning a :[...] result to a
/ variable yields void; (5) over with a lambda leaks under
/ nesting, while each calling the SAME function preserves
/ locals; (6) lambdas do not capture outer locals (pass values
/ as parameters); (7) (pair;list) concat flattens, so append a
/ single element as ,(value), never (value). Design consequence:
/ the encoder is one function cE with inline branches, each
/ calling cE itself, and assembly in non-repeating *B helpers;
/ the decoder is one directly-recursive loop cDL over an
/ explicit frame stack, with leaf helpers only. No decoder or
/ encoder frame reads a pre-call local after a recursive call,
/ and no mutually-repeating call appears as a :[...] branch.
cIsNull:{[x] :[oIsPair[x]; :[(4=4:x[0]); :[x[0]~`null; (0=#x[1]); 0]; 0]; 0]}
cKindOfTag:{[t] :[(t=17); `null; :[(~(t<1))&(~(16<t)); oKindSyms[t-1]; `bad]]}
/ Decimal float parser. Returns (1;float) or (0;"float").
/ Digits are found with ? on the digit string: Kona has no
/ char-minus-int arithmetic ("5"-48 is a rank error).
cIsDigit:{[c] (("0123456789"?c)<10)}
cAllDigits:{[ds] :[(0=#ds); 0; &/(cIsDigit'ds)]}
cDigitsStep:{[acc;c] (acc*10)+("0123456789"?c)}
cDigitsVal:{[ds] cDigitsStep/((,0),ds)}
cStrToFlt:{[s] :[(0=#s); (0;"float"); cStrToFltS[s]]}
cStrToFltS:{[s] :[s[0]="-"; cStrToFltM[1 _ s;-1]; :[s[0]="+"; cStrToFltM[1 _ s;1]; cStrToFltM[s;1]]]}
cStrToFltM:{[r;sgn] :[(0=#r); (0;"float"); cStrToFltE[r;sgn]]}
cFindE:{[r] i:r?"e"; :[i<#r; i; r?"E"]}
cStrToFltE:{[r;sgn] p:cFindE[r]; :[p<#r; cStrToFltX[(p#r);((p+1) _ r);sgn]; cStrToFltX[r;"";sgn]]}
cStrToFltX:{[m;e;sgn] :[(0=#e); cStrToFltM2[m;0;sgn]; cStrToFltX2[m;e;sgn]]}
cStrToFltX2:{[m;e;sgn] ev:cExpValT[e]; :[ev[0]=0; ev; cStrToFltM2[m;ev[1];sgn]]}
cExpValT:{[e] :[e[0]="-"; cExpNeg[1 _ e]; :[e[0]="+"; cExpPos[1 _ e]; cExpPos[e]]]}
cExpNeg:{[ds] :[cAllDigits[ds]; (1;-(cDigitsVal[ds])); (0;"float")]}
cExpPos:{[ds] :[cAllDigits[ds]; (1;cDigitsVal[ds]); (0;"float")]}
cStrToFltM2:{[m;ev;sgn] p:m?"."; :[p<#m; cStrToFltF[(p#m);((p+1) _ m);ev;sgn]; cStrToFltF[m;"";ev;sgn]]}
cStrToFltF:{[ip;fp;ev;sgn] :[cAllDigits[fp]; :[((0=#ip)|(cAllDigits[ip])); cStrToFltF2[ip;fp;ev;sgn]; (0;"float")]; :[(0=#fp)&(cAllDigits[ip]); cStrToFltF2[ip;fp;ev;sgn]; (0;"float")]]}
cStrToFltF2:{[ip;fp;ev;sgn] digits:ip,fp; :[(#digits)>18; (0;"float"); cStrToFltF3[digits;#fp;ev;sgn]]}
cStrToFltF3:{[digits;k;ev;sgn] M:cDigitsVal[digits]; e:ev-k; v:(M+0.0)*(10.0^e); :[(kFIsPosInf[v])|(kFIsNegInf[v]); (0;"float"); :[sgn<0; (1;-v); (1;v)]]}
/ Float element encoding (no tag): class byte plus, for class 4,
/ a length-prefixed decimal. Encoding verifies the round trip.
cEncFltE:{[v] c:kFClass[v]; :[c=0; (1;,0); :[c=1; (1;,1); :[c=2; (1;,2); :[c=3; (1;,3); cEncFltFin[v]]]]]}
cEncFltFin:{[v] s:$v; p:cStrToFlt[s]; :[p[0]=0; p; :[p[1]=v; (1;(,4),bEncStr[_ic s]); (0;"float")]]}
/ Shared readers. cDecCnt returns (1;(count;rest)) or (0;reason).
/ Remaining-based readers live in the decoder section below;
/ cDecCnt is shared (count;rest in both conventions).
cDecCnt:{[bs] :[(#bs)<4; (0;"trunc"); cDecCntR[bs]]}
cDecCntR:{[bs] n:(bDecU32[4#bs]); :[n>kMAXLEN; (0;"limit"); (1;(n;4 _ bs))]}
/ Encoders. cE appends one object's tag-plus-payload to an
/ accumulator and returns (1;bytes) or (0;reason); cEncode splits
/ the tag back out for bFrame. Object sequences use each (whose
/ frames stay fresh under nesting); named-step folds are used
/ only for leaf data that never recurses into objects.
/ Kona recursion rules honored here (see header): no frame reads
/ a pre-call local after a call returns except through each,
/ whose locals are preserved; no dyadic verb after a call in a
/ repeating frame; never assign a :[ result to a variable.
cE:{[x;d] k:oKind[x]; :[d>kMAXDEPTH; (0;"depth"); :[cIsNull[x]; (1;,17); :[k~`bad; (0;"type"); :[k~`int; (1;(,1),kI64ToBytes[x[1]]); :[k~`flt; cEFlt[x]; :[k~`str; (1;(,3),bEncStr[_ic x[1]]); :[k~`sym; (1;(,4),bEncStr[_ic $x[1]]); :[k~`intvec; (1;(,5),bEncU32[#x[1]],cEncInts[x[1]]); :[k~`fltvec; cEFltVec[x]; :[k~`list; cEListB[x[1];cE'[x[1];d+1]]; :[k~`dict; cEDictB[x[1][0];cEncSymSeq[x[1][0]];cE'[x[1][1];d+1]]; :[k~`table; cETable[x]; :[k~`time; (1;(,10),(,x[1][0]),kI64ToBytes[x[1][1]]); :[k~`intmat; (1;(,11),bEncU32[x[1][0]],bEncU32[x[1][1]],cEncInts[x[1][2]]); :[k~`fltmat; cEFltMat[x]; :[k~`schema; (1;(,13),bEncU32[#x[1]],cEncFieldSeq[x[1]]); :[k~`plan; cEPlanB[x[1][1];bEncStr[_ic $x[1][0]];cE'[x[1][1];d+1]]; :[k~`ref; (1;(,15),kI64ToBytes[x[1][0]],kI64ToBytes[x[1][1]],kI64ToBytes[x[1][2]]); :[k~`txn; cETxnB[x[1][1];kI64ToBytes[x[1][0]];x[1][2];cE'[x[1][1];d+1]]; (0;"type")]]]]]]]]]]]]]]]]]]]}
cEFlt:{[x] e:cEncFltE[x[1]]; :[e[0]=0; e; (1;(,2),e[1])]}
cEFltVec:{[x] r:cEncFltSeq[x[1]]; :[r[0]=0; r; (1;(,6),bEncU32[#x[1]],r[1])]}
cEFltMat:{[x] r:cEncFltSeq[x[1][2]]; :[r[0]=0; r; (1;(,12),bEncU32[x[1][0]],bEncU32[x[1][1]],r[1])]}
cETable:{[x] ns:x[1][0]; cs:x[1][1]; cb:bEncU32[#ns]; nb:cEncSymSeq[ns]; r:cEncColSeq[cs]; :[r[0]=0; r; (1;(,9),cb,nb,r[1])]}
cEFirstErrStep:{[acc;r] :[acc[0]=0; acc; r]}
cEFirstErr:{[rs] cEFirstErrStep/((,(1;!0)),rs)}
cESeqBytes:{[rs] :[(0=#rs); !0; ,/{[r] r[1]}'rs]}
cEOk:{[rs] :[(0=#rs); 1; &/{[r] r[0]}'rs]}
cEListB:{[xs;rs] ok:cEOk[rs]; a:(,7),bEncU32[#xs]; b:a,cESeqBytes[rs]; :[ok; (1;b); cEFirstErr[rs]]}
cEDictB:{[ks;kb;rs] ok:cEOk[rs]; a:(,8),bEncU32[#ks]; b:a,kb; c:b,cESeqBytes[rs]; :[ok; (1;c); cEFirstErr[rs]]}
cEPlanB:{[a;ob;rs] ok:cEOk[rs]; b:(,14),ob; c:b,bEncU32[#a]; d:c,cESeqBytes[rs]; :[ok; (1;d); cEFirstErr[rs]]}
cETxnB:{[ops;ib;st;rs] ok:cEOk[rs]; a:(,16),ib; b:a,bEncU32[#ops]; c:b,cESeqBytes[rs]; d:c,(,st); :[ok; (1;d); cEFirstErr[rs]]}
cEncIntsStep:{[acc;v] acc,kI64ToBytes[v]}
cEncInts:{[vs] cEncIntsStep/((,!0),vs)}
cEncFltSeqStep:{[acc;v] :[acc[0]=0; acc; cEncFltSeqStep2[acc;v]]}
cEncFltSeqStep2:{[acc;v] e:cEncFltE[v]; :[e[0]=0; e; (1;acc[1],e[1])]}
cEncFltSeq:{[vs] r:cEncFltSeqStep/((,(1;!0)),vs); :[r[0]=0; r; (1;r[1])]}
cEncSymSeqStep:{[acc;y] acc,bEncStr[_ic $y]}
cEncSymSeq:{[ks] cEncSymSeqStep/((,!0),ks)}
cEncCol:{[col] :[(-1)=4:col; (1;(,1),bEncU32[#col],cEncInts[col]); :[(-2)=4:col; cEncColFlt[col]; :[(-3)=4:col; (1;(,3),bEncU32[#col],_ic col); :[(-4)=4:col; (1;(,4),bEncU32[#col],cEncSymSeq[col]); (0;"type")]]]]}
cEncColFlt:{[col] r:cEncFltSeq[col]; :[r[0]=0; r; (1;(,2),bEncU32[#col],r[1])]}
cEncColSeqStep:{[acc;col] :[acc[0]=0; acc; cEncColSeqStep2[acc;col]]}
cEncColSeqStep2:{[acc;col] e:cEncCol[col]; :[e[0]=0; e; (1;acc[1],e[1])]}
cEncColSeq:{[cs] r:cEncColSeqStep/((,(1;!0)),cs); :[r[0]=0; r; (1;r[1])]}
cEncField:{[f] bEncStr[_ic $f[0]],(,((oKindSyms?f[1])+1)),(,f[2])}
cEncFieldSeqStep:{[acc;f] acc,cEncField[f]}
cEncFieldSeq:{[fs] cEncFieldSeqStep/((,!0),fs)}
cEncode:{[x] :[cIsNull[x]; (1;bFrame[17;!0]); :[oIsValid[x]; cEncodeV[x]; (0;"valid")]]}
cEncodeV:{[x] r:cE[x;0]; :[r[0]=0; r; cEncodeV2[r]]}
cEncodeV2:{[r] (1;bFrame[r[1][0];1 _ r[1]])}
/ Decoders. cDL is a single directly-recursive loop over an
/ explicit frame stack: state (bytes;frames;hasout;out). A frame
/ is (kind;remaining;values;extra) for list, dict, plan, txn.
/ Leaf objects decode through non-repeating helpers; compound
/ headers push a frame and the loop continues; a completed
/ object is consumed into its parent frame, and when a frame
/ empties it assembles into a new completed object. The top
/ object completes when a completed object meets an empty
/ stack. Only cDL recurses, and only onto itself, because
/ Kona voids a :[...] branch call that transitively repeats
/ its own function through another function (proven by the
/ mini-bm/mini-bp probes); direct self-recursion is safe.
/ Depth is the number of open frames: an object decoded while
/ more than kMAXDEPTH frames are open fails with "depth".
cDLTop:{[fr] fr[(#fr)-1]}
cDLPop:{[fr] -1 _ fr}
cDLUpd:{[f;obj] (f[0];f[1]-1;f[2],(,obj);f[3])}
cDLAsmObj:{[f] :[f[0]~`list; (`list;f[2]); :[f[0]~`dict; (`dict;(f[3];f[2])); (`plan;(f[3];f[2]))]]}
cDLAsmTxn:{[f;bs;pop] :[(0=#bs); (0;"trunc"); :[(~(bs[0]<0))&(~(2<bs[0])); (1;((1 _ bs;pop;1;(`txn;(f[3];f[2];bs[0]))))); (0;"range")]]}
cDLAsmSt:{[f;bs;pop] :[f[0]~`txn; cDLAsmTxn[f;bs;pop]; (1;((bs;pop;1;cDLAsmObj[f])))]}
cDLLeafX:{[r] :[r[0]=0; r; (1;(r[1][1][0];r[1][0]))]}
cDLLeaf:{[t;bs] :[t=1; cDLLeafX[cDQInt[bs;!0;1;0]]; :[t=2; cDLLeafX[cDQFlt[bs;!0;1;0]]; :[t=3; cDLLeafX[cDQStr[bs;!0;1;0]]; :[t=4; cDLLeafX[cDQSym[bs;!0;1;0]]; :[t=5; cDLLeafX[cDQIntVec[bs;!0;1;0]]; :[t=6; cDLLeafX[cDQFltVec[bs;!0;1;0]]; :[t=9; cDLLeafX[cDQTable[bs;!0;1;0]]; :[t=10; cDLLeafX[cDQTime[bs;!0;1;0]]; :[t=11; cDLLeafX[cDQIntMat[bs;!0;1;0]]; :[t=12; cDLLeafX[cDQFltMat[bs;!0;1;0]]; :[t=13; cDLLeafX[cDQSchema[bs;!0;1;0]]; :[t=15; cDLLeafX[cDQRef[bs;!0;1;0]]; (0;"tag")]]]]]]]]]]]]}
cDL:{[st] :[st[2]; :[(0=#st[1]); (1;(st[0];st[3])); :[(0<cDLTop[st[1]][1]-1); cDL[(st[0];(cDLPop[st[1]]),(,cDLUpd[cDLTop[st[1]];st[3]]);0;!0)]; :[(cDLAsmSt[cDLUpd[cDLTop[st[1]];st[3]];st[0];cDLPop[st[1]]])[0]=0; cDLAsmSt[cDLUpd[cDLTop[st[1]];st[3]];st[0];cDLPop[st[1]]]; cDL[(cDLAsmSt[cDLUpd[cDLTop[st[1]];st[3]];st[0];cDLPop[st[1]]])[1]]]]]; :[(0=#st[0]); (0;"trunc"); :[(#st[1])>kMAXDEPTH; (0;"depth"); :[(st[0][0]<1)|(st[0][0]>17); (0;"tag"); :[st[0][0]=17; cDL[(1 _ st[0];st[1];1;(`null;!0))]; :[~((st[0][0]=7)|(st[0][0]=8)|(st[0][0]=14)|(st[0][0]=16)|(st[0][0]=17)); :[(cDLLeaf[st[0][0];1 _ st[0]])[0]=0; (0;(cDLLeaf[st[0][0];1 _ st[0]])[1]); cDL[((cDLLeaf[st[0][0];1 _ st[0]])[1][1];st[1];1;(cDLLeaf[st[0][0];1 _ st[0]])[1][0])]]; :[st[0][0]=7; :[(cDecCnt[1 _ st[0]])[0]=0; (0;(cDecCnt[1 _ st[0]])[1]); :[(cDecCnt[1 _ st[0]])[1][0]=0; cDL[((cDecCnt[1 _ st[0]])[1][1];st[1];1;(`list;!0))]; cDL[((cDecCnt[1 _ st[0]])[1][1];st[1],(,(`list;(cDecCnt[1 _ st[0]])[1][0];!0;!0));0;!0)]]]; :[st[0][0]=8; :[(cDecCnt[1 _ st[0]])[0]=0; (0;(cDecCnt[1 _ st[0]])[1]); :[(cDecSyms[(cDecCnt[1 _ st[0]])[1][0];(cDecCnt[1 _ st[0]])[1][1]])[0]=0; (0;(cDecSyms[(cDecCnt[1 _ st[0]])[1][0];(cDecCnt[1 _ st[0]])[1][1]])[1]); :[(cDecCnt[1 _ st[0]])[1][0]=0; cDL[((cDecSyms[(cDecCnt[1 _ st[0]])[1][0];(cDecCnt[1 _ st[0]])[1][1]])[1][1];st[1];1;(`dict;((cDecSyms[(cDecCnt[1 _ st[0]])[1][0];(cDecCnt[1 _ st[0]])[1][1]])[1][0];!0)))]; cDL[((cDecSyms[(cDecCnt[1 _ st[0]])[1][0];(cDecCnt[1 _ st[0]])[1][1]])[1][1];st[1],(,(`dict;(cDecCnt[1 _ st[0]])[1][0];!0;(cDecSyms[(cDecCnt[1 _ st[0]])[1][0];(cDecCnt[1 _ st[0]])[1][1]])[1][0]));0;!0)]]]]; :[st[0][0]=14; :[(cDecSymE[1 _ st[0]])[0]=0; (0;(cDecSymE[1 _ st[0]])[1]); :[((oPlanOps?(cDecSymE[1 _ st[0]])[1][0])<7); :[(cDecCnt[(cDecSymE[1 _ st[0]])[1][1]])[0]=0; (0;(cDecCnt[(cDecSymE[1 _ st[0]])[1][1]])[1]); :[(cDecCnt[(cDecSymE[1 _ st[0]])[1][1]])[1][0]=0; cDL[((cDecCnt[(cDecSymE[1 _ st[0]])[1][1]])[1][1];st[1];1;(`plan;((cDecSymE[1 _ st[0]])[1][0];!0)))]; cDL[((cDecCnt[(cDecSymE[1 _ st[0]])[1][1]])[1][1];st[1],(,(`plan;(cDecCnt[(cDecSymE[1 _ st[0]])[1][1]])[1][0];!0;(cDecSymE[1 _ st[0]])[1][0]));0;!0)]]]; (0;"op")]]; :[st[0][0]=16; :[(#1 _ st[0])<8; (0;"trunc"); :[((kBytesToI64[8#1 _ st[0]])[1]<0); (0;"range"); :[(cDecCnt[8 _ 1 _ st[0]])[0]=0; (0;(cDecCnt[8 _ 1 _ st[0]])[1]); :[(cDecCnt[8 _ 1 _ st[0]])[1][0]=0; :[(0=#(cDecCnt[8 _ 1 _ st[0]])[1][1]); (0;"trunc"); :[(~(((cDecCnt[8 _ 1 _ st[0]])[1][1])[0]<0))&(~(2<((cDecCnt[8 _ 1 _ st[0]])[1][1])[0])); cDL[((1 _ (cDecCnt[8 _ 1 _ st[0]])[1][1]);st[1];1;(`txn;((kBytesToI64[8#1 _ st[0]])[1];!0;((cDecCnt[8 _ 1 _ st[0]])[1][1])[0])))]; (0;"range")]]; cDL[((cDecCnt[8 _ 1 _ st[0]])[1][1];st[1],(,(`txn;(cDecCnt[8 _ 1 _ st[0]])[1][0];!0;(kBytesToI64[8#1 _ st[0]])[1]));0;!0)]]]]]; (0;"tag")]]]]]]]]]]}
cDQInt:{[bs;vals;n;d] :[(#bs)<8; (0;"trunc"); (1;((8 _ bs);(vals,(,(`int;(kBytesToI64[8#bs])[1])));n-1;d))]}
cDQFlt:{[bs;vals;n;d] r:cDecFltE[bs]; :[r[0]=0; r; (1;(r[1][1];(vals,(,(`flt;r[1][0])));n-1;d))]}
cDQStr:{[bs;vals;n;d] r:cDecLenStr[bs]; :[r[0]=0; r; (1;(r[1][1];(vals,(,(`str;r[1][0])));n-1;d))]}
cDQSym:{[bs;vals;n;d] r:cDecSymE[bs]; :[r[0]=0; r; (1;(r[1][1];(vals,(,(`sym;r[1][0])));n-1;d))]}
cDQIntVec:{[bs;vals;n;d] r:cDecCnt[bs]; :[r[0]=0; r; cDQIntVecR[r;vals;n;d]]}
cDQIntVecR:{[r;vals;n;d] :[(#r[1][1])<(8*r[1][0]); (0;"trunc"); (1;(((8*r[1][0]) _ r[1][1]);(vals,(,(`intvec;cDecInts[r[1][0];r[1][1]])));n-1;d))]}
cDQFltVec:{[bs;vals;n;d] r:cDecCnt[bs]; :[r[0]=0; r; cDQFltVecR[r;vals;n;d]]}
cDQFltVecR:{[r;vals;n;d] fr:cDecFlts[r[1][0];r[1][1]]; :[fr[0]=0; fr; (1;(fr[1][1];(vals,(,(`fltvec;fr[1][0])));n-1;d))]}
cDQTable:{[bs;vals;n;d] r:cDecCnt[bs]; :[r[0]=0; r; cDQTableR[r;vals;n;d]]}
cDQTableR:{[r;vals;n;d] :[r[1][0]>kMAXCOLS; (0;"limit"); cDQTableR2[r;vals;n;d]]}
cDQTableR2:{[r;vals;n;d] kr:cDecSyms[r[1][0];r[1][1]]; :[kr[0]=0; kr; cDQTableR3[r;vals;n;d;kr]]}
cDQTableR3:{[r;vals;n;d;kr] cr:cDecCols[r[1][0];kr[1][1]]; :[cr[0]=0; cr; (1;(cr[1][1];(vals,(,(`table;(kr[1][0];cr[1][0]))));n-1;d))]}
cDQTime:{[bs;vals;n;d] :[(#bs)<9; (0;"trunc"); cDQTimeR[bs;vals;n;d]]}
cDQTimeR:{[bs;vals;n;d] s:bs[0]; v:(kBytesToI64[8#(1 _ bs)])[1]; :[(~(s<0))&(~(2<s)); :[(s=2); :[(~(v<0))&(v<86400000000000); (1;((9 _ bs);(vals,(,(`time;(s;v))));n-1;d)); (0;"range")]; (1;((9 _ bs);(vals,(,(`time;(s;v))));n-1;d))]; (0;"range")]}
cDQIntMat:{[bs;vals;n;d] :[(#bs)<8; (0;"trunc"); cDQIntMatR[bs;vals;n;d]]}
cDQIntMatR:{[bs;vals;n;d] r:(bDecU32[4#bs]); c:(bDecU32[4#(4 _ bs)]); cDQIntMatR2[r;c;8 _ bs;vals;n;d]}
cDQIntMatR2:{[r;c;rest;vals;n;d] p:kChkMul[r;c]; :[p[0]=0; (0;"overflow"); cDQIntMatR3[r;c;p[1];rest;vals;n;d]]}
cDQIntMatR3:{[r;c;mn;rest;vals;n;d] :[mn>kMAXLEN; (0;"limit"); :[(#rest)<(8*mn); (0;"trunc"); (1;(((8*mn) _ rest);(vals,(,(`intmat;(r;c;cDecInts[mn;rest]))));n-1;d))]]}
cDQFltMat:{[bs;vals;n;d] :[(#bs)<8; (0;"trunc"); cDQFltMatR[bs;vals;n;d]]}
cDQFltMatR:{[bs;vals;n;d] r:(bDecU32[4#bs]); c:(bDecU32[4#(4 _ bs)]); cDQFltMatR2[r;c;8 _ bs;vals;n;d]}
cDQFltMatR2:{[r;c;rest;vals;n;d] p:kChkMul[r;c]; :[p[0]=0; (0;"overflow"); cDQFltMatR3[r;c;p[1];rest;vals;n;d]]}
cDQFltMatR3:{[r;c;mn;rest;vals;n;d] :[mn>kMAXLEN; (0;"limit"); cDQFltMatR4[r;c;mn;rest;vals;n;d]]}
cDQFltMatR4:{[r;c;mn;rest;vals;n;d] fr:cDecFlts[mn;rest]; :[fr[0]=0; fr; (1;(fr[1][1];(vals,(,(`fltmat;(r;c;fr[1][0]))));n-1;d))]}
cDQSchema:{[bs;vals;n;d] r:cDecCnt[bs]; :[r[0]=0; r; cDQSchemaR[r;vals;n;d]]}
cDQSchemaR:{[r;vals;n;d] :[r[1][0]>kMAXCOLS; (0;"limit"); cDQSchemaR2[r;vals;n;d]]}
cDQSchemaR2:{[r;vals;n;d] fr:cDecFields[r[1][0];r[1][1]]; :[fr[0]=0; fr; (1;(fr[1][1];(vals,(,(`schema;fr[1][0])));n-1;d))]}
cDQRef:{[bs;vals;n;d] :[(#bs)<24; (0;"trunc"); cDQRefR[bs;vals;n;d]]}
cDQRefR:{[bs;vals;n;d] s:(kBytesToI64[8#bs])[1]; o:(kBytesToI64[8#(8 _ bs)])[1]; l:(kBytesToI64[8#(16 _ bs)])[1]; :[(~(s<0))&(~(o<0))&(~(l<0)); :[~(kMAXPAYLOAD<l); (1;((24 _ bs);(vals,(,(`ref;(s;o;l))));n-1;d)); (0;"limit")]; (0;"range")]}
/ Shared readers and leaf sequence decoders, all returning
/ remaining bytes (never consumed counts).
cDecLenStr:{[bs] :[(#bs)<4; (0;"trunc"); cDecLenStrR[bs]]}
cDecLenStrR:{[bs] ln:bDecU32[4#bs]; :[ln>kMAXLEN; (0;"limit"); :[(#bs)<(4+ln); (0;"trunc"); (1;((_ci (ln#(4 _ bs)));(4+ln) _ bs))]]}
cDecSymE:{[bs] r:cDecLenStr[bs]; :[r[0]=0; r; cDecSymE2[r]]}
cDecSymE2:{[r] s:r[1][0]; :[(#s)>kMAXNAME; (0;"limit"); (1;((`$s);r[1][1]))]}
cDecFltE:{[bs] :[(0=#bs); (0;"trunc"); cDecFltC[bs[0];1 _ bs]]}
cDecFltC:{[c;rest] :[c=0; (1;((0.0%0.0);rest)); :[c=1; (1;((1.0%0.0);rest)); :[c=2; (1;((-(1.0%0.0));rest)); :[c=3; (1;(0.0;rest)); :[c=4; cDecFltS[rest]; (0;"tag")]]]]]}
cDecFltS:{[rest] r:cDecLenStr[rest]; :[r[0]=0; r; cDecFltS2[r]]}
cDecFltS2:{[r] v:cStrToFlt[r[1][0]]; :[v[0]=0; v; (1;(v[1];r[1][1]))]}
cDecIntsStep:{[acc;ignored] v:(kBytesToI64[8#acc[1]])[1]; (acc[0],v;8 _ acc[1])}
cDecInts:{[n;rest] (cDecIntsStep/((,(!0;rest)),!n))[0]}
cDecFltsStep:{[acc;ignored] :[acc[0]=0; acc; cDecFltsStep2[acc]]}
cDecFltsStep2:{[acc] r:cDecFltE[acc[2]]; :[r[0]=0; (0;r[1];acc[2]); (1;acc[1],(r[1][0]);r[1][1])]}
cDecFlts:{[n;rest] r:cDecFltsStep/((,(1;0#1.0 2.0;rest)),!n); :[r[0]=0; (0;r[1]); (1;(r[1];r[2]))]}
cDecSymsStep:{[acc;ignored] :[acc[0]=0; acc; cDecSymsStep2[acc]]}
cDecSymsStep2:{[acc] r:cDecSymE[acc[2]]; :[r[0]=0; (0;r[1];acc[2]); (1;acc[1],(r[1][0]);r[1][1])]}
cDecSyms:{[n;rest] r:cDecSymsStep/((,(1;!0;rest)),!n); :[r[0]=0; (0;r[1]); (1;(r[1];r[2]))]}
cDecCol:{[bs] :[(0=#bs); (0;"trunc"); cDecColT[bs[0];1 _ bs]]}
cDecColT:{[t;rest] :[t=1; cDecColInt[rest]; :[t=2; cDecColFlt[rest]; :[t=3; cDecColChar[rest]; :[t=4; cDecColSym[rest]; (0;"tag")]]]]}
cDecColInt:{[rest] r:cDecCnt[rest]; :[r[0]=0; r; :[(#r[1][1])<(8*r[1][0]); (0;"trunc"); (1;(cDecInts[r[1][0];r[1][1]];(8*r[1][0]) _ r[1][1]))]]}
cDecColFlt:{[rest] r:cDecCnt[rest]; :[r[0]=0; r; cDecColFltR[r[1][0];r[1][1]]]}
cDecColFltR:{[n;rest] fr:cDecFlts[n;rest]; :[fr[0]=0; fr; (1;(fr[1][0];fr[1][1]))]}
cDecColChar:{[rest] r:cDecCnt[rest]; :[r[0]=0; r; :[(#r[1][1])<(r[1][0]); (0;"trunc"); (1;((_ci ((r[1][0])#r[1][1]));(r[1][0]) _ r[1][1]))]]}
cDecColSym:{[rest] r:cDecCnt[rest]; :[r[0]=0; r; cDecColSymR[r[1][0];r[1][1]]]}
cDecColSymR:{[n;rest] sr:cDecSyms[n;rest]; :[sr[0]=0; sr; (1;(sr[1][0];sr[1][1]))]}
cDecColsStep:{[acc;ignored] :[acc[0]=0; acc; cDecColsStep2[acc]]}
cDecColsStep2:{[acc] r:cDecCol[acc[2]]; :[r[0]=0; (0;r[1];acc[2]); (1;acc[1],(,r[1][0]);r[1][1])]}
cDecCols:{[n;rest] r:cDecColsStep/((,(1;!0;rest)),!n); :[r[0]=0; (0;r[1]); (1;(r[1];r[2]))]}
cDecField:{[bs] r:cDecSymE[bs]; :[r[0]=0; r; cDecFieldR[r]]}
cDecFieldR:{[r] rest:r[1][1]; :[(#rest)<2; (0;"trunc"); cDecFieldR2[r;rest]]}
cDecFieldR2:{[r;rest] t:rest[0]; u:rest[1]; :[(~(t<1))&(~(16<t)); :[(u=0)|(u=1); (1;(((r[1][0];oKindSyms[t-1];u));2 _ rest)); (0;"range")]; (0;"tag")]}
cDecFieldsStep:{[acc;ignored] :[acc[0]=0; acc; cDecFieldsStep2[acc]]}
cDecFieldsStep2:{[acc] r:cDecField[acc[2]]; :[r[0]=0; (0;r[1];acc[2]); (1;acc[1],(,r[1][0]);r[1][1])]}
cDecFields:{[n;rest] r:cDecFieldsStep/((,(1;!0;rest)),!n); :[r[0]=0; (0;r[1]); (1;(r[1];r[2]))]}
/ Top-level decode: frame validation, tag dispatch, exact
/ consumption, then the semantic gate.
cDecode:{[fr] u:bUnframe[fr]; :[u[0]=0; (0;u[1]); cDecodeT[u[1];u[2]]]}
cDecodeT:{[t;p] :[(t<1)|(t>17); (0;"tag"); cDecodeK[t;p]]}
cDecodeK:{[t;p] r:cDL[((,t),p;!0;0;!0)]; :[r[0]=0; r; :[(0=#r[1][0]); cDecodeV[r[1][1]]; (0;"trailing")]]}
cDecodeV:{[obj] :[cIsNull[obj]; (1;obj); :[oIsValid[obj]; (1;obj); (0;"valid")]]}
/ Metadata inspection: frame validation plus header fields
/ only, never a full decode of nested data.
cMeta:{[fr] u:bUnframe[fr]; :[u[0]=0; (0;u[1]); cMetaT[u[1];u[2]]]}
cMetaT:{[t;p] :[(t<1)|(t>17); (0;"tag"); cMetaK[cKindOfTag[t];p]]}
cMetaK:{[k;p] :[k~`null; (1;(`null;!0)); :[((oKindLo?k)<8); cMetaLo[k;p]; cMetaHi[k;p]]]}
cMetaLo:{[k;p] :[k~`int; cMetaInt[p]; :[k~`flt; cMetaFlt[p]; :[k~`str; cMetaStr[p]; :[k~`sym; cMetaSym[p]; :[k~`intvec; cMetaCnt[p;`intvec]; :[k~`fltvec; cMetaCnt[p;`fltvec]; :[k~`list; cMetaCnt[p;`list]; :[k~`dict; cMetaCnt[p;`dict]; (0;"tag")]]]]]]]]}
cMetaHi:{[k;p] :[k~`table; cMetaCnt[p;`table]; :[k~`time; cMetaTime[p]; :[k~`intmat; cMetaMat[p;`intmat]; :[k~`fltmat; cMetaMat[p;`fltmat]; :[k~`schema; cMetaCnt[p;`schema]; :[k~`plan; cMetaPlan[p]; :[k~`ref; cMetaRef[p]; :[k~`txn; cMetaTxn[p]; (0;"tag")]]]]]]]]}
cMetaInt:{[p] :[(#p)<8; (0;"trunc"); (1;(`int;8))]}
cMetaFlt:{[p] :[(0=#p); (0;"trunc"); (1;(`flt;p[0]))]}
cMetaStr:{[p] :[(#p)<4; (0;"trunc"); (1;(`str;(bDecU32[4#p])))]}
cMetaSym:{[p] :[(#p)<4; (0;"trunc"); (1;(`sym;(bDecU32[4#p])))]}
cMetaCnt:{[p;k] :[(#p)<4; (0;"trunc"); (1;(k;(bDecU32[4#p])))]}
cMetaTime:{[p] :[(0=#p); (0;"trunc"); (1;(`time;p[0]))]}
cMetaMat:{[p;k] :[(#p)<8; (0;"trunc"); (1;(k;((bDecU32[4#p]);(bDecU32[4#(4 _ p)]))))]}
cMetaPlan:{[p] r:cDecSymE[p]; :[r[0]=0; r; (1;(`plan;r[1][0]))]}
cMetaRef:{[p] :[(#p)<8; (0;"trunc"); (1;(`ref;(kBytesToI64[8#p])[1]))]}
cMetaTxn:{[p] :[(#p)<8; (0;"trunc"); (1;(`txn;(kBytesToI64[8#p])[1]))]}







