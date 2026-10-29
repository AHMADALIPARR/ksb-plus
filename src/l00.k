/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ KSB+ Sovereign Binary Database Engine
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/
/ This program is free software: you can redistribute it and/or modify
/ it under the terms of the GNU Affero General Public License as published
/ by the Free Software Foundation, either version 3 of the License, or
/ (at your option) any later version.
/
/ This program is distributed in the hope that it will be useful,
/ but WITHOUT ANY WARRANTY; without even the implied warranty of
/ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
/ GNU Affero General Public License for more details.
/
/ You should have received a copy of the GNU Affero General Public License
/ along with this program. If not, see <https://www.gnu.org/licenses/>.

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
