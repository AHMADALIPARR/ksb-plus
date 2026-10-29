/ SPDX-License-Identifier: AGPL-3.0-or-later
/ Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
/ Dual-licensed under AGPL-3.0-or-later and a proprietary commercial license.
/ Layer 11: matrix engine. Row-major intmat/fltmat objects (Layer 2),
/ data layout (rows;cols;data) with data length rows*cols.
/ Int arithmetic is checked (overflow fails, never wraps); float is
/ plain. Functions return (1;value) or (0;reason) as in earlier
/ layers. Entry points fully validate their matrix arguments with
/ oIsValid (unlike Layer 2 accessors, which check kind and shape
/ only): a hand-built pair with a right kind code but a malformed
/ payload fails "valid" here instead of erroring inside arithmetic.
/ mDot takes raw typed vectors, not objects. mRow/mCol return raw
/ typed vectors. Gate E (matrix correctness) needs this layer.
/ Row/column extraction uses row-major indexing: row i is
/ data[i*cols + !cols], column j is data[j + cols*!rows].
mIsMat:{[x] (oKind[x]~`intmat)|(oKind[x]~`fltmat)}
mCheck:{[a] :[mIsMat[a]; :[oIsValid[a]; (1;a); (0;"valid")]; (0;"type")]}
mRowVec:{[m;i;k] dt:m[1][2]; dt[(i*k)+!k]}
mColVec:{[m;j;r;c] dt:m[1][2]; dt[j+c*!r]}
mTranspose:{[a] c:mCheck[a]; :[c[0]=0; c; mTransposeV[c[1]]]}
mTransposeV:{[a] t:a[1]; mTransposeD[a;t[0];t[1];t[2]]}
mTransposeD:{[a;r;c;dt] ctx:(dt;c;r); rows:mTransRow'[(!c);(#(!c))#(,ctx)]; :[oKind[a]~`intmat; oIntMat[c;r;,/rows]; oFltMat[c;r;,/rows]]}
mTransRow:{[ro;ctx] ctx[0][ro+ctx[1]*!ctx[2]]}
mAdd:{[a;b] ca:mCheck[a]; :[ca[0]=0; ca; mAddB[ca[1];b]]}
mAddB:{[a;b] cb:mCheck[b]; :[cb[0]=0; cb; mAddC[a;cb[1]]]}
mAddC:{[a;b] :[oKind[a]~oKind[b]; mAddD[a;b]; (0;"type")]}
mAddD:{[a;b] sa:oMatShape[a]; sb:oMatShape[b]; :[sa[0]=0; sa; :[sb[0]=0; sb; mAddE[a;b;sa[1];sb[1]]]]}
mAddE:{[a;b;sa;sb] :[sa~sb; mAddF[a;b;sa]; (0;"shape")]}
mAddF:{[a;b;sa] :[oKind[a]~`intmat; mAddI[a;b;sa]; mAddFl[a;b;sa]]}
mAddI:{[a;b;sa] rs:kChkAdd'[a[1][2];b[1][2]]; :[cEOk[rs]; oIntMat[sa[0];sa[1];qVals[rs]]; cEFirstErr[rs]]}
mAddFl:{[a;b;sa] oFltMat[sa[0];sa[1];a[1][2]+b[1][2]]}
mSub:{[a;b] ca:mCheck[a]; :[ca[0]=0; ca; mSubB[ca[1];b]]}
mSubB:{[a;b] cb:mCheck[b]; :[cb[0]=0; cb; mSubC[a;cb[1]]]}
mSubC:{[a;b] :[oKind[a]~oKind[b]; mSubD[a;b]; (0;"type")]}
mSubD:{[a;b] sa:oMatShape[a]; sb:oMatShape[b]; :[sa[0]=0; sa; :[sb[0]=0; sb; mSubE[a;b;sa[1];sb[1]]]]}
mSubE:{[a;b;sa;sb] :[sa~sb; mSubF[a;b;sa]; (0;"shape")]}
mSubF:{[a;b;sa] :[oKind[a]~`intmat; mSubI[a;b;sa]; mSubFl[a;b;sa]]}
mSubI:{[a;b;sa] rs:kChkSub'[a[1][2];b[1][2]]; :[cEOk[rs]; oIntMat[sa[0];sa[1];qVals[rs]]; cEFirstErr[rs]]}
mSubFl:{[a;b;sa] oFltMat[sa[0];sa[1];a[1][2]-b[1][2]]}
mScale:{[a;s] c:mCheck[a]; :[c[0]=0; c; mScaleV[c[1];s]]}
mScaleV:{[a;s] :[oKind[a]~`intmat; mScaleI[a;s]; mScaleF[a;s]]}
mScaleI:{[a;s] :[(1=4:s); mScaleIC[a;s]; (0;"type")]}
mScaleIC:{[a;s] t:a[1]; rs:kChkMul'[t[2];(#t[2])#s]; :[cEOk[rs]; oIntMat[t[0];t[1];qVals[rs]]; cEFirstErr[rs]]}
mScaleF:{[a;s] :[(2=4:s); mScaleFC[a;s]; (0;"type")]}
mScaleFC:{[a;s] t:a[1]; oFltMat[t[0];t[1];t[2]*s]}
mMul:{[a;b] ca:mCheck[a]; :[ca[0]=0; ca; mMulB[ca[1];b]]}
mMulB:{[a;b] cb:mCheck[b]; :[cb[0]=0; cb; mMulC[a;cb[1]]]}
mMulC:{[a;b] :[oKind[a]~oKind[b]; mMulD[a;b]; (0;"type")]}
mMulD:{[a;b] sa:oMatShape[a]; sb:oMatShape[b]; :[sa[0]=0; sa; :[sb[0]=0; sb; mMulE[a;b;sa[1];sb[1]]]]}
mMulE:{[a;b;sa;sb] :[sa[1]=sb[0]; mMulF[a;b;sa;sb]; (0;"shape")]}
mMulF:{[a;b;sa;sb] :[oKind[a]~`intmat; mMulI[a;b;sa;sb]; mMulFl[a;b;sa;sb]]}
mMulI:{[a;b;sa;sb] p:kChkMul[sa[0];sb[1]]; :[p[0]=0; p; mMulIC[a;b;sa;sb;p[1]]]}
mMulIC:{[a;b;sa;sb;n] ctx:(a;b;sa[1];sb[1]); cells:mCellI'[(!n);(#(!n))#(,ctx)]; :[cEOk[cells]; oIntMat[sa[0];sb[1];qVals[cells]]; cEFirstErr[cells]]}
mCellI:{[p;ctx] i:p%ctx[3]; j:p-ctx[3]*i; mDotI[mRowVec[ctx[0];i;ctx[2]];mColVec[ctx[1];j;ctx[2];ctx[3]]]}
mMulFl:{[a;b;sa;sb] p:kChkMul[sa[0];sb[1]]; :[p[0]=0; p; mMulFlC[a;b;sa;sb;p[1]]]}
mMulFlC:{[a;b;sa;sb;n] ctx:(a;b;sa[1];sb[1]); cells:mCellF'[(!n);(#(!n))#(,ctx)]; oFltMat[sa[0];sb[1];cells]}
mCellF:{[p;ctx] i:p%ctx[3]; j:p-ctx[3]*i; +/mRowVec[ctx[0];i;ctx[2]]*mColVec[ctx[1];j;ctx[2];ctx[3]]}
mDot:{[a;b] :[((-1)=4:a)&((-1)=4:b); mDotI[a;b]; :[((-2)=4:a)&((-2)=4:b); mDotF[a;b]; (0;"type")]]}
mDotI:{[a;b] :[(#a)=(#b); mDotIC[a;b]; (0;"shape")]}
mDotIC:{[a;b] rs:kChkMul'[a;b]; :[cEOk[rs]; kSumC[qVals[rs]]; cEFirstErr[rs]]}
mDotF:{[a;b] :[(#a)=(#b); (1;+/a*b); (0;"shape")]}
mVecMul:{[a;v] c:mCheck[a]; :[c[0]=0; c; mVecMulV[c[1];v]]}
mVecMulV:{[a;v] :[oKind[a]~`intmat; mVecMulI[a;v]; mVecMulF[a;v]]}
mVecMulI:{[a;v] :[(-1)=4:v; mVecMulIC[a;v]; (0;"type")]}
mVecMulIC:{[a;v] t:a[1]; :[(#v)=t[1]; mVecMulIR[a;v;t]; (0;"shape")]}
mVecMulIR:{[a;v;t] ctx:(a;v;t[1]); rows:mVecRow'[(!t[0]);(#(!t[0]))#(,ctx)]; :[cEOk[rows]; (1;qVals[rows]); cEFirstErr[rows]]}
mVecRow:{[i;ctx] mDotI[mRowVec[ctx[0];i;ctx[2]];ctx[1]]}
mVecMulF:{[a;v] :[(-2)=4:v; mVecMulFC[a;v]; (0;"type")]}
mVecMulFC:{[a;v] t:a[1]; :[(#v)=t[1]; mVecMulFR[a;v;t]; (0;"shape")]}
mVecMulFR:{[a;v;t] ctx:(a;v;t[1]); rows:mVecRowF'[(!t[0]);(#(!t[0]))#(,ctx)]; :[cEOk[rows]; (1;qVals[rows]); cEFirstErr[rows]]}
mVecRowF:{[i;ctx] mDotF[mRowVec[ctx[0];i;ctx[2]];ctx[1]]}
mIdentI:{[n] :[(1=4:n); mIdentIC[n]; (0;"type")]}
mIdentIC:{[n] :[(n<1)|(n>1000); (0;"range"); mIdentID[n]]}
mIdentID:{[n] oIntMat[n;n;mIdentCellsI[n]]}
mIdentCellsI:{[n] mIdentCellI'[(!n*n);(#(!n*n))#n]}
mIdentCellI:{[p;n] r:p%n; :[r=p-n*r; 1; 0]}
mIdentF:{[n] :[(1=4:n); mIdentFC[n]; (0;"type")]}
mIdentFC:{[n] :[(n<1)|(n>1000); (0;"range"); mIdentFD[n]]}
mIdentFD:{[n] oFltMat[n;n;mIdentCellsF[n]]}
mIdentCellsF:{[n] mIdentCellF'[(!n*n);(#(!n*n))#n]}
mIdentCellF:{[p;n] r:p%n; :[r=p-n*r; 1.0; 0.0]}
mTrace:{[a] c:mCheck[a]; :[c[0]=0; c; mTraceV[c[1]]]}
mTraceV:{[a] t:a[1]; :[t[0]=t[1]; mTraceD[a;t]; (0;"shape")]}
mTraceD:{[a;t] dg:mDiag[a;t]; :[oKind[a]~`intmat; kSumC[dg]; (1;+/dg)]}
mDiag:{[a;t] dt:t[2]; n:t[0]; dt[mDiagIdx'[(!n);(#(!n))#n]]}
mDiagIdx:{[i;n] (i*n)+i}
mRow:{[a;i] c:mCheck[a]; :[c[0]=0; c; mRowV[c[1];i]]}
mRowV:{[a;i] :[(1=4:i); mRowW[a;i]; (0;"type")]}
mRowW:{[a;i] t:a[1]; :[(~(i<0))&(i<t[0]); (1;mRowVec[a;i;t[1]]); (0;"bounds")]}
mCol:{[a;j] c:mCheck[a]; :[c[0]=0; c; mColV[c[1];j]]}
mColV:{[a;j] :[(1=4:j); mColW[a;j]; (0;"type")]}
mColW:{[a;j] t:a[1]; :[(~(j<0))&(j<t[1]); (1;mColVec[a;j;t[0];t[1]]); (0;"bounds")]}
mEq:{[a;b] :[(mIsMat[a])&(mIsMat[b]); mEqV[a;b]; (0;"type")]}
mEqV:{[a;b] :[(oIsValid[a])&(oIsValid[b]); (1;a~b); (0;"valid")]}
