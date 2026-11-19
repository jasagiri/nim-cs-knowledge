## Integer number theory: greatest common divisor, Bezout coefficients, modular exponentiation
## and modular inverses.
##
## Every routine that can fail says so in its type. `gcd`, `lcm` and `extGcd` return `Option`
## because `abs(low(int))` and some products are not representable; `powMod` and `modInverse`
## take a `Modulus`, a distinct type built by `modulus`, so a zero or negative modulus cannot reach
## them. The largest modulus is chosen so that the product of two residues fits an `int`
## (see `maxModulus`). Use these as the building blocks for RSA-style toy examples, hashing
## and the Chinese remainder theorem; for large moduli use a big-integer library.

import std/options

type
  Modulus* = distinct int
  Bezout* = object
    ## `a * x + b * y == g` with `g` the (non-negative) gcd.
    g*, x*, y*: int

const maxModulus*: int = 3_037_000_499
  ## floor(sqrt(2^63 - 1)): `(m - 1) * (m - 1)` still fits a 64-bit `int`.

func modulus*(m: int): Option[Modulus] {.raises: [].} =
  ## A modulus lies in 1 .. `maxModulus` (NUM-NT-06).
  if m < 1 or m > maxModulus: none(Modulus) else: some(Modulus(m))

func `==`*(a, b: Modulus): bool {.borrow.}
func `$`*(m: Modulus): string {.borrow.}

func toInt*(m: Modulus): int {.raises: [].} = int(m)

func residue*(a: int; m: Modulus): int {.raises: [].} =
  ## `a` reduced into 0 ..< m, also for negative `a`.
  let mi = int(m)
  ((a mod mi) + mi) mod mi

func gcd*(a, b: int): Option[int] {.raises: [].} =
  ## Greatest common divisor, never negative; `gcd(0, 0)` is 0. None when an argument is
  ## `low(int)`, whose magnitude does not fit (NUM-NT-01).
  if a == low(int) or b == low(int):
    return none(int)
  var x = abs(a)
  var y = abs(b)
  while y != 0:
    (x, y) = (y, x mod y)
  some(x)

func lcm*(a, b: int): Option[int] {.raises: [].} =
  ## Least common multiple, never negative; zero if either argument is zero. None on overflow
  ## or `low(int)` (NUM-NT-02).
  let g = gcd(a, b)
  if g.isNone:
    return none(int)
  if a == 0 or b == 0:
    return some(0)
  let q = abs(a) div g.get
  let m = abs(b)
  if q > high(int) div m: none(int) else: some(q * m)

func extGcd*(a, b: int): Option[Bezout] {.raises: [].} =
  ## The gcd with Bezout coefficients: `a * x + b * y == g` (NUM-NT-03). None when an argument is
  ## `low(int)`.
  if a == low(int) or b == low(int):
    return none(Bezout)
  var oldR = abs(a)
  var r = abs(b)
  var oldS = 1
  var s = 0
  var oldT = 0
  var t = 1
  while r != 0:
    let q = oldR div r
    (oldR, r) = (r, oldR - q * r)
    (oldS, s) = (s, oldS - q * s)
    (oldT, t) = (t, oldT - q * t)
  some(Bezout(g: oldR, x: (if a < 0: -oldS else: oldS), y: (if b < 0: -oldT else: oldT)))

func powMod*(base, exp: int; m: Modulus): Option[int] {.raises: [].} =
  ## `base ^ exp mod m` by repeated squaring, in 0 ..< m. None for a negative exponent
  ## (NUM-NT-04). `powMod(x, 0, m)` is 1 mod m, so 0 when `m` is 1.
  if exp < 0:
    return none(int)
  let mi = int(m)
  var acc = 1 mod mi
  var b = residue(base, m)
  var e = exp
  while e > 0:
    if (e and 1) == 1:
      acc = acc * b mod mi
    e = e shr 1
    if e > 0:
      b = b * b mod mi
  some(acc)

func modInverse*(a: int; m: Modulus): Option[int] {.raises: [].} =
  ## The `x` in 0 ..< m with `a * x ≡ 1 (mod m)`, or none when `a` and `m` are not coprime
  ## (NUM-NT-05).
  let r = extGcd(residue(a, m), int(m))
  if r.isNone or r.get.g != 1:
    return none(int)
  some(residue(r.get.x, m))
