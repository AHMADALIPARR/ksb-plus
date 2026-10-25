# Layer 11: matrix engine

Row-major intmat/fltmat objects (Layer 2). Data layout is
(rows;cols;data) with data length rows*cols, row i occupying
data[i*cols + !cols] and column j occupying data[j + cols*!rows].

## Functions

- `mTranspose[a]`: rows/cols swap, data re-gathered.
- `mAdd[a;b]`, `mSub[a;b]`: elementwise; both operands must have
  the same kind and the same shape.
- `mScale[a;s]`: scalar multiply; the scalar must be an int atom
  for intmat and a float atom for fltmat.
- `mMul[a;b]`: matrix product; inner dimensions must match
  (a.cols = b.rows). Result is (a.rows;b.cols).
- `mVecMul[a;v]`: matrix times a raw typed vector; the vector
  length must equal a.cols. Returns a raw typed vector.
- `mDot[a;b]`: dot product of two raw typed vectors; lengths
  must match. Returns a tagged scalar (1;v).
- `mIdentI[n]`, `mIdentF[n]`: identity matrix, n in 1..1000.
- `mTrace[a]`: sum of the diagonal; the matrix must be square.
- `mRow[a;i]`, `mCol[a;j]`: raw typed vectors; out-of-range
  indices fail "bounds".
- `mEq[a;b]`: (1;1) if the two matrices are equal, (1;0) if not;
  different kinds compare unequal, not an error.

## Arithmetic discipline

Int arithmetic is checked (Layer 1): add, sub, mul, and the
dot-product sum all fail "overflow" instead of wrapping.
Float arithmetic is plain Kona arithmetic, unrounded and
unchecked for overflow to infinity.

## Validation discipline

Unlike Layer 2 accessors (kind and shape only), Layer 11 entry
points fully validate matrix arguments with oIsValid before
touching arithmetic. A hand-built pair with a right kind code
but a malformed payload (wrong data length, over-limit size)
fails "valid" instead of erroring inside arithmetic. Non-matrix
arguments fail "type". `mDot` takes raw vectors, not objects,
and checks their types and lengths directly.

## Error vocabulary

- "type": non-matrix argument, kind mismatch (add/sub/mul),
  wrong scalar type (scale), wrong vector type (vecmul/dot).
- "shape": shape mismatch (add/sub), inner-dimension mismatch
  (mul), wrong vector length (vecmul/dot), non-square trace.
- "bounds": row/column index out of range.
- "range": identity size outside 1..1000.
- "valid": malformed matrix payload (fails oIsValid).
- "overflow": checked int arithmetic overflow (add/sub/mul/
  scale/dot).

## Honest limits

- No inverse, determinant, LU, eigenvalue, or solver: this layer
  is the arithmetic core (transpose, add, sub, scale, multiply,
  matrix-vector, dot, identity, trace, row/col, equality).
- Multiply is O(rows*cols*inner) with a per-cell dot product;
  no blocking, no SIMD, no sparse representation.
- Float results are exact Kona float arithmetic, not rounded
  to any decimal; tests compare float cells as floats.
- Gate E (matrix correctness) is met by this layer's tests
  alone, per the ledger's definition.
