bValid:{[b] ((-1=4:b)|(0=4:b))&(&/~(b<0))&(&/~(255<b))}

/ Modulo for non-negative a and positive m (Kona % is int division).
bMod:{[a;m] a-m*a%m}

/ Fixed-width unsigned encoders (big-endian, int lists).
bEncU8:{[v] ,v}
bEncU16:{[v] (v%256),bMod[v;256]}
bEncU32:{[v] (v%16777216),((bMod[v;16777216])%65536),((bMod[v;65536])%256),bMod[v;256]}

/ Fixed-width unsigned decoders (input must be exactly the right length).
bDecU8:{[b] b[0]}
bDecU16:{[b] (256*b[0])+b[1]}
bDecU32:{[b] (16777216*b[0])+(65536*b[1])+(256*b[2])+b[3]}

/ Signed encoders: two's complement, then unsigned.
bEncI8:{[v] :[v<0; bEncU8[v+256]; bEncU8[v]]}
bEncI16:{[v] :[v<0; bEncU16[v+65536]; bEncU16[v]]}
bEncI32:{[v] :[v<0; bEncU32[v+4294967296]; bEncU32[v]]}

/ Signed decoders.
bDecI8:{[b] u:bDecU8[b]; :[u>127; u-256; u]}
bDecI16:{[b] u:bDecU16[b]; :[u>32767; u-65536; u]}
bDecI32:{[b] u:bDecU32[b]; :[u>2147483647; u-4294967296; u]}

/ u64 as a (hi;lo) u32 pair: Kona has no unsigned 64-bit atom.
bEncU64:{[h;l] bEncU32[h],bEncU32[l]}
bDecU64:{[b] (bDecU32[4#b]; bDecU32[4 _ b])}

/ Length-prefixed byte string: u32be length, then the bytes. Exact
/ consumption: trailing bytes are a length failure.
bEncStr:{[p] bEncU32[#p],p}
bStrLen:{[b] :[(#b)<4; 0; bDecU32[4#b]]}
bDecStr:{[b] n:bStrLen[b]; :[(#b)<4; (0;"short";!0); :[~((#b)=(4+n)); (0;"length";!0); (1;n#4 _ b;!0)]]}

/ Checksum: Adler-style, two accumulators mod 65521, combined as
/ s2*65536+s1. Computed vectorized: s1 is 1+sum, s2 is the sum of the
/ running s1 values, and mod distributes over addition, so the
/ vectorized form equals the stepwise form exactly. Intermediates fit
/ in Kona's signed 64-bit ints for inputs under ~2^27 bytes; larger
/ inputs must be checksummed in chunks (a Layer 4 rule).
/ This is an integrity checksum only, never proof of authenticity.
bCksum:{[b] s1:1+ +/b; s2:+/1+ +\b; (bMod[s2;65521]*65536)+bMod[s1;65521]}

/ Framed value: magic KSB+ (75 83 66 43), version 1, type byte,
/ u32be payload length, payload, u32be checksum of everything before
/ the checksum field. Total overhead 14 bytes. Packed: no padding.
/ Version 1 only; any other version is rejected, never tolerated.
bFrame:{[t;p] body:(75 83 66 43),1,t,bEncU32[#p],p; body,bEncU32[bCksum[body]]}

/ Declared payload length, or 0 when the input is too short to hold
/ a length field. Internal helper for bUnframe.
bFrameLen:{[b] :[(#b)<10; 0; bDecU32[4#6 _ b]]}

/ Validate a framed value. Success: (1;type;payload). Failure:
/ (0;reason;!0) with reason one of short, magic, version, length,
/ checksum. Trailing bytes after a valid frame are a length failure.
bUnframe:{[b] n:#b; ln:bFrameLen[b]; :[n<14; (0;"short";!0); :[~((75 83 66 43)~4#b); (0;"magic";!0); :[~(1=b[4]); (0;"version";!0); :[~(n=14+ln); (0;"length";!0); :[~(bDecU32[4#(10+ln) _ b]=bCksum[(10+ln)#b]); (0;"checksum";!0); (1;b[5];ln#10 _ b)]]]]]}

/ Continuation byte: 128..191.
bCont:{[x] (~(x<128))&(~(191<x))}

/ Well-formed UTF-8, strict: rejects overlong forms (192,193 leads;
/ E0 with a low second byte; F0 with a low second byte), surrogates
/ (ED with a high second byte), values above U+10FFFF (F5+ leads),
/ lone continuations, and truncated sequences. Bytes are not text:
/ Layer 0 strings are byte sequences; this validator is the one
/ place a byte sequence earns the name string.
butf8ok:{[b] :[0=#b; 1; :[b[0]<128; butf8ok[1 _ b]; :[b[0]<192; 0; :[b[0]<194; 0; :[b[0]<224; :[(#b)<2; 0; :[bCont[b[1]]; butf8ok[2 _ b]; 0]]; :[b[0]<240; :[(#b)<3; 0; :[bCont[b[1]]&bCont[b[2]]&:[b[0]=224; (~(b[1]<160))&(~(191<b[1])); :[b[0]=237; (~(b[1]<128))&(~(159<b[1])); 1]]; butf8ok[3 _ b]; 0]]; :[b[0]<245; :[(#b)<4; 0; :[bCont[b[1]]&bCont[b[2]]&bCont[b[3]]&:[b[0]=240; (~(b[1]<144))&(~(191<b[1])); :[b[0]=244; (~(b[1]<128))&(~(143<b[1])); 1]]; butf8ok[4 _ b]; 0]]; 0]]]]]]]}

/ Layer 0 unification additions (branch unify-layer0). Grok's unique
/ correct behaviors, added additively in Kona. The build's frame
/ (magic/version/type/u32 length/Adler) is UNCHANGED, so Layers 1-7
/ keep passing. New decoders return (1;value;rest) on success and
/ (0;reason;!0) on failure, mirroring bDecStr's triple shape. New
/ encoders return (1;bytes;!0) on success and (0;reason;!0) on
/ failure, mirroring Grok's (`ok/`err) results in build style.
/ Float specials use the Layer 1 lessons, inlined here because l00
/ loads before l01 and cannot call kFIsNan: NaN is the only value
/ less than -Inf; infinities are detected by x-x being NaN.
/ Kona float model, verified by execution: Kona holds -0.0 for
/ display but no predicate distinguishes it from +0.0, and division
/ by either zero gives +Inf, so the encoder maps both zeros to
/ +0.0 bytes; the decoder returns the -0.0 literal for sign 1.
/ Kona float literals can exceed binary64 range (the max-double
/ decimal parses to 2^1024), so the encoder rounds to nearest even
/ (IEEE default) instead of Grok's floor, which is exact only for
/ binary64 inputs: for a Kona float with extra mantissa bits,
/ floor would be 1 ulp low (verified: the 0.1 literal). Inputs
/ beyond binary64 range encode to infinities (IEEE overflow);
/ inputs too small for subnormals encode to signed zero (IEEE
/ underflow). CRC-32 is byte-recursive (test-scale inputs); large
/ inputs must be checksummed in chunks, the same rule as bCksum.
bFNEGI:-(1.0%0.0)
bFPOSI:(1.0%0.0)
bF64MANT:4503599627370496.0
bF64MINN:2.0^-1022
bF64I52:2.0^-52
bFIsNan:{[x] x<bFNEGI}
bFIsPosInf:{[x] (~bFIsNan[x])&(x>0)&bFIsNan[x-x]}
bFIsNegInf:{[x] (~bFIsNan[x])&(x<0)&bFIsNan[x-x]}
bF64Step:{[p] a:p[0]; e:p[1]; :[~((a-2)<0); (a%2;e+1); :[((a-1)<0)&(e>-1022); (a*2;e-1); p]]}
bF64Pack:{[sign;exp;mant] ((sign*128)+(exp%16);(bMod[exp;16]*16)+(mant%281474976710656);bMod[mant%1099511627776;256];bMod[mant%4294967296;256];bMod[mant%16777216;256];bMod[mant%65536;256];bMod[mant%256;256];bMod[mant;256])}
bF64RNE:{[p] m0:_(p); f:p-m0; d:f-0.5; :[(d<0); m0; :[0=d; :[0=bMod[m0;2]; m0; m0+1]; m0+1]]}
bEncF64N:{[sign;af;e] mant:bF64RNE[(af-1)*bF64MANT]; exp:e+1023; :[~(exp<2047); (1;:[sign=1;255 240 0 0 0 0 0 0;127 240 0 0 0 0 0 0];!0); :[mant=4503599627370496; :[exp=2046; (1;:[sign=1;255 240 0 0 0 0 0 0;127 240 0 0 0 0 0 0];!0); (1;bF64Pack[sign;exp+1;0];!0)]; (1;bF64Pack[sign;exp;mant];!0)]]}
bEncF64S:{[sign;af] mant:bF64RNE[af*bF64MANT]; :[mant=4503599627370496; (1;bF64Pack[sign;1;0];!0); (1;bF64Pack[sign;0;mant];!0)]}
bEncF64Fin:{[x] sign:((x<0)|((1.0%x)<0)); a:x*(1-2*sign); st:bF64Step/[1100;(a;0)]; af:st[0]; e:st[1]; :[~((af-2)<0); (1;:[sign=1;255 240 0 0 0 0 0 0;127 240 0 0 0 0 0 0];!0); :[~((af-1)<0); bEncF64N[sign;af;e]; bEncF64S[sign;af]]]}
bEncF64:{[x] :[~(2=4:x); (0;"type";!0); :[bFIsNan[x]; (1;127 248 0 0 0 0 0 0;!0); :[bFIsPosInf[x]; (1;127 240 0 0 0 0 0 0;!0); :[bFIsNegInf[x]; (1;255 240 0 0 0 0 0 0;!0); :[x=0; (1;0 0 0 0 0 0 0 0;!0); bEncF64Fin[x]]]]]]}
bDecF64Sub:{[mant] ((mant*1.0)*bF64I52)*bF64MINN}
bDecF64Norm:{[exp;mant] (1.0+((mant*1.0)*bF64I52))*(2.0^(exp-1023))}
bDecF64Val:{[sign;exp;mant] :[exp=2047; :[mant=0; :[sign=1;bFNEGI;bFPOSI]; 0.0%0.0]; :[exp=0; :[mant=0; :[sign=1;-0.0;0.0]; :[sign=1;-bDecF64Sub[mant];bDecF64Sub[mant]]]; :[sign=1;-bDecF64Norm[exp;mant];bDecF64Norm[exp;mant]]]]}
bDecF64B:{[b] sign:b[0]%128; exp:(bMod[b[0];128]*16)+(b[1]%16); mant:(bMod[b[1];16]*281474976710656)+(b[2]*1099511627776)+(b[3]*4294967296)+(b[4]*16777216)+(b[5]*65536)+(b[6]*256)+b[7]; (1;bDecF64Val[sign;exp;mant];8 _ b)}
bDecF64:{[b] :[(#b)<8; (0;"short";!0); bDecF64B[b]]}
bLEBLoop:{[v] :[v<128; ,v; (bMod[v;128]+128),bLEBLoop[v%128]]}
bEncLEB:{[v] :[~(1=4:v); (0;"type";!0); :[v<0; (0;"range";!0); (1;bLEBLoop[v];!0)]]}
bLEBWalk:{[b;i;acc;pow] :[~((#b)>i); (0;"truncated";!0); bLEBWalkL[b;i;acc;pow]]}
bLEBWalkL:{[b;i;acc;pow] :[i>8; (0;"limit";!0); bLEBWalkB[b;i;acc;pow]]}
bLEBWalkB:{[b;i;acc;pow] by:b[i]; :[by>127; bLEBWalk[b;i+1;acc+(by-128)*pow;pow*128]; (1;acc+by*pow;(i+1) _ b)]}
bDecLEB:{[b] r:bLEBWalk[b;0;0;1]; k:(#b)-#r[2]; e:bEncLEB[r[1]][1]; :[0=r[0]; r; :[k~#e; :[(k#b)~e; r; (0;"canonical";!0)]; (0;"canonical";!0)]]}
bEncOpt:{[p] :[~((0=p[0])|(1=p[0])); (0;"tag";!0); :[0=p[0]; (1;,0;!0); :[bValid[p[1]]; (1;1,bEncStr[p[1]];!0); (0;"type";!0)]]]}
bDecOptP:{[r] n:bStrLen[r]; :[(#r)<4; (0;"short";!0); :[(#r)<4+n; (0;"length";!0); (1;(1;n#4 _ r);(4+n) _ r)]]}
bDecOpt:{[b] :[(#b)<1; (0;"short";!0); :[b[0]=0; (1;(0;!0);1 _ b); :[b[0]=1; bDecOptP[1 _ b]; (0;"null";!0)]]]}
bPop:{[a] :[a=0; 0; bMod[a;2]+bPop[a%2]]}
bIsPow2:{[a] (1=4:a)&(a>0)&(a<65536)&(1=bPop[a])}
bAlignPad:{[a;b] :[~bIsPow2[a]; (0;"align";!0); :[~bValid[b]; (0;"type";!0); (1;b,(bMod[a-bMod[#b;a];a]#0);!0)]]}
bXorR:{[a;b;pow;acc] ba:bMod[a;2]; bb:bMod[b;2]; :[pow>2147483648; acc; bXorR[a%2;b%2;pow*2;acc+(ba+bb-2*ba*bb)*pow]]}
bXor32:{[a;b] bXorR[a;b;1;0]}
bCrcRounds:{[c;n] :[n=0; c; :[1=bMod[c;2]; bCrcRounds[bXor32[c%2;3988292384];n-1]; bCrcRounds[c%2;n-1]]]}
bCrcStep:{[c;by] bCrcRounds[bXor32[c;by];8]}
bCrcRec:{[b;c] :[0=#b; bXor32[c;4294967295]; bCrcRec[1 _ b; bCrcStep[c;b[0]]]]}
bCRC32:{[b] bCrcRec[b;4294967295]}
