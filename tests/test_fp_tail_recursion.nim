import std/unittest
import propcheck
import nimcs/fp/tail_recursion

# SPEC: FP-TAILRECURSION-01
test "FP-TAILRECURSION-01 Given a small n, when the sum is computed by naive recursion, accumulator recursion and loop, then all agree and equal the closed form":
  check sumToNaive(0) == 0
  check sumToNaive(10) == 55
  let outcome = check(intIn(0, 500), proc(n: int): bool {.raises: [CatchableError].} =
    let expected = n * (n + 1) div 2
    sumToNaive(n) == expected and sumToAcc(n, 0) == expected and sumToLoop(n) == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TAILRECURSION-02
test "FP-TAILRECURSION-02 Given an accumulator, when sumToAcc starts from it, then the result is the accumulator plus the sum":
  let outcome = check(pair(intIn(0, 500), intIn(-1000, 1000)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    sumToAcc(p[0], p[1]) == p[1] + sumToNaive(p[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TAILRECURSION-03
test "FP-TAILRECURSION-03 Given an index, when Fibonacci is computed by definition, accumulators and loop, then all agree":
  check fibLoop(0) == 0
  check fibLoop(1) == 1
  check fibLoop(10) == 55
  let outcome = check(intIn(0, 20), proc(n: int): bool {.raises: [CatchableError].} =
    let i = FibIndex(n)
    fibNaive(i) == fibLoop(i) and fibAcc(n, 0, 1) == fibLoop(i))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TAILRECURSION-04
test "FP-TAILRECURSION-04 Given the largest index, when the loop computes it, then the value fits and the recurrence holds":
  check fibLoop(92) == 7540113804746346429
  check fibAcc(92, 0, 1) == fibLoop(92)
  let outcome = check(intIn(2, 92), proc(n: int): bool {.raises: [CatchableError].} =
    fibLoop(FibIndex(n)) == fibLoop(FibIndex(n - 1)) + fibLoop(FibIndex(n - 2)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TAILRECURSION-05
test "FP-TAILRECURSION-05 Given a very large n, when the loop sums it, then it finishes in constant stack with the closed-form value":
  check sumToLoop(10_000_000) == 10_000_000 * 10_000_001 div 2
  check sumToLoop(100_000_000) == 5000000050000000

# SPEC: FP-TAILRECURSION-06
test "FP-TAILRECURSION-06 Given two numbers, when gcd is computed recursively and by loop, then both agree, divide both, and are symmetric":
  check gcdRec(12, 18) == 6
  check gcdLoop(0, 5) == 5
  let outcome = check(pair(intIn(0, 300), intIn(0, 300)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let (a, b) = p
    let g = gcdLoop(a, b)
    gcdRec(a, b) == g and gcdLoop(b, a) == g and
      (if g == 0: a == 0 and b == 0 else: a mod g == 0 and b mod g == 0))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TAILRECURSION-07
test "FP-TAILRECURSION-07 Given a subrange-typed branch in an if expression, when the other branch is out of range, then the expression raises RangeDefect unless converted":
  type Small = range[0 .. 3]
  func pickRaw(n: Small; big: int): int = (if n < 2: n else: big)
  func pickConverted(n: Small; big: int): int = (if n < 2: int(n) else: big)
  check pickConverted(Small(3), 100) == 100
  check pickConverted(Small(1), 100) == 1
  expect RangeDefect:
    check pickRaw(Small(3), 100) == 100
