/ Layer 15: security + ops on Layers 9 and 12. Prefix n.
/ All public functions return (1;value) or (0;reason).
/ WARNING (read before using): password hashes here are
/ Layer 1 kHashStr, an Adler/mod-prime checksum of the
/ password bytes. That is DEMONSTRATION-GRADE ONLY: no salt,
/ no key-derivation work factor, fast to brute-force. It is
/ NOT a secure password hash and must never be presented as
/ one. This layer's contribution is access-control logic
/ (users, roles, permissions, audit, rate limits, authorized
/ query execution) plus ops (backup, restore, checkpoint,
/ verify, quota). Production use requires a real KDF in
/ place of kHashStr; the auth logic itself does not depend
/ on which hash function fills the hash column.
/ Authorization runs BEFORE execution: nAuthQ/nAuthSQL parse
/ the query, check `read permission on every table it names,
/ and return (0;"denied") without executing when denied.
/ Ops are thin wrappers over Layers 5 and 8; backup writes
/ the store file first, so a failed WAL save leaves the
/ store file in place (reported by the propagated error).
nIsInt:{[x] (1=4:x)}
nIsIntVec:{[x] (-1)=4:x}
nIsSym:{[x] (4=4:x)}
nIsSymVec:{[x] (-4)=4:x}
nIsCharList:{[x] (-3)=4:x}
nIs01:{[v] (v=0)|(v=1)}
nUserNew:{[users;passes] :[nIsSymVec[users]; nUserNewV[users;passes]; (0;"type")]}
nUserNewV:{[users;passes] :[(#users)=(#passes); nUserNewW[users;passes]; (0;"shape")]}
nUserNewW:{[users;passes] :[(0=#users); oTable[`user`hash;((0#`a);!0)]; nUserNewF[users;passes]]}
nUserNewF:{[users;passes] :[(0=4:passes); nUserNewG[users;passes]; (0;"type")]}
nUserNewG:{[users;passes] :[&/(nIsCharList'passes); nUserNewH[users;passes]; (0;"type")]}
nUserNewH:{[users;passes] :[(#users)=#(?users); nUserNewI[users;passes]; (0;"key")]}
nUserNewI:{[users;passes] oTable[`user`hash;(users;kHashStr'passes)]}
nAuth:{[usertab;user;pass] :[(oKind[usertab]~`table); nAuthV[usertab;user;pass]; (0;"type")]}
nAuthV:{[usertab;user;pass] :[(nIsSym[user]&nIsCharList[pass]); nAuthW[usertab;user;pass]; (0;"type")]}
nAuthW:{[usertab;user;pass] c:oCol[usertab;`user]; :[c[0]=0; c; nAuthX[usertab;user;pass;c[1]]]}
nAuthX:{[usertab;user;pass;users] ix:users?user; :[ix<#users; nAuthY[usertab;ix;pass]; (1;0)]}
nAuthY:{[usertab;ix;pass] h:oCol[usertab;`hash]; :[h[0]=0; h; (1;(kHashStr[pass]=h[1][ix]))]}
nRoleNew:{[users;roles] :[(nIsSymVec[users]&nIsSymVec[roles]); nRoleNewV[users;roles]; (0;"type")]}
nRoleNewV:{[users;roles] :[(#users)=(#roles); oTable[`user`role;(users;roles)]; (0;"shape")]}
nPermNew:oTable[`role`obj`op;((0#`a);(0#`a);(0#`a))]
nGrant:{[pt;role;obj;op] :[(oKind[pt]~`table); nGrantV[pt;role;obj;op]; (0;"type")]}
nGrantV:{[pt;role;obj;op] :[(pt[1][0]~`role`obj`op); nGrantW[pt;role;obj;op]; (0;"shape")]}
nGrantW:{[pt;role;obj;op] :[((nIsSym[role]&nIsSym[obj])&(nIsSym[op])); nGrantX[pt;role;obj;op]; (0;"type")]}
nGrantX:{[pt;role;obj;op] cs:pt[1][1]; nc:((cs[0],(,role));(cs[1],(,obj));(cs[2],(,op))); oTable[`role`obj`op;nc]}
nRevoke:{[pt;role;obj;op] :[(oKind[pt]~`table); nRevokeV[pt;role;obj;op]; (0;"type")]}
nRevokeV:{[pt;role;obj;op] :[(pt[1][0]~`role`obj`op); nRevokeW[pt;role;obj;op]; (0;"shape")]}
nRevokeW:{[pt;role;obj;op] :[((nIsSym[role]&nIsSym[obj])&(nIsSym[op])); nRevokeX[pt;role;obj;op]; (0;"type")]}
nRevokeX:{[pt;role;obj;op] cs:pt[1][1]; nRevokeY[pt;cs;role;obj;op]}
nRevokeY:{[pt;cs;role;obj;op] :[(0=#cs[0]); (1;pt); nRevokeZ[cs;role;obj;op]]}
nRevokeZ:{[cs;role;obj;op] m:((cs[0]=role)&(cs[1]=obj))&(cs[2]=op); k:&~m; oTable[`role`obj`op;(cs[0][k];cs[1][k];cs[2][k])]}
nCan:{[pt;ur;user;obj;op] :[(oKind[pt]~`table); nCanA[pt;ur;user;obj;op]; (0;"type")]}
nCanA:{[pt;ur;user;obj;op] :[(oKind[ur]~`table); nCanB[pt;ur;user;obj;op]; (0;"type")]}
nCanB:{[pt;ur;user;obj;op] :[((nIsSym[user]&nIsSym[obj])&(nIsSym[op])); nCanC[pt;ur;user;obj;op]; (0;"type")]}
nCanC:{[pt;ur;user;obj;op] :[(pt[1][0]~`role`obj`op); nCanD[pt;ur;user;obj;op]; (0;"shape")]}
nCanD:{[pt;ur;user;obj;op] :[(ur[1][0]~`user`role); nCanE[pt;ur;user;obj;op]; (0;"shape")]}
nCanE:{[pt;ur;user;obj;op] f:qFilter[ur;`user;`eq;user]; :[f[0]=0; f; nCanF[pt;f[1];obj;op]]}
nCanF:{[pt;urt;obj;op] c:oCol[urt;`role]; :[c[0]=0; c; nCanG[pt;c[1];obj;op]]}
nCanG:{[pt;roles;obj;op] :[(0=#roles); (1;0); nCanH[pt;roles;obj;op]]}
nCanH:{[pt;roles;obj;op] f:qFilter[pt;`obj;`eq;obj]; :[f[0]=0; f; nCanI[f[1];roles;op]]}
nCanI:{[pt2;roles;op] f:qFilter[pt2;`op;`eq;op]; :[f[0]=0; f; nCanJ[f[1];roles]]}
nCanJ:{[pt3;roles] c:oCol[pt3;`role]; :[c[0]=0; c; nCanK[c[1];roles]]}
nCanK:{[rcol;roles] :[(0=#rcol); (1;0); nCanL[rcol;roles]]}
nIn:{[roles;x] (roles?x)<(#roles)}
nCanL:{[rcol;roles] m:nIn'[(#rcol)#(,roles);rcol]; (1;|/m)}
nAuditNew:oTable[`seq`user`op`obj`allowed;(!0;(0#`a);(0#`a);(0#`a);!0)]
nAuditAppend:{[aud;user;op;obj;allowed] :[(oKind[aud]~`table); nAuditAppendV[aud;user;op;obj;allowed]; (0;"type")]}
nAuditAppendV:{[aud;user;op;obj;allowed] :[(aud[1][0]~`seq`user`op`obj`allowed); nAuditAppendW[aud;user;op;obj;allowed]; (0;"shape")]}
nAuditAppendW:{[aud;user;op;obj;allowed] :[((nIsSym[user]&nIsSym[op])&(nIsSym[obj])); nAuditAppendX[aud;user;op;obj;allowed]; (0;"type")]}
nAuditAppendX:{[aud;user;op;obj;allowed] :[(nIsInt[allowed]); nAuditAppendY[aud;user;op;obj;allowed]; (0;"type")]}
nAuditAppendY:{[aud;user;op;obj;allowed] :[((allowed=0)|(allowed=1)); nAuditAppendZ[aud;user;op;obj;allowed]; (0;"range")]}
nAuditAppendZ:{[aud;user;op;obj;allowed] cs:aud[1][1]; sq:#cs[0]; nc:((cs[0],(,sq));(cs[1],(,user));(cs[2],(,op));(cs[3],(,obj));(cs[4],(,allowed))); oTable[`seq`user`op`obj`allowed;nc]}
nAuditVerify:{[aud] :[(oKind[aud]~`table); nAuditVerifyV[aud]; (0;"type")]}
nAuditVerifyV:{[aud] :[(aud[1][0]~`seq`user`op`obj`allowed); nAuditVerifyW[aud]; (1;0)]}
nAuditVerifyW:{[aud] cs:aud[1][1]; nAuditVerifyX[cs[0];cs[4]]}
nAuditVerifyX:{[seq;allowed] :[(nIsIntVec[seq]&nIsIntVec[allowed]); nAuditVerifyY[seq;allowed]; (1;0)]}
nAuditVerifyY:{[seq;allowed] :[((#seq)=(#allowed)); nAuditVerifyZ[seq;allowed]; (1;0)]}
nAuditVerifyZ:{[seq;allowed] :[(seq~(!#seq)); nAuditVerifyA[allowed]; (1;0)]}
nAuditVerifyA:{[allowed] :[(0=#allowed); (1;1); (1;&/(nIs01'allowed))]}
nRateNew:oTable[`user`tokens`last;((0#`a);!0;!0)]
nRateAllow:{[bk;user;ts;rate;cap] :[(oKind[bk]~`table); nRateAllowV[bk;user;ts;rate;cap]; (0;"type")]}
nRateAllowV:{[bk;user;ts;rate;cap] :[(bk[1][0]~`user`tokens`last); nRateAllowW[bk;user;ts;rate;cap]; (0;"shape")]}
nRateAllowW:{[bk;user;ts;rate;cap] :[(nIsSym[user]); nRateAllowX[bk;user;ts;rate;cap]; (0;"type")]}
nRateAllowX:{[bk;user;ts;rate;cap] :[((nIsInt[ts]&nIsInt[rate])&(nIsInt[cap])); nRateAllowY[bk;user;ts;rate;cap]; (0;"type")]}
nRateAllowY:{[bk;user;ts;rate;cap] :[((~(ts<0))&(~(rate<0)))&(~(cap<1)); nRateAllowZ[bk;user;ts;rate;cap]; (0;"range")]}
nRateAllowZ:{[bk;user;ts;rate;cap] us:oCol[bk;`user]; :[us[0]=0; us; nRateAllowA[bk;user;ts;rate;cap;us[1]]]}
nRateAllowA:{[bk;user;ts;rate;cap;users] ix:users?user; :[ix<#users; nRateAllowB[bk;ix;ts;rate;cap]; nRateAllowN[bk;user;ts;cap]]}
nRateAllowN:{[bk;user;ts;cap] cs:bk[1][1]; nc:((cs[0],(,user));(cs[1],(,cap-1));(cs[2],(,ts))); nb:oTable[`user`tokens`last;nc]; :[nb[0]=0; nb; (1;(1;nb[1]))]}
nRateAllowB:{[bk;ix;ts;rate;cap] tk:oCol[bk;`tokens]; :[tk[0]=0; tk; nRateAllowC[bk;ix;ts;rate;cap;tk[1]]]}
nRateAllowC:{[bk;ix;ts;rate;cap;toks] ls:oCol[bk;`last]; :[ls[0]=0; ls; nRateAllowD[bk;ix;ts;rate;cap;toks[ix];ls[1][ix]]]}
nRateAllowD:{[bk;ix;ts;rate;cap;tok;lst] :[~(ts<lst); nRateAllowE[bk;ix;ts;rate;cap;tok;lst]; (0;"range")]}
nRateAllowE:{[bk;ix;ts;rate;cap;tok;lst] m:kChkMul[(ts-lst);rate]; :[m[0]=0; m; nRateAllowF[bk;ix;ts;cap;tok;m[1]]]}
nRateAllowF:{[bk;ix;ts;cap;tok;add] r:kChkAdd[tok;add]; :[r[0]=0; r; nRateAllowG[bk;ix;ts;cap;r[1]]]}
nRateAllowG:{[bk;ix;ts;cap;ref0] ref:cap&ref0; :[ref>0; nRateAllowH[bk;ix;ts;ref-1;1]; nRateAllowH[bk;ix;ts;ref;0]]}
nRateAllowH:{[bk;ix;ts;newtok;allowed] cs:bk[1][1]; tk:cs[1]; tk[ix]:newtok; ls:cs[2]; ls[ix]:ts; nb:oTable[`user`tokens`last;(cs[0];tk;ls)]; :[nb[0]=0; nb; (1;(allowed;nb[1]))]}
nAuthQ:{[env;pt;ur;user;query] r:uTok[query]; :[r[0]=0; r; nAuthQV[env;pt;ur;user;query;r[1]]]}
nAuthQV:{[env;pt;ur;user;query;toks] p:uParseQ[toks]; :[p[0]=0; p; nAuthQW[env;pt;ur;user;query;p[1]]]}
nAuthQW:{[env;pt;ur;user;query;parsed] c:nCan[pt;ur;user;parsed[1];`read]; :[c[0]=0; c; nAuthQX[env;query;c[1]]]}
nAuthQX:{[env;query;can] :[can=1; uQ[env;query]; (0;"denied")]}
nAuthSQL:{[env;pt;ur;user;query] r:uTok[query]; :[r[0]=0; r; nAuthSQLV[env;pt;ur;user;query;r[1]]]}
nAuthSQLV:{[env;pt;ur;user;query;toks] p:zParseSQL[toks]; :[p[0]=0; p; nAuthSQLW[env;pt;ur;user;query;p[1]]]}
nAuthSQLW:{[env;pt;ur;user;query;st] c:nCan[pt;ur;user;st[1];`read]; :[c[0]=0; c; nAuthSQLX[env;pt;ur;user;query;st;c[1]]]}
nAuthSQLX:{[env;pt;ur;user;query;st;can] :[can=0; (0;"denied"); nAuthSQLY[env;pt;ur;user;query;st]]}
nAuthSQLY:{[env;pt;ur;user;query;st] :[((4:st[4])=4); nAuthSQLZ[env;pt;ur;user;query;st]; zSQL[env;query]]}
nAuthSQLZ:{[env;pt;ur;user;query;st] c:nCan[pt;ur;user;st[4];`read]; :[c[0]=0; c; nAuthSQLA[env;query;c[1]]]}
nAuthSQLA:{[env;query;can] :[can=1; zSQL[env;query]; (0;"denied")]}
nBackup:{[st;wal;spath;wpath] s:sSave[st;spath]; :[s[0]=0; s; nBackupV[wal;spath;wpath]]}
nBackupV:{[wal;spath;wpath] w:wSave[wal;wpath]; :[w[0]=0; w; (1;(spath;wpath))]}
nRestore:{[spath;wpath] s:sLoad[spath]; :[s[0]=0; s; nRestoreV[wpath;s[1]]]}
nRestoreV:{[wpath;store] w:wLoad[wpath]; :[w[0]=0; w; (1;(store;w[1][0];w[1][1]))]}
nCheckpoint:{[st;wal] wCheckpoint[st;wal]}
nVerifyStore:{[st] :[sIsStore[st]; nVerifyStoreV[st]; (0;"type")]}
nVerifyStoreV:{[st] r:sRecs[st]; :[r[0]=0; r; (1;(#st;r[1];sValid[st]))]}
nQuota:{[tab;maxrows] :[(oKind[tab]~`table); nQuotaV[tab;maxrows]; (0;"type")]}
nQuotaV:{[tab;maxrows] :[(nIsInt[maxrows]); nQuotaW[tab;maxrows]; (0;"type")]}
nQuotaW:{[tab;maxrows] :[~(maxrows<0); nQuotaX[tab;maxrows]; (0;"range")]}
nQuotaX:{[tab;maxrows] nr:#(tab[1][1][0]); :[~(maxrows<nr); (1;1); (0;"limit")]}
