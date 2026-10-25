/ Layer 14: banking + time-series workloads on Layers 9 and 12.
/ Prefix y. All public functions return (1;value) or (0;reason).
/ Tables are Layer 2 table objects (oTable results unwrapped with [1]).
/ Money is integer cents. yTransfer computes both new balances before
/ building, so a credit overflow cannot leave a half-applied debit.
/ A yTxBuild transaction is built exactly like Layer 9 builds one
/ (same tuple shape, same `put entry format) except the chunk
/ addresses are tracked via sPut, because tPut does not return them.
/ The commit itself goes through tCommit, so WAL entries, the commit
/ marker, and the version check are all Layer 9 semantics, not a copy.
/ Time-series ticks carry ts>=0, non-negative vol, finite-or-zero px.
/ OHLC buckets use floor division, so bucket boundaries are exact.
yIsIntVec:{[x] (-1)=4:x}
yIsSymVec:{[x] (-4)=4:x}
yIsFltVec:{[x] (-2)=4:x}
yNonNeg:{[xs] :[(0=#xs); 1; ~(|/(xs<0))]}
yUnique:{[xs] (#xs)=#(?xs)}
yFin1:{[v] c:kFClass[v]; (c=3)|(c=4)}
yAllFin:{[px] :[(0=#px); 1; &/(yFin1'px)]}
yAcctNew:{[ids;bals] :[yIsIntVec[ids]; yAcctNewV[ids;bals]; (0;"type")]}
yAcctNewV:{[ids;bals] :[yIsIntVec[bals]; yAcctNewW[ids;bals]; (0;"type")]}
yAcctNewW:{[ids;bals] :[(#ids)=(#bals); yAcctNewX[ids;bals]; (0;"shape")]}
yAcctNewX:{[ids;bals] :[yUnique[ids]; yAcctNewY[ids;bals]; (0;"key")]}
yAcctNewY:{[ids;bals] :[yNonNeg[bals]; oTable[`acct`bal;(ids;bals)]; (0;"range")]}
yFindAcct:{[tab;acct] c:oCol[tab;`acct]; :[c[0]=0; c; yFindAcctV[c[1];acct]]}
yFindAcctV:{[accts;acct] :[(1=4:acct); yFindAcctW[accts;acct]; (0;"type")]}
yFindAcctW:{[accts;acct] ix:accts?acct; :[ix<#accts; (1;ix); (0;"key")]}
yBalIx:{[tab;ix] b:oCol[tab;`bal]; :[b[0]=0; b; (1;b[1][ix])]}
yBal:{[tab;acct] r:yFindAcct[tab;acct]; :[r[0]=0; r; yBalIx[tab;r[1]]]}
ySetBal:{[tab;ix;nb] a:oCol[tab;`acct]; :[a[0]=0; a; ySetBalV[tab;a[1];ix;nb]]}
ySetBalV:{[tab;accts;ix;nb] b:oCol[tab;`bal]; :[b[0]=0; b; ySetBalW[accts;b[1];ix;nb]]}
ySetBalW:{[accts;bals;ix;nb] bl:bals; bl[ix]:nb; oTable[`acct`bal;(accts;bl)]}
yDeposit:{[tab;acct;amt] :[(1=4:amt); yDepositV[tab;acct;amt]; (0;"type")]}
yDepositV:{[tab;acct;amt] :[~(amt<0); yDepositW[tab;acct;amt]; (0;"range")]}
yDepositW:{[tab;acct;amt] r:yFindAcct[tab;acct]; :[r[0]=0; r; yDepositX[tab;r[1];amt]]}
yDepositX:{[tab;ix;amt] b:yBalIx[tab;ix]; :[b[0]=0; b; yDepositY[tab;ix;amt;b[1]]]}
yDepositY:{[tab;ix;amt;bal] nb:kChkAdd[bal;amt]; :[nb[0]=0; nb; ySetBal[tab;ix;nb[1]]]}
yWithdraw:{[tab;acct;amt] :[(1=4:amt); yWithdrawV[tab;acct;amt]; (0;"type")]}
yWithdrawV:{[tab;acct;amt] :[~(amt<0); yWithdrawW[tab;acct;amt]; (0;"range")]}
yWithdrawW:{[tab;acct;amt] r:yFindAcct[tab;acct]; :[r[0]=0; r; yWithdrawX[tab;r[1];amt]]}
yWithdrawX:{[tab;ix;amt] b:yBalIx[tab;ix]; :[b[0]=0; b; yWithdrawY[tab;ix;amt;b[1]]]}
yWithdrawY:{[tab;ix;amt;bal] :[(bal<amt); (0;"funds"); yWithdrawZ[tab;ix;amt;bal]]}
yWithdrawZ:{[tab;ix;amt;bal] nb:kChkSub[bal;amt]; :[nb[0]=0; nb; ySetBal[tab;ix;nb[1]]]}
yTransfer:{[tab;from;to;amt] :[(1=4:amt); yTransferV[tab;from;to;amt]; (0;"type")]}
yTransferV:{[tab;from;to;amt] :[~(amt<0); yTransferW[tab;from;to;amt]; (0;"range")]}
yTransferW:{[tab;from;to;amt] :[~(from~to); yTransferX[tab;from;to;amt]; (0;"shape")]}
yTransferX:{[tab;from;to;amt] rf:yFindAcct[tab;from]; :[rf[0]=0; rf; yTransferY[tab;rf[1];to;amt]]}
yTransferY:{[tab;fi;to;amt] rt:yFindAcct[tab;to]; :[rt[0]=0; rt; yTransferZ[tab;fi;rt[1];amt]]}
yTransferZ:{[tab;fi;ti;amt] bf:yBalIx[tab;fi]; :[bf[0]=0; bf; yTransferA[tab;fi;ti;amt;bf[1]]]}
yTransferA:{[tab;fi;ti;amt;fbal] :[(fbal<amt); (0;"funds"); yTransferB[tab;fi;ti;amt;fbal]]}
yTransferB:{[tab;fi;ti;amt;fbal] bt:yBalIx[tab;ti]; :[bt[0]=0; bt; yTransferC[tab;fi;ti;amt;fbal;bt[1]]]}
yTransferC:{[tab;fi;ti;amt;fbal;tbal] nb:kChkSub[fbal;amt]; :[nb[0]=0; nb; yTransferD[tab;fi;ti;amt;nb[1];tbal]]}
yTransferD:{[tab;fi;ti;amt;fnew;tbal] cb:kChkAdd[tbal;amt]; :[cb[0]=0; cb; yTransferE[tab;fi;ti;fnew;cb[1]]]}
yTransferE:{[tab;fi;ti;fnew;tnew] a:oCol[tab;`acct]; :[a[0]=0; a; yTransferF[a[1];tab;fi;ti;fnew;tnew]]}
yTransferF:{[accts;tab;fi;ti;fnew;tnew] b:oCol[tab;`bal]; :[b[0]=0; b; yTransferG[accts;b[1];fi;ti;fnew;tnew]]}
yTransferG:{[accts;bals;fi;ti;fnew;tnew] nb:bals; nb[fi]:fnew; nb[ti]:tnew; oTable[`acct`bal;(accts;nb)]}
yTotal:{[tab] qAgg[tab;`bal;`sum]}
yConserved:{[a;b] ra:yTotal[a]; :[ra[0]=0; ra; yConservedV[ra[1];b]]}
yConservedV:{[sa;b] rb:yTotal[b]; :[rb[0]=0; rb; (1;sa=rb[1])]}
yJNew:oTable[`jid`from`to`amt;(!0;!0;!0;!0)]
yJAppend:{[j;id;from;to;amt] :[oKind[j]~`table; yJAppendN[j;id;from;to;amt]; (0;"type")]}
yJAppendN:{[j;id;from;to;amt] :[j[1][0]~`jid`from`to`amt; yJAppendV[j;id;from;to;amt]; (0;"shape")]}
yJAppendV:{[j;id;from;to;amt] :[((1=4:id)&(1=4:from))&((1=4:to)&(1=4:amt)); yJAppendW[j;id;from;to;amt]; (0;"type")]}
yJAppendW:{[j;id;from;to;amt] :[~(amt<0); yJAppendX[j;id;from;to;amt]; (0;"range")]}
yJAppendX:{[j;id;from;to;amt] cs:j[1][1]; nc:((cs[0],(,id));(cs[1],(,from));(cs[2],(,to));(cs[3],(,amt))); oTable[`jid`from`to`amt;nc]}
yJReplay:{[j;tab] :[oKind[j]~`table; yJReplayN[j;tab]; (0;"type")]}
yJReplayN:{[j;tab] :[j[1][0]~`jid`from`to`amt; yJReplayC[j;tab]; (0;"shape")]}
yJReplayC:{[j;tab] cs:j[1][1]; yJReplayF[tab;cs]}
yJReplayF:{[tab;cs] r:yJStep/((,(1;tab;cs)),!#cs[0]); :[r[0]=0; (0;r[1]); (1;r[1])]}
yJStep:{[acc;i] :[acc[0]=0; acc; yJStep2[acc;i]]}
yJStep2:{[acc;i] cs:acc[2]; t:yTransfer[acc[1];cs[1][i];cs[2][i];cs[3][i]]; :[t[0]=0; (0;t[1];cs); (1;t[1];cs)]}
yJCheck:{[j;t0;t1] r:yJReplay[j;t0]; :[r[0]=0; r; (1;r[1]~t1)]}
yStoreAccts:{[st;tab] sp:qSplitTable[tab]; :[sp[0]=0; sp; qWrite[st;sp[1]]]}
yTxBuild:{[st;mn;ver;txnid;from;to;amt] tb:qRead[st;mn]; :[tb[0]=0; tb; yTxBuildV[st;mn;ver;txnid;from;to;amt;tb[1]]]}
yTxBuildV:{[st;mn;ver;txnid;from;to;amt;tab] nt:yTransfer[tab;from;to;amt]; :[nt[0]=0; nt; yTxBuildW[st;ver;txnid;nt[1]]]}
yTxBuildW:{[st;ver;txnid;ntab] sp:qSplitTable[ntab]; :[sp[0]=0; sp; yTxBuildX[st;ver;txnid;sp[1]]]}
yTxBuildX:{[st;ver;txnid;sp] bt:tBegin[st;ver;txnid]; :[bt[0]=0; bt; yTxBuildY[bt[1];sp]]}
yTxBuildY:{[txn;sp] fr:,/sp[3]; yTxBuildZ[txn;sp;fr]}
yTxBuildZ:{[txn;sp;fr] r:yPutStep/((,(1;txn[3];!0;!0;txn[0])),fr); :[r[0]=0; (0;r[1]); yTxBuildA[txn;sp;r]]}
yPutStep:{[acc;fr] :[acc[0]=0; acc; yPutStep2[acc;fr]]}
yPutStep2:{[acc;fr] r:sPut[acc[1];fr]; :[r[0]=0; (0;r[1];acc[2];acc[3];acc[4]); (1;r[1][0];acc[2],(,((r[1][1];r[1][2])));acc[3],(,( `put;acc[4];fr));acc[4])]}
yTxBuildA:{[txn;sp;r] nt:(txn[0];0;txn[2];r[1];r[3]); :[tIsTxn[nt]; yTxBuildB[nt;sp;r[2]]; (0;"shape")]}
yCnt:{[x] #x}
yTxBuildB:{[nt;sp;addrs] mn:yRegroup[addrs;yCnt'sp[3]]; (1;(nt;(sp[0];sp[1];sp[2];mn)))}
yRegroup:{[addrs;cnts] r:yRegStep/((,(addrs;!0)),cnts); r[1]}
yRegStep:{[acc;n] (n _ acc[0];acc[1],(,((n#acc[0]))))}
yTxTransfer:{[st;mn;ver;wal;txnid;from;to;amt] b:yTxBuild[st;mn;ver;txnid;from;to;amt]; :[b[0]=0; b; yTxTransferV[st;ver;wal;b[1]]]}
yTxTransferV:{[st;ver;wal;bt] cm:tCommit[bt[0];st;ver;wal]; :[cm[0]=0; cm; yTxTransferW[cm[1];bt[1]]]}
yTxTransferW:{[cm;mn] (1;(cm[1];mn;cm[2];cm[3]))}
yTickNew:{[ts;sym;px;vol] :[yIsIntVec[ts]; yTickNewV[ts;sym;px;vol]; (0;"type")]}
yTickNewV:{[ts;sym;px;vol] :[yIsSymVec[sym]; yTickNewW[ts;sym;px;vol]; (0;"type")]}
yTickNewW:{[ts;sym;px;vol] :[yIsFltVec[px]; yTickNewX[ts;sym;px;vol]; (0;"type")]}
yTickNewX:{[ts;sym;px;vol] :[yIsIntVec[vol]; yTickNewY[ts;sym;px;vol]; (0;"type")]}
yTickNewY:{[ts;sym;px;vol] :[((#ts)=(#sym))&(((#ts)=(#px))&((#ts)=(#vol))); yTickNewZ[ts;sym;px;vol]; (0;"shape")]}
yTickNewZ:{[ts;sym;px;vol] :[yNonNeg[ts]; yTickNewA[ts;sym;px;vol]; (0;"range")]}
yTickNewA:{[ts;sym;px;vol] :[yNonNeg[vol]; yTickNewB[ts;sym;px;vol]; (0;"range")]}
yTickNewB:{[ts;sym;px;vol] :[yAllFin[px]; oTable[`ts`sym`px`vol;(ts;sym;px;vol)]; (0;"valid")]}
yBuckets:{[ts;width] :[(1=4:width); yBucketsV[ts;width]; (0;"type")]}
yBucketsV:{[ts;width] :[width>0; yBucketsW[ts;width]; (0;"range")]}
yBucketsW:{[ts;width] rs:kDivF'[ts;(#ts)#width]; :[cEOk[rs]; (1;width*qVals[rs]); cEFirstErr[rs]]}
yPair:{[a;b] (a;b)}
yC0:{[r] r[0]}
yC1:{[r] r[1]}
yC2:{[r] r[2]}
yC3:{[r] r[3]}
yC4:{[r] r[4]}
yC5:{[r] r[5]}
yC6:{[r] r[6]}
yOHLC:{[tab;width] :[(1=4:width); yOHLCV[tab;width]; (0;"type")]}
yOHLCV:{[tab;width] :[width>0; yOHLCW[tab;width]; (0;"range")]}
yOHLCW:{[tab;width] ts:oCol[tab;`ts]; :[ts[0]=0; ts; yOHLCX[tab;width;ts[1]]]}
yOHLCX:{[tab;width;ts] sy:oCol[tab;`sym]; :[sy[0]=0; sy; yOHLCY[tab;width;ts;sy[1]]]}
yOHLCY:{[tab;width;ts;sy] px:oCol[tab;`px]; :[px[0]=0; px; yOHLCZ[tab;width;ts;sy;px[1]]]}
yOHLCZ:{[tab;width;ts;sy;px] vl:oCol[tab;`vol]; :[vl[0]=0; vl; yOHLCA[tab;width;ts;sy;px;vl[1]]]}
yOHLCA:{[tab;width;ts;sy;px;vl] bk:yBuckets[ts;width]; :[bk[0]=0; bk; yOHLCB[ts;sy;px;vl;bk[1]]]}
yOHLCB:{[ts;sy;px;vl;bk] pr:yPair'[sy;bk]; up:?pr; :[(0=#up); oTable[`sym`bucket`open`high`low`close`vol;((0#`a);!0;(0#1.0 2.0);(0#1.0 2.0);(0#1.0 2.0);(0#1.0 2.0);!0)]; yOHLCC[ts;sy;px;vl;bk;up]]}
yOHLCC:{[ts;sy;px;vl;bk;up] rs:yOHLCRow'[(#up)#(,(ts;sy;px;vl;bk));up]; :[cEOk[rs]; yOHLCD[qVals[rs]]; cEFirstErr[rs]]}
yOHLCRow:{[ctx;pair] ts:ctx[0]; sy:ctx[1]; px:ctx[2]; vl:ctx[3]; bk:ctx[4]; m:(sy=pair[0])&(bk=pair[1]); ix:&m; yOHLCRowV[ts;sy;px;vl;ix;pair]}
yOHLCRowV:{[ts;sy;px;vl;ix;pair] g:<ts[ix]; yOHLCRowW[ts;sy;px;vl;ix;g;pair]}
yOHLCRowW:{[ts;sy;px;vl;ix;g;pair] po:(px[ix])[g]; vo:(vl[ix])[g]; yOHLCRowX[po;vo;pair]}
yOHLCRowX:{[po;vo;pair] s:qSumInt[vo]; :[s[0]=0; s; (1;(pair[0];pair[1];po[0];|/po;&/po;po[(#po)-1];s[1]))]}
yOHLCD:{[rows] sy:yC0'rows; bk:yC1'rows; op:yC2'rows; hi:yC3'rows; lo:yC4'rows; cl:yC5'rows; vo:yC6'rows; oTable[`sym`bucket`open`high`low`close`vol;(sy;bk;op;hi;lo;cl;vo)]}
yVwap:{[tab] px:oCol[tab;`px]; :[px[0]=0; px; yVwapV[tab;px[1]]]}
yVwapV:{[tab;px] vl:oCol[tab;`vol]; :[vl[0]=0; vl; yVwapW[px;vl[1]]]}
yVwapW:{[px;vl] :[(0=#px); (0;"empty"); yVwapX[px;vl]]}
yVwapX:{[px;vl] :[yAllFin[px]; yVwapY[px;vl]; (0;"valid")]}
yVwapY:{[px;vl] sv:qSumInt[vl]; :[sv[0]=0; sv; yVwapZ[px;vl;sv[1]]]}
yVwapZ:{[px;vl;sv] :[sv=0; (0;"range"); yVwapA[px;vl;sv]]}
yVwapA:{[px;vl;sv] sp:+/(px*vl); :[yFin1[sp]; (1;sp%(sv+0.0)); (0;"range")]}
yRollMean:{[col;n] :[yIsFltVec[col]; yRollMeanV[col;n]; (0;"type")]}
yRollMeanV:{[col;n] :[(1=4:n); yRollMeanW[col;n]; (0;"type")]}
yRollMeanW:{[col;n] :[n>0; yRollMeanX[col;n]; (0;"range")]}
yRollMeanX:{[col;n] :[(0=#col); (1;0#1.0 2.0); yRollMeanY[col;n]]}
yRollMeanY:{[col;n] rs:yRollOne'[(#col)#(,(col;n));!#col]; (1;rs)}
yRollStart:{[i;n] :[i<n; 0; (i-n)+1]}
yRollOne:{[ctx;i] col:ctx[0]; n:ctx[1]; st:yRollStart[i;n]; ln:((i+1)-st); w:ln#(st _ col); (+/w)%((#w)+0.0)}
