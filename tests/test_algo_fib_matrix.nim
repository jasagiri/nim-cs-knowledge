import std/[unittest, options]
import propcheck
import nimcs/algo/fib_matrix

func fibIter(n: int): int {.raises: [].} =
  ## The loop; exact up to F(92).
  if n == 0:
    return 0
  var a = 0
  var b = 1
  for _ in 1 ..< n:   # stops at b = F(n), so F(93) is never formed
    let c = a + b
    a = b
    b = c
  b

func fibIterMod(n, m: int): int {.raises: [].} =
  var a = 0 mod m
  var b = 1 mod m
  for _ in 0 ..< n:
    let c = (a + b) mod m
    a = b
    b = c
  a

# SPEC: NUM-FIBM-01
test "NUM-FIBM-01 Given every n in 0..92, when using the matrix power, then it equals the iterative value":
  for n in 0 .. maxFibExact:
    check fibMatrix(n) == some(fibIter(n))
  check fibMatrix(92).get == 7540113804746346429
  check fibMatrix(10).get == 55

# SPEC: NUM-FIBM-02
test "NUM-FIBM-02 Given n and a modulus, when using fibMod, then it equals the iterative value mod m":
  let outcome = check(pair(intIn(0, 300), intIn(1, 100_000)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    fibMod(p[0], p[1]) == some(fibIterMod(p[0], p[1])))
  checkpoint describe(outcome)
  check outcome.passed
  check fibMod(10, 1) == some(0)
  check fibMod(90, maxFibModulus) == some(fibIter(90) mod maxFibModulus)

# SPEC: NUM-FIBM-03
test "NUM-FIBM-03 Given n outside 0..92, when using the exact form, then the result is none; the recurrence holds inside":
  check fibMatrix(-1).isNone
  check fibMatrix(maxFibExact + 1).isNone
  check fibMatrix(high(int)).isNone
  let outcome = check(intIn(2, maxFibExact), proc(n: int): bool {.raises: [CatchableError].} =
    fibMatrix(n).get == fibMatrix(n - 1).get + fibMatrix(n - 2).get)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: NUM-FIBM-04
test "NUM-FIBM-04 Given a huge n, when using fibMod, then Pisano periodicity holds and invalid arguments give none":
  # The Fibonacci numbers mod 10 repeat with period 60.
  let outcome = check(intIn(0, 1_000_000_000), proc(n: int): bool {.raises: [CatchableError].} =
    fibMod(n, 10) == fibMod(n mod 60, 10) and fibMod(n + 60, 10) == fibMod(n, 10))
  checkpoint describe(outcome)
  check outcome.passed
  check fibMod(high(int) - 1, 1_000_000_007).isSome
  check fibMod(-1, 7).isNone
  check fibMod(5, 0).isNone
  check fibMod(5, -3).isNone
  check fibMod(5, maxFibModulus + 1).isNone
