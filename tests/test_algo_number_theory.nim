import std/[unittest, options]
import propcheck
import nimcs/algo/number_theory

func mdl(m: int): Modulus {.raises: [].} = modulus(m).get

func naivePow(base, exp, m: int): int {.raises: [].} =
  result = 1 mod m
  for _ in 1 .. exp:
    result = result * (((base mod m) + m) mod m) mod m

func isPrime(n: int): bool {.raises: [].} =
  if n < 2: return false
  for d in 2 ..< n:
    if d * d > n: break
    if n mod d == 0: return false
  true

# SPEC: NUM-NT-01
test "NUM-NT-01 Given integers, when taking the gcd, then it is non-negative, symmetric and divides both":
  check gcd(12, 18).get == 6
  check gcd(-12, 18).get == 6
  check gcd(0, 0).get == 0
  check gcd(0, 7).get == 7
  check gcd(low(int), 4).isNone
  check gcd(4, low(int)).isNone
  let outcome = check(pair(intIn(-500, 500), intIn(-500, 500)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let g = gcd(p[0], p[1]).get
    g >= 0 and g == gcd(p[1], p[0]).get and
      (g == 0 or (p[0] mod g == 0 and p[1] mod g == 0)) and
      (g == 0 or gcd(p[0] div g, p[1] div g).get == 1))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: NUM-NT-02
test "NUM-NT-02 Given integers, when taking the lcm, then gcd times lcm is the absolute product; overflow gives none":
  check lcm(4, 6).get == 12
  check lcm(0, 6).get == 0
  check lcm(-4, 6).get == 12
  check lcm(high(int), high(int) - 1).isNone
  check lcm(low(int), 2).isNone
  let outcome = check(pair(intIn(-500, 500), intIn(-500, 500)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    gcd(p[0], p[1]).get * lcm(p[0], p[1]).get == abs(p[0] * p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: NUM-NT-03
test "NUM-NT-03 Given integers, when running the extended gcd, then a*x + b*y equals the gcd (Bezout)":
  check extGcd(240, 46).get.g == 2
  check extGcd(low(int), 3).isNone
  let outcome = check(pair(intIn(-1000, 1000), intIn(-1000, 1000)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let r = extGcd(p[0], p[1]).get
    p[0] * r.x + p[1] * r.y == r.g and r.g == gcd(p[0], p[1]).get)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: NUM-NT-04
test "NUM-NT-04 Given base, exponent and modulus, when using powMod, then it equals repeated multiplication; a negative exponent gives none":
  check powMod(2, 10, mdl(1000)).get == 24
  check powMod(5, 0, mdl(7)).get == 1
  check powMod(5, 0, mdl(1)).get == 0
  check powMod(2, -1, mdl(7)).isNone
  check powMod(-2, 3, mdl(7)).get == 6
  check powMod(3, 1_000_000_000_000, mdl(1_000_000_007)).isSome
  let outcome = check(pair(pair(intIn(-50, 50), intIn(0, 40)), intIn(1, 97)),
    proc(p: ((int, int), int)): bool {.raises: [CatchableError].} =
      powMod(p[0][0], p[0][1], mdl(p[1])).get == naivePow(p[0][0], p[0][1], p[1]))
  checkpoint describe(outcome)
  check outcome.passed
  # Fermat: a^(p-1) = 1 (mod p) for a prime p not dividing a.
  for p in [2, 3, 5, 7, 11, 13, 97, 1_000_000_007]:
    check isPrime(p)
    check powMod(5 + p, p - 1, mdl(p)).get == (if (5 + p) mod p == 0: 0 else: 1 mod p)

# SPEC: NUM-NT-05
test "NUM-NT-05 Given a and m, when inverting, then a*inv is 1 mod m exactly when a and m are coprime, else none":
  check modInverse(3, mdl(11)).get == 4
  check modInverse(2, mdl(4)).isNone
  check modInverse(0, mdl(1)).get == 0
  check modInverse(-3, mdl(11)).get == 7
  let outcome = check(pair(intIn(-200, 200), intIn(1, 120)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let inv = modInverse(p[0], mdl(p[1]))
    let coprime = gcd(p[0], p[1]).get == 1
    if coprime:
      inv.isSome and inv.get >= 0 and inv.get < p[1] and
        (p[0] * inv.get - 1) mod p[1] == 0
    else:
      inv.isNone)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: NUM-NT-06
test "NUM-NT-06 Given a modulus outside 1..maxModulus, when constructing it, then the result is none":
  check modulus(0).isNone
  check modulus(-5).isNone
  check modulus(maxModulus + 1).isNone
  check modulus(maxModulus).isSome
  check modulus(1).isSome
  check $mdl(97) == "97"
  check toInt(mdl(97)) == 97
  check residue(-1, mdl(7)) == 6
  check residue(15, mdl(7)) == 1
  check mdl(7) == mdl(7)
