/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 5 tests. Run via run-tests.sh, which feeds the layer chain
/ src/l00.k through src/l05.k, then this file to Kona. Each chk
/ prints PASS name or FAIL name. The last line prints ALL PASS
/ only when every check passed.
/ Persistence tests write scratch files s5test.K, s5test0.K,
/ s5testL.K, s5testG.K in the current directory (the repo dir
/ under run-tests.sh); they are git-ignored, and saves rewrite
/ them rather than appending, so reruns are clean.
/ Persistence is verified per page (validation, fields, frames,
/ decoded objects), never by a whole-store match: Kona's 1: read
/ of nested structures is unreliable (see src/l05.k header), so
/ no test compares a loaded store to a saved store with ~.
FC:(,0)
chk:{[n;g;w] m:g~w; FC[0]:FC[0]+(~m); (:[m; "PASS "; "FAIL "]),n}
uw:{[t] t[1]}
frI:uw[cEncode[uw[oInt[42]]]]
frS:uw[cEncode[uw[oStr["hello"]]]]
frV:uw[cEncode[uw[oIntVec[1 2 3]]]]
frN:uw[cEncode[(`null;!0)]]
frBad:frI
frBad[(#frBad)-1]:bMod[frBad[(#frBad)-1]+1;256]
bigF:uw[cEncode[uw[oStr[4044#"ab"]]]]
bigOver:uw[cEncode[uw[oStr[5000#"ab"]]]]
chk["new-count"; sCount[sNew]; (1;0)]
chk["new-valid"; sValid[sNew]; 1]
chk["new-recs"; sRecs[sNew]; (1;0)]
chk["new-type"; sCount[5]; (0;"type")]
c1:sCreate[sNew]
chk["create-ok"; c1[0]; 1]
chk["create-id"; c1[1][1]; 0]
st1:c1[1][0]
chk["create-count"; sCount[st1]; (1;1)]
chk["create-page"; sPage[st1;0]; (1;uw[pEmpty[0]])]
chk["create-bounds1"; sPage[st1;1]; (0;"bounds")]
chk["create-boundsneg"; sPage[st1;-1]; (0;"bounds")]
chk["create-type"; sPage[st1;"x"]; (0;"type")]
p1:sPut[st1;frI]
chk["put1-ok"; p1[0]; 1]
chk["put1-id"; p1[1][1]; 0]
chk["put1-slot"; p1[1][2]; 0]
st2:p1[1][0]
p2:sPut[st2;frS]
chk["put2-id"; p2[1][1]; 0]
chk["put2-slot"; p2[1][2]; 1]
st3:p2[1][0]
chk["get00"; sGet[st3;0;0]; (1;frI)]
chk["get01"; sGet[st3;0;1]; (1;frS)]
chk["get02"; sGet[st3;0;2]; (0;"bounds")]
chk["get10"; sGet[st3;1;0]; (0;"bounds")]
chk["put-badframe"; sPut[st3;frBad]; (0;"checksum")]
chk["put-oversize"; sPut[sNew;bigOver]; (0;"limit")]
st4:uw[sAppendTo[st3;0;frV]]
chk["app-get2"; sGet[st4;0;2]; (1;frV)]
chk["app-count"; sCount[st4]; (1;1)]
chk["app-recs"; sRecs[st4]; (1;3)]
chk["app-badpage"; sAppendTo[st4;5;frI]; (0;"bounds")]
chk["app-badframe"; sAppendTo[st4;0;frBad]; (0;"checksum")]
pA:sPut[sNew;bigF]
chk["spillA-id"; pA[1][1]; 0]
chk["spillA-slot"; pA[1][2]; 0]
stA:pA[1][0]
pB:sPut[stA;frN]
chk["spillB-id"; pB[1][1]; 0]
chk["spillB-slot"; pB[1][2]; 1]
stB:pB[1][0]
pC:sPut[stB;frI]
chk["spillC-id"; pC[1][1]; 1]
chk["spillC-slot"; pC[1][2]; 0]
stC:pC[1][0]
chk["spill-count"; sCount[stC]; (1;2)]
chk["spill-get10"; sGet[stC;1;0]; (1;frI)]
chk["spill-get01"; sGet[stC;0;1]; (1;frN)]
chk["spill-recs"; sRecs[stC]; (1;3)]
chk["unchanged-count"; sCount[st3]; (1;1)]
chk["unchanged-recs"; sRecs[st3]; (1;2)]
chk["unchanged-new"; sCount[sNew]; (1;0)]
chk["valid-store"; sValid[stC]; 1]
stX:stC
pgX:stX[0]
pgX[100]:bMod[pgX[100]+1;256]
stX[0]:pgX
chk["valid-corrupt"; sValid[stX]; 0]
chk["put-corrupt"; sPut[stX;frI]; (0;"valid")]
chk["save-corrupt"; sSave[stX;"s5test"]; (0;"valid")]
chk["recs-corrupt"; sRecs[stX]; (0;"checksum")]
chk["save-ok"; sSave[stC;"s5test"]; (1;"s5test")]
ld:sLoad["s5test"]
chk["load-ok"; ld[0]; 1]
stL:ld[1]
chk["load-count"; sCount[stL]; (1;2)]
chk["load-valid"; sValid[stL]; 1]
chk["load-get00"; sGet[stL;0;0]; (1;bigF)]
chk["load-get01"; sGet[stL;0;1]; (1;frN)]
chk["load-get10"; sGet[stL;1;0]; (1;frI)]
chk["load-recs"; sRecs[stL]; (1;3)]
chk["load-page0"; pValid[uw[sPage[stL;0]]]; 1]
chk["load-page1"; pValid[uw[sPage[stL;1]]]; 1]
chk["load-decode"; cDecode[uw[sGet[stL;0;0]]]; (1;uw[oStr[4044#"ab"]])]
chk["save-empty"; sSave[sNew;"s5test0"]; (1;"s5test0")]
chk["load-empty"; sLoad["s5test0"]; (1;!0)]
fl:1: "s5test"
fl[100]:bMod[fl[100]+1;256]
"s5test" 1: fl
chk["load-corrupt"; sLoad["s5test"]; (0;"valid")]
chk["save-overwrite"; sSave[st3;"s5test"]; (1;"s5test")]
chk["load-overwrite"; sCount[uw[sLoad["s5test"]]]; (1;1)]
"s5testL" 1: (100#0)
chk["load-length"; sLoad["s5testL"]; (0;"length")]
"s5testG" 1: (1 2;3 4)
chk["load-type"; sLoad["s5testG"]; (0;"type")]
chk["save-badpath"; sSave[st3;5]; (0;"type")]
chk["load-badpath"; sLoad[5]; (0;"type")]
chk["save-nonstore"; sSave[5;"s5test"]; (0;"type")]
:[0=FC[0]; "ALL PASS"; "FAILURES"]
