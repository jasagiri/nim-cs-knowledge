import std/[algorithm, bitops, options, sequtils, unittest]
import propcheck
import nimcs/algo/analysis

proc sortedInts(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-20, 20), 0, 60).map(proc(xs: seq[int]): seq[int] {.raises: [].} = xs.sorted)

func costsOf(steps: seq[AppendStep]): seq[int] {.raises: [].} =
  for s in steps:
    result.add s.cost

func floorLog2(n: int): int {.raises: [].} =
  var k = 0
  var v = n
  while v > 1:
    v = v div 2
    inc k
  k

func valueOf(bits: seq[bool]): int {.raises: [].} =
  for i, b in bits:
    if b:
      result += 1 shl i

# SPEC: ANALYSIS-ASYMP-01
test "ANALYSIS-ASYMP-01 Given n distinct numbers, when duplicates are searched pair by pair, then exactly n(n-1)/2 comparisons are made":
  let outcome = check(intIn(0, 60), proc(n: int): bool {.raises: [CatchableError].} =
    let xs = toSeq(0 ..< n)
    let r = naiveDuplicateComparisons(xs)
    not r.found and r.comparisons == n * (n - 1) div 2)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ANALYSIS-ASYMP-01
test "ANALYSIS-ASYMP-01 Given an early duplicate, when searched, then the count stops early":
  check naiveDuplicateComparisons(@[4, 4, 1, 2, 3]).comparisons == 1
  check naiveDuplicateComparisons(@[4, 1, 2, 3, 4]).found
  check naiveDuplicateComparisons(newSeq[int]()).comparisons == 0

# SPEC: ANALYSIS-ASYMP-02
test "ANALYSIS-ASYMP-02 Given any sorted sequence and key, when binary searched, then the probes never exceed floor(log2 n) + 1":
  let outcome = check(pair(sortedInts(), intIn(-25, 25)), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, x) = c
    let probes = binarySearchSteps(xs, x)
    if xs.len == 0: probes == 0 else: probes >= 1 and probes <= floorLog2(xs.len) + 1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ANALYSIS-ASYMP-02
test "ANALYSIS-ASYMP-02 Given 1023 sorted items, when every key and the misses on both sides are probed, then the worst case is 10 probes":
  let xs = toSeq(0 ..< 1023)
  var worst = 0
  for x in -1 .. 1023:
    worst = max(worst, binarySearchSteps(xs, x))
  check worst == 10

# SPEC: ANALYSIS-ASYMP-03
test "ANALYSIS-ASYMP-03 Given stated constants, when the witness is checked, then a right claim holds and a wrong one is refuted":
  func quadraticPlusLinear(n: int): int {.raises: [].} = n * n + 10 * n
  func square(n: int): int {.raises: [].} = n * n
  func linear(n: int): int {.raises: [].} = n
  check isBigOOn(quadraticPlusLinear, square, 11, 1, 1000)
  check not isBigOOn(quadraticPlusLinear, square, 1, 1, 1000)     # the constant is too small
  check isBigOOn(quadraticPlusLinear, square, 11, 0, 1000)         # also from 0: both sides are 0 at n = 0
  check not isBigOOn(square, linear, 100, 1, 1000)                 # n^2 is not O(n): n = 101 breaks c = 100
  check isBigOmegaOn(quadraticPlusLinear, square, 1, 1, 1000)
  check not isBigOmegaOn(linear, square, 1, 2, 1000)

# SPEC: ANALYSIS-ASYMP-04
test "ANALYSIS-ASYMP-04 Given n >= 1, when the ceiling of log2 is asked, then 2^(k-1) < n <= 2^k, and below 1 there is none":
  let outcome = check(intIn(1, 100_000), proc(n: int): bool {.raises: [CatchableError].} =
    let k = ceilLog2(n)
    k.isSome and (1 shl k.get) >= n and (k.get == 0 or (1 shl (k.get - 1)) < n))
  checkpoint describe(outcome)
  check outcome.passed
  check ceilLog2(0).isNone
  check ceilLog2(-5).isNone
  check ceilLog2(1) == some(0)
  check ceilLog2(8) == some(3)
  check ceilLog2(9) == some(4)

# SPEC: ANALYSIS-ASYMP-05
test "ANALYSIS-ASYMP-05 Given a key, when scanned linearly, then the steps are its position plus one, or the length when absent":
  check linearSearchSteps(@[7, 8, 9], 7) == 1
  check linearSearchSteps(@[7, 8, 9], 9) == 3
  check linearSearchSteps(@[7, 8, 9], 5) == 3
  check linearSearchSteps(newSeq[int](), 5) == 0

# SPEC: ANALYSIS-AMORT-01
test "ANALYSIS-AMORT-01 Given n appends with doubling, when the real costs are added, then the total is at most 3n":
  let outcome = check(intIn(0, 400), proc(n: int): bool {.raises: [CatchableError].} =
    appendSteps(n, gDoubling).totalCost <= 3 * n)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ANALYSIS-AMORT-01
test "ANALYSIS-AMORT-01 Given five appends with doubling, when the costs are listed, then expensive resizes are rare":
  check appendSteps(5, gDoubling).costsOf == @[1, 2, 3, 1, 5]
  check appendSteps(0, gDoubling).len == 0
  check appendSteps(-3, gDoubling).len == 0

# SPEC: ANALYSIS-AMORT-02
test "ANALYSIS-AMORT-02 Given n appends growing by one, when the real costs are added, then the total is n(n+1)/2, above 3n from six on":
  let outcome = check(intIn(0, 200), proc(n: int): bool {.raises: [CatchableError].} =
    let total = appendSteps(n, gByOne).totalCost
    total == n * (n + 1) div 2 and (n < 6 or total > 3 * n))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ANALYSIS-AMORT-03
test "ANALYSIS-AMORT-03 Given any run of doubling appends, when the potential method is applied, then every amortized cost is at most 3 and the potential never goes negative":
  let outcome = check(intIn(1, 400), proc(n: int): bool {.raises: [CatchableError].} =
    let steps = appendSteps(n, gDoubling)
    let amortized = doublingAmortizedCosts(n)
    if amortized.len != n: return false
    var sumAmortized = 0
    for i, a in amortized:
      if a > 3 or potential(steps[i].size, steps[i].capacity) < 0: return false
      sumAmortized += a
    sumAmortized >= steps.totalCost)       # the credits pay for every real cost
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ANALYSIS-AMORT-04
test "ANALYSIS-AMORT-04 Given n increments of a binary counter, when flips are counted, then the total is exactly 2n minus the popcount of n":
  let outcome = check(intIn(0, 1000), proc(n: int): bool {.raises: [CatchableError].} =
    counterFlips(n) == 2 * n - countSetBits(n))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ANALYSIS-AMORT-04
test "ANALYSIS-AMORT-04 Given a counter, when incremented, then it holds the next number and the old counter is unchanged":
  let outcome = check(intIn(0, 1000), proc(n: int): bool {.raises: [CatchableError].} =
    var bits: seq[bool]
    for _ in 1 .. n:
      bits = incrementBits(bits).bits
    let before = bits
    let step = incrementBits(bits)
    valueOf(step.bits) == n + 1 and bits == before and valueOf(before) == n)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ANALYSIS-AMORT-04
test "ANALYSIS-AMORT-04 Given a counter of all ones, when incremented, then a single increment flips every bit":
  let step = incrementBits(@[true, true, true])
  check step.flips == 4
  check step.bits == @[false, false, false, true]
