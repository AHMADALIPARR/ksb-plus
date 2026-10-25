/ Layer 10: K execution. Executes Layer 2 plan objects against
/ columnar stores (Layer 6) and in-memory tables. A plan pipeline
/ is a general list of plan objects, executed left to right; each
/ step consumes the previous step's table. The first step may be
/ a scan over a (store;manifest) environment; later steps consume
/ tables. Plans are data, not K source text: there is no K parser
/ in this layer, and none is claimed.
/ Environment: a table object, or a (store;manifest) pair.
/ Plan args are Layer 2 objects: column and op names are sym
/ objects, literal values are int/flt/str/sym objects, and a
/ projection is a list object of sym objects.
/ Ops: scan (store env only), filter, project, select, sort,
/ limit, join (table env only). Sort is ascending, or descending
/ with a second int arg of -1 (descending reverses the stable
/ ascending grade, so equal keys come out in reverse row order).
/ Join is an inner equi-join on key columns via a Layer 7 hash
/ index over the right table; duplicate non-key column names fail
/ with "key"; NaN keys fail with "type" (hash lookup semantics).
/ Char-column predicates cannot be expressed: Layer 2 has no
/ char-atom object, and Layer 6 requires a char atom for
/ char-column values, so such plans fail "type" from Layer 6.
/ Functions return (1;value) or (0;reason) as in earlier layers.
/ An empty pipeline is a shape error.
eIsTableEnv:{[e] oKind[e]~`table}
eIsStoreEnv:{[e] :[(0=4:e)&(2=#e); :[sIsStore[e[0]]; qIsManifest[e[1]]; 0]; 0]}
eUnwrapSym:{[o] :[oKind[o]~`sym; (1;o[1]); (0;"type")]}
eUnwrapInt:{[o] :[oKind[o]~`int; (1;o[1]); (0;"type")]}
eUnwrapVal:{[o] :[(oKind[o]~`int)|(oKind[o]~`flt)|(oKind[o]~`str)|(oKind[o]~`sym); (1;o[1]); (0;"type")]}
eSymVal:{[o] :[oKind[o]~`sym; (1;o[1]); (0;"type")]}
eUnwrapSyms:{[o] :[oKind[o]~`list; eUnwrapSymsL[o[1]]; (0;"type")]}
eUnwrapSymsL:{[xs] rs:eSymVal'xs; :[cEOk[rs]; (1;qVals[rs]); cEFirstErr[rs]]}
eArgs:{[pl;n] a:oPlanArgs[pl]; :[a[0]=0; a; eArgsN[a[1];n]]}
eArgsN:{[a;n] :[(#a)=n; (1;a); (0;"shape")]}
eStep:{[env;pl] :[oKind[pl]~`plan; eStepV[env;pl]; (0;"shape")]}
eStepV:{[env;pl] op:oPlanOp[pl]; :[op[0]=0; op; eStepO[env;op[1];pl]]}
eStepO:{[env;op;pl] :[op~`scan; eScan[env;pl]; :[op~`filter; eFilter[env;pl]; :[op~`project; eProject[env;pl]; :[op~`select; eSelect[env;pl]; :[op~`sort; eSort[env;pl]; :[op~`limit; eLimit[env;pl]; :[op~`join; eJoin[env;pl]; (0;"op")]]]]]]]}
eScan:{[env;pl] :[eIsStoreEnv[env]; eScanV[env;pl]; (0;"shape")]}
eScanV:{[env;pl] r:eArgs[pl;4]; :[r[0]=0; r; eScanA[env;r[1]]]}
eScanA:{[env;a] cs:eUnwrapSym[a[0]]; os:eUnwrapSym[a[1]]; vs:eUnwrapVal[a[2]]; ps:eUnwrapSyms[a[3]]; :[cs[0]=0; cs; :[os[0]=0; os; :[vs[0]=0; vs; :[ps[0]=0; ps; qScan[env[0];env[1];cs[1];os[1];vs[1];ps[1]]]]]]}
eFilter:{[env;pl] :[eIsTableEnv[env]; eFilterV[env;pl]; (0;"shape")]}
eFilterV:{[env;pl] r:eArgs[pl;3]; :[r[0]=0; r; eFilterA[env;r[1]]]}
eFilterA:{[env;a] cs:eUnwrapSym[a[0]]; os:eUnwrapSym[a[1]]; vs:eUnwrapVal[a[2]]; :[cs[0]=0; cs; :[os[0]=0; os; :[vs[0]=0; vs; qFilter[env;cs[1];os[1];vs[1]]]]]}
eProject:{[env;pl] :[eIsTableEnv[env]; eProjectV[env;pl]; (0;"shape")]}
eProjectV:{[env;pl] r:eArgs[pl;1]; :[r[0]=0; r; eProjectA[env;r[1]]]}
eProjectA:{[env;a] ps:eUnwrapSyms[a[0]]; :[ps[0]=0; ps; qProject[env;ps[1]]]}
eSelect:{[env;pl] :[eIsTableEnv[env]; eSelectV[env;pl]; (0;"shape")]}
eSelectV:{[env;pl] r:eArgs[pl;4]; :[r[0]=0; r; eSelectA[env;r[1]]]}
eSelectA:{[env;a] cs:eUnwrapSym[a[0]]; os:eUnwrapSym[a[1]]; vs:eUnwrapVal[a[2]]; ps:eUnwrapSyms[a[3]]; :[cs[0]=0; cs; :[os[0]=0; os; :[vs[0]=0; vs; :[ps[0]=0; ps; qSelect[env;cs[1];os[1];vs[1];ps[1]]]]]]}
eSort:{[env;pl] :[eIsTableEnv[env]; eSortV[env;pl]; (0;"shape")]}
eSortV:{[env;pl] a:oPlanArgs[pl]; :[a[0]=0; a; eSortA[env;a[1]]]}
eSortA:{[env;a] :[((#a)=1)|((#a)=2); eSortB[env;a]; (0;"shape")]}
eSortB:{[env;a] cs:eUnwrapSym[a[0]]; :[cs[0]=0; cs; eSortC[env;cs[1];a]]}
eSortC:{[env;nm;a] :[(#a)=1; eSortTab[env;nm;1]; eSortD[env;nm;a[1]]]}
eSortD:{[env;nm;d] ds:eUnwrapInt[d]; :[ds[0]=0; ds; eSortE[env;nm;ds[1]]]}
eSortE:{[env;nm;dir] :[(dir=1)|(dir=-1); eSortTab[env;nm;dir]; (0;"range")]}
eSortTab:{[tab;nm;dir] c:oCol[tab;nm]; :[c[0]=0; c; eSortG[tab;c[1];dir]]}
eSortG:{[tab;col;dir] g:<col; :[dir=1; eSortH[tab;g]; eSortR[tab;g]]}
eSortR:{[tab;g] eSortH[tab;g[((#g)-1)-(!#g)]]}
eSortH:{[tab;g] gs:qGatherCols[tab[1][1];g]; oTable[tab[1][0];gs]}
eLimit:{[env;pl] :[eIsTableEnv[env]; eLimitV[env;pl]; (0;"shape")]}
eLimitV:{[env;pl] r:eArgs[pl;1]; :[r[0]=0; r; eLimitA[env;r[1]]]}
eLimitA:{[env;a] ns:eUnwrapInt[a[0]]; :[ns[0]=0; ns; eLimitTab[env;ns[1]]]}
eLimitTab:{[tab;n] :[(n<0); (0;"range"); eLimitTabV[tab;n]]}
eLimitTabV:{[tab;n] nr:#(tab[1][1][0]); m:eMinN[n;nr]; cs:eTakeN'[tab[1][1];(#(tab[1][1]))#m]; oTable[tab[1][0];cs]}
eMinN:{[n;nr] :[n<nr; n; nr]}
eTakeN:{[col;m] m#col}
eJoin:{[env;pl] :[eIsTableEnv[env]; eJoinV[env;pl]; (0;"shape")]}
eJoinV:{[env;pl] r:eArgs[pl;3]; :[r[0]=0; r; eJoinA[env;r[1]]]}
eJoinA:{[env;a] :[oKind[a[0]]~`table; eJoinB[env;a]; (0;"type")]}
eJoinB:{[env;a] lk:eUnwrapSym[a[1]]; rk:eUnwrapSym[a[2]]; :[lk[0]=0; lk; :[rk[0]=0; rk; eJoinTab[env;a[0];lk[1];rk[1]]]]}
eJoinTab:{[lt;rt;lk;rk] lc:oCol[lt;lk]; :[lc[0]=0; lc; eJoinC[lt;rt;lk;rk;lc[1]]]}
eJoinC:{[lt;rt;lk;rk;lc] rc:oCol[rt;rk]; :[rc[0]=0; rc; eJoinD[lt;rt;lk;rk;lc;rc[1]]]}
eJoinD:{[lt;rt;lk;rk;lc;rc] nb:eJoinNb[rc]; h:xHashBuild[rc;nb]; :[h[0]=0; h; eJoinE[lt;rt;lk;rk;lc;h[1]]]}
eJoinNb:{[rc] :[(0=#rc); 1; #rc]}
eJoinE:{[lt;rt;lk;rk;lc;h] r:eJoinFold[lc;h]; :[r[0]=0; r; eJoinF[lt;rt;lk;rk;r[1];r[2]]]}
eJoinFold:{[lc;h] eJoinStep/((,(1;!0;!0;lc;h)),(!#lc))}
eJoinStep:{[acc;i] :[acc[0]=0; acc; eJoinStep2[acc;i]]}
eJoinStep2:{[acc;i] m:xHashLookup[acc[4];acc[3][i]]; :[m[0]=0; m; eJoinStep3[acc;i;m[1]]]}
eJoinStep3:{[acc;i;rs] (1;acc[1],((#rs)#i);acc[2],rs;acc[3];acc[4])}
eJoinF:{[lt;rt;lk;rk;L;R] rn:rt[1][0]; rn2:eDropKey[rn;rk]; :[rn2[0]=0; rn2; eJoinG[lt;rt;rk;rn2[1];L;R]]}
eDropKey:{[rn;rk] ix:rn?rk; :[ix<#rn; (1;rn[&(~((!#rn)=ix))]); (0;"key")]}
eJoinG:{[lt;rt;rk;rn2;L;R] :[eHasDup[lt[1][0];rn2]; (0;"key"); eJoinH[lt;rt;rk;rn2;L;R]]}
eInList:{[x;xs] (xs?x)<#xs}
eHasDup:{[lns;rns] &/(eInList'[lns;(#lns)#(,rns)])}
eJoinH:{[lt;rt;rk;rn2;L;R] rn:rt[1][0]; ix:rn?rk; kp:&(~((!#rn)=ix)); lg:qGatherCols[lt[1][1];L]; rg:qGatherCols[(rt[1][1])[kp];R]; oTable[(lt[1][0],rn2);(lg,rg)]}
eExec:{[env;pl] :[oKind[pl]~`plan; eStep[env;pl]; ePipe[env;pl]]}
ePipe:{[env;pls] :[eAllPlans[pls]; ePipeF[env;pls]; (0;"shape")]}
eAllPlans:{[pls] :[(0=4:pls); &/(eIsPlan'pls); 0]}
eIsPlan:{[p] oKind[p]~`plan}
ePipeF:{[env;pls] r:ePipeStep/((,(1;env)),pls); :[r[0]=0; r; (1;r[1])]}
ePipeStep:{[acc;p] :[acc[0]=0; acc; eStep[acc[1];p]]}
