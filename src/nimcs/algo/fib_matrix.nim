## Fast Fibonacci by raising the matrix [[1, 1], [1, 0]] to the n-th power: its entries are
## F(n+1), F(n), F(n), F(n-1), and repeated squaring needs O(log n) multiplications.
##
## `fibMatrix` is exact and returns none beyond F(92), the last value that fits a signed 64-bit
## `int`; `fibMod` works modulo a validated modulus and accepts any n up to `high(int)`. Use the
## matrix form when n is huge and only a residue is needed, or as the first example of "a linear
## recurrence is a matrix power"; for small n a loop (`memoization.fibTable`) is simpler.

import std/options

type Mat = object
  a, b, c, d: uint64   # [[a, b], [c, d]]

const
  maxFibExact*: int = 92
    ## F(93) overflows a signed 64-bit integer.
  maxFibModulus*: int = 3_037_000_499
    ## Largest modulus whose residue products fit an `int`.

func mul(x, y: Mat): Mat {.raises: [].} =
  Mat(a: x.a * y.a + x.b * y.c, b: x.a * y.b + x.b * y.d,
      c: x.c * y.a + x.d * y.c, d: x.c * y.b + x.d * y.d)

func fibMatrix*(n: int): Option[int] {.raises: [].} =
  ## F(n) for 0 <= n <= `maxFibExact`, else none (NUM-FIBM-01, NUM-FIBM-03).
  ##
  ## Unsigned arithmetic wraps silently, so overflow is ruled out by bound: no power of the matrix
  ## beyond M^n is formed (the base is squared only while bits remain), and every entry of M^n is at
  ## most F(n+1) <= F(93) < 2^64.
  if n < 0 or n > maxFibExact:
    return none(int)
  var acc = Mat(a: 1, b: 0, c: 0, d: 1)
  var base = Mat(a: 1, b: 1, c: 1, d: 0)
  var e = n
  while e > 0:
    if (e and 1) == 1:
      acc = mul(acc, base)
    e = e shr 1
    if e > 0:
      base = mul(base, base)
  some(int(acc.b))

func fibMod*(n, m: int): Option[int] {.raises: [].} =
  ## F(n) mod m for n >= 0 and 1 <= m <= `maxFibModulus`, else none (NUM-FIBM-02, NUM-FIBM-04).
  if n < 0 or m < 1 or m > maxFibModulus:
    return none(int)
  func mulM(x, y: (int, int, int, int); m: int): (int, int, int, int) {.raises: [].} =
    ((x[0] * y[0] mod m + x[1] * y[2] mod m) mod m, (x[0] * y[1] mod m + x[1] * y[3] mod m) mod m,
     (x[2] * y[0] mod m + x[3] * y[2] mod m) mod m, (x[2] * y[1] mod m + x[3] * y[3] mod m) mod m)
  var acc = (1 mod m, 0, 0, 1 mod m)
  var base = (1 mod m, 1 mod m, 1 mod m, 0)
  var e = n
  while e > 0:
    if (e and 1) == 1:
      acc = mulM(acc, base, m)
    e = e shr 1
    if e > 0:
      base = mulM(base, base, m)
  some(acc[1])
