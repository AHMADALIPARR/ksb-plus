/ SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-SnapKitty-Opaque-1.0
/ Copyright Ahmad Ali Parr
/ Small printing helpers for the examples (not part of the engine).

xStr:{[x] $x}
xLen:{[s] #s}
xPad:{[w;s] (-w)$s}
xRow:{[r] ,/r}
xCol:{[nm;c] ss:(,$nm),xStr'c; w:2+|/xLen'ss; xPad[w]'ss}
xLines:{[t] cs:xCol'[t[1][0];t[1][1]]; xRow'(+cs)}
show:{[t] `0:xLines[t]; `0:,""}
say:{[s] `0:,s}
xSp:{[s] " ",s}
xJoin:{[ss] ,/xSp'ss}
says:{[ss] `0:ss}
