/ Layer 4 tests. Run via run-tests.sh, which feeds the layer chain
/ src/l00.k, src/l01.k, src/l02.k, src/l03.k, src/l04.k, then this
/ file to Kona. Each chk prints PASS name or FAIL name. The last
/ line prints ALL PASS only when every check passed.
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
uw:{[t] t[1]}
fixck:{[pg] u:bDecU32[4#(12 _ pg)]; rec:(u-20)#(20 _ pg); (16#pg),bEncU32[bCksum[(16#pg),rec]],(20 _ pg)}
frI:uw[cEncode[uw[oInt[42]]]]
frS:uw[cEncode[uw[oStr["hello"]]]]
frV:uw[cEncode[uw[oIntVec[1 2 3]]]]
frN:uw[cEncode[(`null;!0)]]
pgE:uw[pEmpty[0]]
chk["empty-valid"; pValid[pgE]; 1]
chk["empty-id"; pId[pgE]; (1;0)]
chk["empty-cnt"; pCnt[pgE]; (1;0)]
chk["empty-used"; pUsed[pgE]; (1;20)]
chk["empty-free"; pFree[pgE]; (1;4076)]
chk["empty-read"; pRead[pgE]; (1;!0)]
pg1:uw[pBuild[7;(,frI)]]
chk["one-valid"; pValid[pg1]; 1]
chk["one-id"; pId[pg1]; (1;7)]
chk["one-cnt"; pCnt[pg1]; (1;1)]
chk["one-used"; pUsed[pg1]; (1;20+#frI)]
chk["one-free"; pFree[pg1]; (1;4096-(20+#frI))]
chk["one-read"; pRead[pg1]; (1;(,frI))]
chk["one-get0"; pGet[pg1;0]; (1;frI)]
chk["one-get1"; pGet[pg1;1]; (0;"bounds")]
chk["one-getneg"; pGet[pg1;-1]; (0;"bounds")]
chk["one-gettype"; pGet[pg1;"x"]; (0;"type")]
pg3:uw[pBuild[9;(frI;frS;frV)]]
chk["three-valid"; pValid[pg3]; 1]
chk["three-cnt"; pCnt[pg3]; (1;3)]
chk["three-read"; pRead[pg3]; (1;(frI;frS;frV))]
chk["three-get1"; pGet[pg3;1]; (1;frS)]
chk["three-get2"; pGet[pg3;2]; (1;frV)]
chk["three-rt0"; cDecode[frI]; (1;uw[oInt[42]])]
chk["three-rt1"; cDecode[frS]; (1;uw[oStr["hello"]])]
chk["three-rt2"; cDecode[frV]; (1;uw[oIntVec[1 2 3]])]
pgA:uw[pAppend[pgE;frI]]
pgB:uw[pAppend[pgA;frS]]
chk["app-cnt"; pCnt[pgB]; (1;2)]
chk["app-read"; pRead[pgB]; (1;(frI;frS))]
chk["app-orig0"; pCnt[pgE]; (1;0)]
chk["app-orig1"; pCnt[pgA]; (1;1)]
frBad:frI
frBad[(#frBad)-1]:bMod[frBad[(#frBad)-1]+1;256]
chk["app-badframe"; pAppend[pgE;frBad]; (0;"checksum")]
chk["build-negid"; pBuild[-1;(,frI)]; (0;"range")]
chk["build-bigid"; pBuild[4294967296;(,frI)]; (0;"range")]
chk["build-typeid"; pBuild[`a;(,frI)]; (0;"type")]
chk["build-maxid"; pId[uw[pBuild[4294967295;(,frI)]]]; (1;4294967295)]
chk["build-frametype"; pBuild[0;frI]; (0;"type")]
chk["build-badframe"; pBuild[0;(,frBad)]; (0;"checksum")]
chk["build-shortframe"; pBuild[0;(,5#frI)]; (0;"short")]
big1:uw[cEncode[uw[oStr[3000#"ab"]]]]
big2:uw[cEncode[uw[oStr[3000#"cd"]]]]
chk["build-limit"; pBuild[0;(big1;big2)]; (0;"limit")]
bigF:uw[cEncode[uw[oStr[4044#"ab"]]]]
pgF:uw[pBuild[0;(,bigF)]]
chk["fit-used"; pUsed[pgF]; (1;4082)]
chk["fit-free"; pFree[pgF]; (1;14)]
pgFull:uw[pAppend[pgF;frN]]
chk["fit-full-used"; pUsed[pgFull]; (1;4096)]
chk["fit-full-free"; pFree[pgFull]; (1;0)]
chk["fit-full-cnt"; pCnt[pgFull]; (1;2)]
chk["fit-over"; pAppend[pgFull;frI]; (0;"limit")]
chk["fit-over-build"; pBuild[0;(bigF;frN;frI)]; (0;"limit")]
pgM:pg1
pgM[0]:44
chk["corrupt-magic"; pParse[pgM]; (0;"magic")]
chk["corrupt-magic-valid"; pValid[pgM]; 0]
chk["corrupt-magic-get"; pGet[pgM;0]; (0;"magic")]
chk["corrupt-magic-read"; pRead[pgM]; (0;"magic")]
chk["corrupt-magic-app"; pAppend[pgM;frI]; (0;"magic")]
chk["corrupt-magic-id"; pId[pgM]; (0;"magic")]
pgV:pg1
pgV[3]:2
chk["corrupt-version"; pParse[pgV]; (0;"version")]
pgC:pg1
pgC[18]:bMod[pgC[18]+1;256]
chk["corrupt-cksum"; pParse[pgC]; (0;"checksum")]
pgT:pg1
pgT[100]:1
chk["corrupt-trailing"; pParse[pgT]; (0;"trailing")]
pgB2:pg1
pgB2[100]:300
chk["corrupt-byterange"; pParse[pgB2]; (0;"type")]
chk["corrupt-short"; pParse[-1 _ pg1]; (0;"length")]
chk["corrupt-long"; pParse[pg1,0]; (0;"length")]
chk["corrupt-atom"; pParse[5]; (0;"type")]
pgN:pg1
pgN[11]:bMod[pgN[11]+1;256]
chk["corrupt-count"; pParse[fixck[pgN]]; (0;"count")]
pgU:pg1
pgU[15]:bMod[pgU[15]+1;256]
chk["corrupt-usedplus"; pParse[fixck[pgU]]; (0;"trunc")]
pgD:pg1
pgD[15]:bMod[pgD[15]-1;256]
chk["corrupt-usedminus"; pParse[fixck[pgD]]; (0;"trailing")]
pgR:pg1
pgR[30]:bMod[pgR[30]+1;256]
chk["corrupt-frameck"; pParse[fixck[pgR]]; (0;"checksum")]
:[0=FC[0]; "ALL PASS"; "FAILURES"]
