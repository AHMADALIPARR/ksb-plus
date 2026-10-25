/ Layer 7: indexes on top of the Layer 6 columnar engine.
/ A sorted index is (keys;rowids): keys a typed vector, rowids an
/ int list of the same length, keys in grade order. Lookups and
/ ranges return rowids in INDEX (sorted-key) order, not row order.
/ A hash index is (n;buckets): buckets a list of (keys;rowids)
/ pairs, one per bucket, keys placed by kBucket over kHashBytes of
/ the key bytes. All functions return (1;value) / (0;reason) except
/ the predicates xIsSortIdx / xIsHashIdx / xHashStruct, which
/ return raw 0/1, and the binary searches, which return raw ints.
/ Reasons: type, shape, key, bounds, range, plus Layer 6 reasons.
/ NaN keys: a built sorted index sorts NaN first (Kona grade is
/ deterministic), but NaN keys are rejected for lookup, insert,
/ delete, and range ("type") -- SQL-NULL-like semantics, and such
/ rows are unreachable by key. Kona list match treats identical
/ NaN lists as equal, so xIsSortIdx still accepts a NaN-containing
/ sorted index, and xSortSave / xSortLoad work for it; only the
/ NaN rows themselves are unreachable. Hash index persistence is
/ out of scope here.
/ Binary search: xLo / xHi are two SEPARATE directly self-recursive
/ functions. They must not call a shared helper: Kona mutual
/ recursion leaks locals and voids branch calls (see kona-notes).
/ xLo[ks;key;lo;hi]: first i with ks[i] >= key.
/ xHi[ks;key;lo;hi]: first i with ks[i] > key.
xLo:{[ks;key;lo;hi] :[(lo=hi); lo; :[ks[(lo+hi)%2]<key; xLo[ks;key;((lo+hi)%2)+1;hi]; xLo[ks;key;lo;(lo+hi)%2]]]}
xHi:{[ks;key;lo;hi] :[(lo=hi); lo; :[key<ks[(lo+hi)%2]; xHi[ks;key;lo;(lo+hi)%2]; xHi[ks;key;((lo+hi)%2)+1;hi]]]}
/ xKeyOk[kt;key]: kt is the keys type code (-1 int, -2 float, -3
/ char, -4 symbol). Numeric indexes accept int or float keys.
/ xKeyNan[key]: 1 for a float NaN key, else 0.
xKeyOk:{[kt;key] :[((kt=-1)|(kt=-2)); :[(((1=4:key))|((2=4:key))); 1; 0]; :[(kt=-3); :[(3=4:key); 1; 0]; :[(kt=-4); :[(4=4:key); 1; 0]; 0]]]}
xKeyNan:{[key] :[(2=4:key); kFIsNan[key]; 0]}
/ xIsSortIdx: full check including sortedness (keys ~ keys[<keys]).
/ xSortStruct: same without the sortedness check, so lookups are
/ not O(n)-validated; sortedness is the caller's explicit check.
xIsSortIdx:{[ix] :[(2=#ix); xIsSortIdxV[ix]; 0]}
xIsSortIdxV:{[ix] ks:ix[0]; rs:ix[1]; :[((4:ks)<0); :[(-1=4:rs); :[(#ks)=(#rs); :[ks~ks[<ks]; 1; 0]; 0]; 0]; 0]}
xSortStruct:{[ix] :[(2=#ix); xSortStructV[ix]; 0]}
xSortStructV:{[ix] ks:ix[0]; rs:ix[1]; :[((4:ks)<0); :[(-1=4:rs); :[(#ks)=(#rs); 1; 0]; 0]; 0]}
/ xSortBuild[col]: grade order. Rejects non-typed-vector columns.
xSortBuild:{[col] :[((4:col)<0); (1;(col[<col];<col)); (0;"type")]}
/ Lookup: rowids slice for the key's [xLo, xHi) interval.
xSortLookup:{[ix;key] :[xSortStruct[ix]=0; (0;"shape"); xSortLookupV[ix;key]]}
xSortLookupV:{[ix;key] ks:ix[0]; :[((xKeyOk[4:ks;key]=0)|(xKeyNan[key]=1)); (0;"type"); xSortLookupR[ix;key]]}
xSortLookupR:{[ix;key] ks:ix[0]; rs:ix[1]; lo:xLo[ks;key;0;#ks]; hi:xHi[ks;key;0;#ks]; (1;(hi-lo)#(lo _ rs))}
/ Range [lo,hi): two xLo calls. hi<=lo yields empty, guarded so
/ take never gets a negative count. Key types are checked before
/ the guard, so incomparable keys report "type", not empty.
xSortRange:{[ix;lo;hi] :[xSortStruct[ix]=0; (0;"shape"); xSortRangeV[ix;lo;hi]]}
xSortRangeV:{[ix;lo;hi] ks:ix[0]; :[((xKeyOk[4:ks;lo]=0)|(xKeyNan[lo]=1)); (0;"type"); xSortRangeH[ix;lo;hi]]}
xSortRangeH:{[ix;lo;hi] ks:ix[0]; :[((xKeyOk[4:ks;hi]=0)|(xKeyNan[hi]=1)); (0;"type"); xSortRangeR[ix;lo;hi]]}
xSortRangeR:{[ix;lo;hi] :[~(lo<hi); (1;!0); xSortRangeS[ix;lo;hi]]}
xSortRangeS:{[ix;lo;hi] ks:ix[0]; rs:ix[1]; a:xLo[ks;lo;0;#ks]; b:xLo[ks;hi;0;#ks]; (1;(b-a)#(a _ rs))}
/ Splices: atom append preserves the typed-vector type when the
/ atom's type matches the vector's (callers validate first).
xSpliceIn:{[v;pos;x] (pos#v),x,(pos _ v)}
xSpliceOut:{[v;pos] (pos#v),((pos+1) _ v)}
/ Insert: position is xHi, i.e. after existing equals. Row must be
/ an int atom >= 0, else "type" / "range".
xSortInsert:{[ix;key;row] :[xSortStruct[ix]=0; (0;"shape"); xSortInsertV[ix;key;row]]}
xSortInsertV:{[ix;key;row] ks:ix[0]; :[((xKeyOk[4:ks;key]=0)|(xKeyNan[key]=1)); (0;"type"); xSortInsertR[ix;key;row]]}
xSortInsertR:{[ix;key;row] :[(1=4:row); xSortInsertS[ix;key;row]; (0;"type")]}
xSortInsertS:{[ix;key;row] :[(row<0); (0;"range"); xSortInsertT[ix;key;row]]}
xSortInsertT:{[ix;key;row] ks:ix[0]; rs:ix[1]; p:xHi[ks;key;0;#ks]; (1;(xSpliceIn[ks;p;key];xSpliceIn[rs;p;row]))}
/ Delete: one occurrence. Absent key or absent row reports "key".
xSortDelete:{[ix;key;row] :[xSortStruct[ix]=0; (0;"shape"); xSortDeleteV[ix;key;row]]}
xSortDeleteV:{[ix;key;row] ks:ix[0]; :[((xKeyOk[4:ks;key]=0)|(xKeyNan[key]=1)); (0;"type"); xSortDeleteR[ix;key;row]]}
xSortDeleteR:{[ix;key;row] :[(1=4:row); xSortDeleteS[ix;key;row]; (0;"type")]}
xSortDeleteS:{[ix;key;row] ks:ix[0]; rs:ix[1]; lo:xLo[ks;key;0;#ks]; hi:xHi[ks;key;0;#ks]; :[(lo=hi); (0;"key"); xSortDeleteT[ix;key;row;lo;hi]]}
xSortDeleteT:{[ix;key;row;lo;hi] rs:ix[1]; seg:(hi-lo)#(lo _ rs); p:seg?row; :[(p=#seg); (0;"key"); xSortDeleteU[ix;lo+p]]}
xSortDeleteU:{[ix;del] ks:ix[0]; rs:ix[1]; (1;(xSpliceOut[ks;del];xSpliceOut[rs;del]))}
/ Hash key bytes: int via kI64ToBytes, float via its $ decimal,
/ char atom enlisted, symbol via its $ name; all as int lists.
/ xTagOfKey: Layer 6 tag (1/2/3/4) for a key atom, else 0.
xKeyBytes:{[key] :[(1=4:key); (1;kI64ToBytes[key]); :[(2=4:key); (1;_ic $key); :[(3=4:key); (1;_ic (,key)); :[(4=4:key); (1;_ic $key); (0;"type")]]]]}
xTagOfKey:{[key] :[(1=4:key); 1; :[(2=4:key); 2; :[(3=4:key); 3; :[(4=4:key); 4; 0]]]]}
xHashBucket:{[key;n] kb:xKeyBytes[key]; :[kb[0]=0; kb; xHashBucketB[kb[1];n]]}
xHashBucketB:{[kb;n] kBucket[kHashBytes[kb];n]}
/ Hash build: initial buckets are n copies of (typed-empty;!0).
/ The fold carries (ok;buckets;col;n); bucket updates replace the
/ whole bucket element via indexed assignment on a local copy.
xHashBuild:{[col;n] :[((4:col)<0); xHashBuildV[col;n]; (0;"type")]}
xHashBuildV:{[col;n] :[(1=4:n); xHashBuildW[col;n]; (0;"type")]}
xHashBuildW:{[col;n] :[(n<1); (0;"range"); xHashBuildB[col;n]]}
xHashBuildB:{[col;n] ek:qEmptyCol[qTagOf[col]]; bk:(n#(, (ek;!0))); r:xHashStep/((,(1;bk;col;n)),(!#col)); :[r[0]=0; (0;r[1]); (1;(n;r[1]))]}
xHashStep:{[acc;i] :[acc[0]=0; acc; xHashStep2[acc;i]]}
xHashStep2:{[acc;i] key:acc[2][i]; b:xHashBucket[key;acc[3]]; :[b[0]=0; (0;b[1];acc[2];acc[3]); xHashStep3[acc;i;key;b[1]]]}
xHashStep3:{[acc;i;key;b] bk:acc[1][b]; ks:bk[0],key; rs:bk[1],i; bks:acc[1]; bks[b]:(ks;rs); (1;bks;acc[2];acc[3])}
/ xHashStruct: pair, int n >= 1, n buckets, every bucket a pair
/ with typed (or general-and-empty) keys, int rowids, equal
/ lengths. xHashKeyType: first non-empty bucket's keys type, else 0.
xHashStruct:{[ix] :[(2=#ix); xHashStructV[ix]; 0]}
xHashStructV:{[ix] n:ix[0]; bks:ix[1]; :[(1=4:n); :[(n<1); 0; :[(n=#bks); :[&/(xHashBucketOk'bks); 1; 0]; 0]]; 0]}
xHashBucketOk:{[bk] :[(2=#bk); xHashBucketOkV[bk]; 0]}
xHashBucketOkV:{[bk] ks:bk[0]; rs:bk[1]; :[(-1=4:rs); :[(#ks)=(#rs); :[((4:ks)<0); 1; :[((0=4:ks)&(0=#ks)); 1; 0]]; 0]; 0]}
xBucketKeyType:{[bk] :[(0=#bk[0]); 0; 4:bk[0]]}
xHashKeyType:{[ix] ts:xBucketKeyType'ix[1]; nz:&(~(ts=0)); :[(0=#nz); 0; ts[nz[0]]]}
/ Hash lookup: all-empty yields empty before any key check, so an
/ empty index never rejects a key type. Otherwise the key type
/ must match and the bucket is scanned by mask.
xHashLookup:{[ix;key] :[xHashStruct[ix]=0; (0;"shape"); xHashLookupV[ix;key]]}
xHashLookupV:{[ix;key] kt:xHashKeyType[ix]; :[(0=kt); (1;!0); xHashLookupW[ix;key;kt]]}
xHashLookupW:{[ix;key;kt] :[((xKeyOk[kt;key]=0)|(xKeyNan[key]=1)); (0;"type"); xHashLookupR[ix;key]]}
xHashLookupR:{[ix;key] n:ix[0]; b:xHashBucket[key;n]; :[b[0]=0; b; xHashLookupS[ix;key;b[1]]]}
xHashLookupS:{[ix;key;b] bk:ix[1][b]; ks:bk[0]; rs:bk[1]; pos:&(ks=key); (1;rs[pos])}
/ Hash insert: an all-empty index accepts any valid non-NaN key
/ type, else the key type must match. An EMPTY bucket's keys are
/ replaced by the typed empty for the key's type before appending,
/ so a first insert into a virgin or wrongly-typed-empty bucket
/ can never corrupt the bucket's type.
xHashInsert:{[ix;key;row] :[xHashStruct[ix]=0; (0;"shape"); xHashInsertV[ix;key;row]]}
xHashInsertV:{[ix;key;row] :[(1=4:row); xHashInsertW[ix;key;row]; (0;"type")]}
xHashInsertW:{[ix;key;row] :[(row<0); (0;"range"); xHashInsertX[ix;key;row]]}
xHashInsertX:{[ix;key;row] :[(xKeyNan[key]=1); (0;"type"); xHashInsertY[ix;key;row]]}
xHashInsertY:{[ix;key;row] kt:xHashKeyType[ix]; :[(0=kt); :[(xTagOfKey[key]=0); (0;"type"); xHashInsertZ[ix;key;row]]; :[(xKeyOk[kt;key]=0); (0;"type"); xHashInsertZ[ix;key;row]]]}
xHashInsertZ:{[ix;key;row] n:ix[0]; b:xHashBucket[key;n]; :[b[0]=0; b; xHashInsertT[ix;key;row;b[1]]]}
xHashInsertT:{[ix;key;row;b] bk:ix[1][b]; ks:bk[0]; :[(0=#ks); xHashInsertU[ix;key;row;b;qEmptyCol[xTagOfKey[key]]]; xHashInsertU[ix;key;row;b;ks]]}
xHashInsertU:{[ix;key;row;b;ks] bks:ix[1]; bk:bks[b]; ks2:ks,key; rs2:bk[1],row; bks[b]:(ks2;rs2); (1;(ix[0];bks))}
/ Hash delete: one occurrence, first match only. Empty index and
/ absent key/row report "key". The key type is checked before the
/ mask, so a mismatched key reports "type" instead of erroring in
/ the element-wise comparison.
xHashDelete:{[ix;key;row] :[xHashStruct[ix]=0; (0;"shape"); xHashDeleteV[ix;key;row]]}
xHashDeleteV:{[ix;key;row] :[(1=4:row); xHashDeleteW[ix;key;row]; (0;"type")]}
xHashDeleteW:{[ix;key;row] kt:xHashKeyType[ix]; :[(0=kt); (0;"key"); xHashDeleteX[ix;key;row;kt]]}
xHashDeleteX:{[ix;key;row;kt] :[((xKeyOk[kt;key]=0)|(xKeyNan[key]=1)); (0;"type"); xHashDeleteY[ix;key;row]]}
xHashDeleteY:{[ix;key;row] n:ix[0]; b:xHashBucket[key;n]; :[b[0]=0; b; xHashDeleteZ[ix;key;row;b[1]]]}
xHashDeleteZ:{[ix;key;row;b] bk:ix[1][b]; ks:bk[0]; rs:bk[1]; m:(ks=key)&(rs=row); pos:&m; :[(0=#pos); (0;"key"); xHashDeleteU[ix;b;pos[0]]]}
xHashDeleteU:{[ix;b;p] bks:ix[1]; bk:bks[b]; ks2:xSpliceOut[bk[0];p]; rs2:xSpliceOut[bk[1];p]; bks[b]:(ks2;rs2); (1;(ix[0];bks))}
/ xIsHashIdx: struct check plus full placement verification: every
/ key in every bucket re-hashes to its own bucket index. Empty
/ buckets pass vacuously.
xIsHashIdx:{[ix] :[xHashStruct[ix]=0; 0; xIsHashIdxF[ix]]}
xIsHashIdxF:{[ix] r:xIsHashStep/((,(1;ix)),(!ix[0])); r[0]}
xIsHashStep:{[acc;i] :[acc[0]=0; acc; xIsHashStep2[acc;i]]}
xIsHashStep2:{[acc;i] bk:acc[1][1][i]; ks:bk[0]; :[(0=#ks); acc; xIsHashStep3[acc;i;ks]]}
xIsHashStep3:{[acc;i;ks] hs:xHashBucket'[ks;(#ks)#acc[1][0]]; :[(cEOk[hs]=0); (0;acc[1]); :[&/(qVals[hs]=i); acc; (0;acc[1])]]}
/ Sorted index persistence through Layer 6: two columns, `key and
/ `row, written as a manifest. Load gates on xIsSortIdx, so a
/ loaded index is sorted by construction.
xSortSave:{[st;ix] :[xIsSortIdx[ix]=0; (0;"shape"); xSortSaveV[st;ix]]}
xSortSaveV:{[st;ix] t:oTable[(`key`row);(ix[0];ix[1])]; :[t[0]=0; t; xSortSaveW[st;t[1]]]}
xSortSaveW:{[st;tab] sp:qSplitTable[tab]; :[sp[0]=0; sp; qWrite[st;sp[1]]]}
xSortLoad:{[st;mn] r:qRead[st;mn]; :[r[0]=0; r; xSortLoadV[r[1]]]}
xSortLoadV:{[tab] k:oCol[tab;`key]; :[k[0]=0; k; xSortLoadW[tab;k[1]]]}
xSortLoadW:{[tab;kc] w:oCol[tab;`row]; :[w[0]=0; w; xSortLoadX[(kc;w[1])]]}
xSortLoadX:{[ix] :[xIsSortIdx[ix]=0; (0;"shape"); (1;ix)]}
/ xGather: exactly the given rows, in the given order, for the
/ projected columns. Empty rowids trivially pass the bounds check
/ and yield a 0-row table with the projected columns.
xGather:{[st;mn;ix;proj] :[qIsManifest[mn]=0; (0;"shape"); xGatherV[st;mn;ix;proj]]}
xGatherV:{[st;mn;ix;proj] :[(-1=4:ix); xGatherW[st;mn;ix;proj]; (0;"type")]}
xGatherW:{[st;mn;ix;proj] :[oIsSymList[proj]=0; (0;"type"); xGatherB[st;mn;ix;proj]]}
xGatherB:{[st;mn;ix;proj] :[(0=#ix); xGatherC[st;mn;ix;proj]; :[((&/(~(ix<0)))&(&/(ix<mn[2]))); xGatherC[st;mn;ix;proj]; (0;"bounds")]]}
xGatherC:{[st;mn;ix;proj] cs:qReadCols[st;mn;proj]; :[cs[0]=0; cs; xGatherT[proj;ix;cs[1]]]}
xGatherT:{[proj;ix;cols] oTable[proj;qGatherCols[cols;ix]]}
/ xScanIdx: columnar store + sorted index -> rows, end to end.
xScanIdx:{[st;mn;ix;lo;hi;proj] r:xSortRange[ix;lo;hi]; :[r[0]=0; r; xGather[st;mn;r[1];proj]]}
