/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 1: primitive numerical kernels.
/ Conventions, verified against Kona by execution.
/ - Checked functions return (1;value) on success and (0;reason) on
/   failure, where reason is one of overflow, div0, range, bounds,
/   empty, scale. Nothing wraps silently: raw Kona +,-,* wrap
/   two's complement (IMAX+1 becomes IMIN) and raw Kona % by zero
/   returns IMAX, so no public arithmetic here uses the raw verbs
/   on unvalidated operands.
/ - Raw functions are total on their documented domain; the domain
/   is stated in the comment above each one.
/ - Kona ints are signed 64-bit. IMAX prints as 0I and IMIN prints
/   as 0N, but both behave as ordinary two's complement values in
/   comparisons and arithmetic; they are NOT null sentinels here.
/   Missingness is never a sentinel value in KSB+: it is an explicit
/   tagged failure or a validity structure in a higher layer.
/ - Division is truncating toward zero (Kona %). kDivF is floor
/   division and kModF is the matching floor modulus (sign follows
/   the divisor). kRem is the truncating remainder (sign follows
/   the dividend).
/ - Kona has no bitwise operators. Shifts and masks are div/mod
/   arithmetic; bitwise AND/OR/XOR/NOT are defined on the domain
/   0..IMAX (bit 63 is the sign bit and is always 0 there).
/ - Float classification works around Kona's non-IEEE comparisons:
/   Kona's NaN (0n) compares less than everything, including -Inf,
/   and NaN=NaN is 1, so NaN is detected by x < -Inf, never by
/   x~=x. Kona collapses -0.0 to 0.0, so zero always encodes with
/   sign 0 in Layer 3.
/ - Hashing here is Adler-style plus mod-prime mixing. It is
/   deterministic and sufficient for buckets and symbol tables.
/   It is NOT cryptographic and is never claimed to be.

/ Shared resource limits (used by Layers 2 and 3 as well).
kMAXLEN:1000000
kMAXDEPTH:32
kMAXCOLS:256
kMAXNAME:128
kMAXPAYLOAD:67108864

/ Range constants.
kIMAX:9223372036854775807
kIMIN:(-9223372036854775807)-1

/ Checked addition. Overflow iff the sum would pass IMAX (both
/ positive side) or IMIN (both negative side). The threshold
/ subtractions fit: IMAX-a fits when a>0, IMIN-a fits when a<0.
kChkAdd:{[a;b] :[(a>0)&(b>kIMAX-a); (0;"overflow"); :[(a<0)&(b<kIMIN-a); (0;"overflow"); (1;a+b)]]}

/ Checked subtraction. a-b overflows iff a is above IMAX+b (b<0)
/ or below IMIN+b (b>0); both threshold additions fit.
kChkSub:{[a;b] :[(b<0)&(a>kIMAX+b); (0;"overflow"); :[(b>0)&(a<kIMIN+b); (0;"overflow"); (1;a-b)]]}

/ Checked multiplication, by division. The -1 cases come first
/ because IMIN%-1 would be the one trapping division. For the
/ remaining sign cases the threshold division fits and the
/ comparison against its truncation is exact: for a>0,b>0 the
/ threshold is a floor; for mixed signs the IMIN threshold is a
/ floor of a positive quotient; for a<0,b<0 the IMAX threshold is
/ a ceiling of a negative quotient, and a < ceiling is exactly
/ a < the real quotient for integer a.
kChkMul:{[a;b] :[(a=0)|(b=0); (1;0); :[(a=-1)|(b=-1); :[(a=kIMIN)|(b=kIMIN); (0;"overflow"); (1;a*b)]; :[(a>0)&(b>0); :[a>kIMAX%b; (0;"overflow"); (1;a*b)]; :[(a>0)&(b<0); :[a>kIMIN%b; (0;"overflow"); (1;a*b)]; :[(a<0)&(b>0); :[b>kIMIN%a; (0;"overflow"); (1;a*b)]; :[a<kIMAX%b; (0;"overflow"); (1;a*b)]]]]]]}

/ Truncating division. div0 and IMIN/-1 are errors, never the
/ raw Kona results (IMAX sentinel, or a wrapping/trapping divide).
kDiv:{[a;b] :[b=0; (0;"div0"); :[(a=kIMIN)&(b=-1); (0;"overflow"); (1;a%b)]]}

/ Truncating remainder, sign of the dividend. The product b*q
/ fits because |q| <= |a|/|b|, except IMIN/-1 which is guarded.
kRemRaw:{[a;b] q:a%b; (1;a-b*q)}
kRem:{[a;b] :[b=0; (0;"div0"); :[(a=kIMIN)&(b=-1); (0;"overflow"); kRemRaw[a;b]]]}

/ Floor division. The q-1 adjustment is safe: q equals IMIN only
/ for b=1 (remainder 0, no adjustment) or b=-1 (guarded above).
kDivFRaw:{[a;b] q:a%b; r:a-b*q; :[(r=0)|((a<0)&(b<0))|((a>0)&(b>0)); (1;q); (1;q-1)]}
kDivF:{[a;b] :[b=0; (0;"div0"); :[(a=kIMIN)&(b=-1); (0;"overflow"); kDivFRaw[a;b]]]}

/ Floor modulus, sign of the divisor. r+b fits because r and b
/ have opposite signs in the adjustment branch, so |r+b| < |b|.
kModFRaw:{[a;b] q:a%b; r:a-b*q; :[(r=0)|((a<0)&(b<0))|((a>0)&(b>0)); (1;r); (1;r+b)]}
kModF:{[a;b] :[b=0; (0;"div0"); :[(a=kIMIN)&(b=-1); (0;"overflow"); kModFRaw[a;b]]]}

/ Signed comparisons, raw and total.
kCmp:{[a;b] :[a<b; -1; :[a>b; 1; 0]]}
kLt:{[a;b] a<b}
kLe:{[a;b] ~(b<a)}
kGt:{[a;b] a>b}
kGe:{[a;b] ~(a<b)}
kEq:{[a;b] a=b}

/ Boolean operations on 0/1 values (they apply elementwise to
/ lists, as Kona verbs do). Domain is 0/1; other inputs are a
/ caller error, not a checked failure.
kNot:{[a] 1-a}
kAnd:{[a;b] a&b}
kOr:{[a;b] a|b}
kXor:{[a;b] (a|b)-(a&b)}

/ Power of two. Domain 0..62 only: 2^63 wraps to IMIN and negative
/ n recurses forever. Every caller validates the range first.
kPow2:{[n] :[n=0; 1; 2*kPow2[n-1]]}

/ Checked left shift (multiply by 2^n). Same threshold argument
/ as checked multiplication with a positive multiplier.
kShlCRaw:{[a;n] p:kPow2[n]; :[(a>0)&(a>kIMAX%p); (0;"overflow"); :[(a<0)&(a<kIMIN%p); (0;"overflow"); (1;a*p)]]}
kShlC:{[a;n] :[(n<0)|(n>62); (0;"range"); kShlCRaw[a;n]]}

/ Arithmetic (floor) right shift. The q-1 adjustment is safe:
/ q equals IMIN only for n=0, where the remainder is 0.
kShrRaw:{[a;n] d:kPow2[n]; q:a%d; r:a-d*q; :[(a<0)&(~(r=0)); (1;q-1); (1;q)]}
kShr:{[a;n] :[(n<0)|(n>62); (0;"range"); kShrRaw[a;n]]}

/ Mask of the low n bits. n=63 is excluded: 2^63 is not a mask.
/ The full non-negative range is kIMAX itself.
kMask:{[n] :[(n<0)|(n>62); (0;"range"); (1;(kPow2[n])-1)]}

/ Bitwise AND on 0..IMAX. Bits are extracted vectorized: bit i
/ is (a % 2^i) mod 2, using bMod because Kona % is division.
kBandRaw:{[a;b] p:(1,*\62#2); (1;+/(((bMod[a%p;2])*(bMod[b%p;2]))*p))}
kBand:{[a;b] :[(a<0)|(b<0); (0;"range"); kBandRaw[a;b]]}
kBor:{[a;b] c:kBand[a;b]; :[c[0]=0; c; (1;a+(b-c[1]))]}
kBxor:{[a;b] c:kBand[a;b]; :[c[0]=0; c; (1;(a-c[1])+(b-c[1]))]}
kBnotRaw:{[a;n] :[(a<0)|(a>(kPow2[n])-1); (0;"range"); (1;((kPow2[n])-1)-a)]}
kBnot:{[a;n] :[(n<0)|(n>62); (0;"range"); kBnotRaw[a;n]]}

/ 8-byte big-endian two's complement representation (Layer 0
/ byte order). Split at 2^32 with a floor adjustment for negative
/ values with nonzero remainder; both halves then fit their
/ Layer 0 encoders exactly.
kI64ToBytes:{[v] d:4294967296; q:v%d; r:v-d*q; :[(v<0)&(~(r=0)); bEncI32[q-1],bEncU32[r+d]; bEncI32[q],bEncU32[r]]}
kBytesToI64:{[bs] :[(#bs)=8; (1;(bDecI32[4#bs]*4294967296)+bDecU32[4 _ bs]); (0;"length")]}

/ Byte-list access with bounds checking.
kByteAt:{[bs;i] :[(i<0)|(i>((#bs)-1)); (0;"bounds"); (1;bs[i])]}
kByteSet:{[bs;i;v] :[(i<0)|(i>((#bs)-1))|(v<0)|(v>255); (0;"bounds"); (1;(i#bs),v,((i+1) _ bs))]}

/ Absolute value. IMIN has no negation in int64, so it is an
/ overflow, not a wrap.
kAbs:{[a] :[a=kIMIN; (0;"overflow"); (1;:[a<0; -a; a])]}

/ Fixed-point arithmetic on scaled integers. a means a/s.
/ Addition and subtraction need no rescaling; multiplication
/ divides by s once; division multiplies by s first. Rounding is
/ truncation toward zero unless the H variant is used (half away
/ from zero). Scales are positive ints; scales above 2^62 are
/ rejected by the H variant because 2*|r| must fit.
kFxAdd:{[a;b;s] :[s<1; (0;"scale"); kChkAdd[a;b]]}
kFxSub:{[a;b;s] :[s<1; (0;"scale"); kChkSub[a;b]]}
kFxMulRaw:{[a;b;s] p:kChkMul[a;b]; :[p[0]=0; p; (1;p[1]%s)]}
kFxMul:{[a;b;s] :[s<1; (0;"scale"); kFxMulRaw[a;b;s]]}
kFxMulHRaw:{[a;b;s] p:kChkMul[a;b]; :[p[0]=0; p; kFxMulHStep[p;s]]}
kFxMulHStep:{[p;s] q:p[1]%s; r:p[1]-s*q; ar:kAbs[r]; :[ar[0]=0; ar; :[(2*ar[1])<s; (1;q); (1;:[p[1]<0; q-1; q+1])]]}
kFxMulH:{[a;b;s] :[s<1; (0;"scale"); :[s>4611686018427387904; (0;"scale"); kFxMulHRaw[a;b;s]]]}
kFxDivRaw:{[a;b;s] p:kChkMul[a;s]; :[p[0]=0; p; :[(p[1]=kIMIN)&(b=-1); (0;"overflow"); (1;p[1]%b)]]}
kFxDiv:{[a;b;s] :[s<1; (0;"scale"); :[b=0; (0;"div0"); kFxDivRaw[a;b;s]]]}
kFxFromInt:{[a;s] :[s<1; (0;"scale"); kChkMul[a;s]]}
kFxToInt:{[a;s] :[s<1; (0;"scale"); (1;a%s)]}
kFxCmp:{[a;b] kCmp[a;b]}

/ Float classification. NaN first: Kona's NaN compares less than
/ -Inf, which no real value does. Infinities are then the values
/ that survive doubling with a sign. Zero is exact; Kona has no
/ -0.0 (it collapses to 0.0), so zero has no sign here.
/ Class codes: 0 NaN, 1 +Inf, 2 -Inf, 3 zero, 4 finite.
kFNEGI:-(1.0%0.0)
kFPOSI:(1.0%0.0)
kFIsNan:{[x] x<kFNEGI}
/ Inf test via x-x (NaN only for infinities): Kona's = and <
/ both miscompare max double against +Inf (max=Inf reads 1,
/ max<Inf reads 0), so the old x=2*x test classified max double
/ as +Inf. Fixed 2026-10-25 during Layer 3 (t01 re-run clean).
kFIsPosInf:{[x] (~kFIsNan[x])&(x>0)&kFIsNan[x-x]}
kFIsNegInf:{[x] (~kFIsNan[x])&(x<0)&kFIsNan[x-x]}
kFClass:{[x] :[kFIsNan[x]; 0; :[kFIsPosInf[x]; 1; :[kFIsNegInf[x]; 2; :[x=0; 3; 4]]]]}
kFSign:{[x] :[kFIsNan[x]; 0; :[x<0; -1; :[x>0; 1; 0]]]}

/ Deterministic reductions over int lists. Sums and products are
/ checked (a wrapping fold would be a silent error); min, max,
/ all, and any are total except on empty input for min/max.
/ Implemented as over-folds, not recursion: an earlier recursive
/ version (mutual helper recursion returning tagged pairs) silently
/ produced no output for non-empty lists in Kona, while direct
/ single-function recursion (r, butf8ok) works; the over form
/ avoids the pattern entirely and has no depth limit. Atoms are
/ rejected: a bare atom is not a list, and drop-based recursion
/ on an atom never shrinks (infinite recursion to stack error).
kSumStep:{[acc;x] :[acc[0]=0; acc; kChkAdd[acc[1];x]]}
kSumC:{[xs] :[(4:xs)>0; (0;"type"); kSumStep/((,(1;0)),xs)]}
kProdStep:{[acc;x] :[acc[0]=0; acc; kChkMul[acc[1];x]]}
kProdC:{[xs] :[(4:xs)>0; (0;"type"); kProdStep/((,(1;1)),xs)]}
kMin:{[xs] :[(4:xs)>0; (0;"type"); :[0=#xs; (0;"empty"); (1;&/xs)]]}
kMax:{[xs] :[(4:xs)>0; (0;"type"); :[0=#xs; (0;"empty"); (1;|/xs)]]}
kAll:{[xs] :[(4:xs)>0; (0;"type"); :[0=#xs; (1;1); (1;&/xs)]]}
kAny:{[xs] :[(4:xs)>0; (0;"type"); :[0=#xs; (1;0); (1;|/xs)]]}
kCount:{[xs] #xs}

/ Hashing primitives for later layers (buckets, symbol tables).
/ Adler-style over bytes, plus a mod-65521 mixing step. Products
/ stay below 65521*48271, so they always fit. NOT cryptographic.
kHashBytes:{[bs] bCksum[bs]}
kHashInt:{[a] bCksum[kI64ToBytes[a]]}
kHashStr:{[s] bCksum[_ic s]}
kHashMix:{[h] bMod[(bMod[h;65521]*48271);65521]}
kHashCombine:{[h1;h2] bMod[(bMod[h1;65521])+(31*bMod[h2;65521]);65521]}
kBucket:{[h;n] :[n<1; (0;"range"); (1;bMod[h;n])]}
