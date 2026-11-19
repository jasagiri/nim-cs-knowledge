import std/[unittest, options]
import propcheck
import nimcs/algo/divide_conquer

func sliceSum(xs: seq[int]; s: Subarray): int {.raises: [].} =
  for i in s.first .. s.last:
    result += xs[i]

func bruteMax(xs: seq[int]): int {.raises: [].} =
  result = low(int)
  for i in 0 ..< xs.len:
    var sum = 0
    for j in i ..< xs.len:
      sum += xs[j]
      if sum > result:
        result = sum

# SPEC: TECH-DC-MAXSUB-01
test "TECH-DC-MAXSUB-01 Given known arrays, when running Kadane, then the sum and slice are the hand-worked ones":
  let xs = @[-2, 1, -3, 4, -1, 2, 1, -5, 4]
  check maxSubarrayKadane(xs).get == Subarray(sum: 6, first: 3, last: 6)
  check maxSubarrayKadane(@[-3, -1, -2]).get == Subarray(sum: -1, first: 1, last: 1)
  check maxSubarrayKadane(@[5]).get == Subarray(sum: 5, first: 0, last: 0)

# SPEC: TECH-DC-MAXSUB-02
test "TECH-DC-MAXSUB-02 Given known arrays, when running divide and conquer, then the sum matches":
  check maxSubarrayDc(@[-2, 1, -3, 4, -1, 2, 1, -5, 4]).get.sum == 6
  check maxSubarrayDc(@[-3, -1, -2]).get.sum == -1
  check maxSubarrayDc(@[2, -1, 2]).get == Subarray(sum: 3, first: 0, last: 2)

# SPEC: TECH-DC-MAXSUB-03
test "TECH-DC-MAXSUB-03 Given any non-empty array, when comparing both methods and brute force, then the sums agree and each slice adds up":
  let outcome = check(seqOf(intIn(-9, 9), 1, 25), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let k = maxSubarrayKadane(xs).get
    let d = maxSubarrayDc(xs).get
    k.sum == d.sum and k.sum == bruteMax(xs) and
      k.first >= 0 and k.last < xs.len and k.first <= k.last and sliceSum(xs, k) == k.sum and
      d.first >= 0 and d.last < xs.len and d.first <= d.last and sliceSum(xs, d) == d.sum)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-DC-MAXSUB-04
test "TECH-DC-MAXSUB-04 Given an empty array, when asking for the maximum subarray, then the result is none":
  check maxSubarrayKadane(newSeq[int]()).isNone
  check maxSubarrayDc(newSeq[int]()).isNone

# SPEC: TECH-DC-MASTER-01
test "TECH-DC-MASTER-01 Given classic recurrences, when classifying, then each lands in its textbook case":
  check masterCase(2, 2, 1) == some(mcBalanced)   # merge sort
  check masterCase(1, 2, 0) == some(mcBalanced)   # binary search
  check masterCase(3, 2, 1) == some(mcLeaves)     # Karatsuba
  check masterCase(7, 2, 2) == some(mcLeaves)     # Strassen
  check masterCase(1, 2, 1) == some(mcRoot)       # halving with linear work
  check masterCase(2, 2, 0) == some(mcLeaves)     # divide and conquer maximum subarray scan without combine cost
  check masterCase(2, 3, 5) == some(mcRoot)

# SPEC: TECH-DC-MASTER-02
test "TECH-DC-MASTER-02 Given a, b, d, when comparing with exact powers, then the case agrees and never moves toward the root as a grows; huge d does not overflow":
  let outcome = check(pair(intIn(1, 60), pair(intIn(2, 5), intIn(0, 6))),
    proc(p: (int, (int, int))): bool {.raises: [CatchableError].} =
      let (a, (b, d)) = p
      var pw = 1
      for _ in 1 .. d:
        pw *= b
      let expected = if a < pw: mcRoot elif a == pw: mcBalanced else: mcLeaves
      masterCase(a, b, d).get == expected and
        ord(masterCase(a + 1, b, d).get) >= ord(masterCase(a, b, d).get))
  checkpoint describe(outcome)
  check outcome.passed
  check masterCase(high(int), 2, 1_000_000) == some(mcRoot)
  check masterCase(high(int), 2, 62) == some(mcLeaves)

# SPEC: TECH-DC-MASTER-03
test "TECH-DC-MASTER-03 Given a < 1, b < 2 or d < 0, when classifying, then the result is none":
  check masterCase(0, 2, 1).isNone
  check masterCase(2, 1, 1).isNone
  check masterCase(2, 2, -1).isNone
