import std/[unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/meet_in_middle

proc instances(): Gen[(seq[int], int)] {.raises: [ValueError].} =
  pair(seqOf(intIn(-9, 12), 0, 12), intIn(-30, 40))

func subsetSums(items: seq[int]): seq[int] {.raises: [].} =
  ## Oracle: the sum of every subset, one per bit mask.
  for mask in 0 ..< (1 shl items.len):
    var s = 0
    for i, x in items:
      if ((mask shr i) and 1) == 1:
        s += x
    result.add s

func bruteCount(items: seq[int]; target: int): int {.raises: [].} =
  for s in subsetSums(items):
    if s == target: inc result

func bruteClosest(items: seq[int]; target: int): int {.raises: [].} =
  result = 0
  var bestGap = abs(target)
  for s in subsetSums(items):
    let gap = abs(s - target)
    if gap < bestGap or (gap == bestGap and s < result):
      result = s
      bestGap = gap

# SPEC: MITM-COUNT-01
test "MITM-COUNT-01 Given hand-worked item lists, when counting subsets, then the known counts come back":
  check countSubsetSum(@[1, 2, 3, 4], 5).value == 2          # {1,4} {2,3}
  check countSubsetSum(@[1, 1, 1], 2).value == 3             # equal items are distinct choices
  check countSubsetSum(newSeq[int](), 0).value == 1          # the empty subset
  check countSubsetSum(newSeq[int](), 1).value == 0
  check countSubsetSum(@[5, -5], 0).value == 2               # {} and {5,-5}

# SPEC: MITM-COUNT-01
test "MITM-COUNT-01 Given any small instance, when counting, then the count equals brute force over all subsets":
  let outcome = check(instances(), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    countSubsetSum(p[0], p[1]).value == bruteCount(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: MITM-COUNT-02
test "MITM-COUNT-02 Given any instance, when the items are reordered, then the count is unchanged":
  let outcome = check(instances(), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    var flipped = p[0]
    for i in 0 ..< flipped.len div 2:
      swap(flipped[i], flipped[flipped.len - 1 - i])
    countSubsetSum(p[0], p[1]) == countSubsetSum(flipped, p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: MITM-EXISTS-01
test "MITM-EXISTS-01 Given any instance, when asking for existence, then it is true exactly when the count is positive":
  let outcome = check(instances(), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    subsetSumExists(p[0], p[1]).value == (bruteCount(p[0], p[1]) > 0))
  checkpoint describe(outcome)
  check outcome.passed
  check subsetSumExists(@[3, 34, 4, 12, 5, 2], 9).value
  check not subsetSumExists(@[3, 34, 4, 12, 5, 2], 30).value

# SPEC: MITM-CLOSEST-01
test "MITM-CLOSEST-01 Given any small instance, when asking for the nearest sum, then it equals brute force including the tie rule":
  let outcome = check(instances(), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    closestSubsetSum(p[0], p[1]).value == bruteClosest(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: MITM-CLOSEST-02
test "MITM-CLOSEST-02 Given a target between two sums or a reachable one, when asking, then the nearest or exact sum comes back":
  check closestSubsetSum(@[10, 20], 14).value == 10
  check closestSubsetSum(@[10, 20], 15).value == 10      # tie: the smaller sum
  check closestSubsetSum(@[10, 20], 16).value == 20
  check closestSubsetSum(@[10, 20], 30).value == 30
  check closestSubsetSum(newSeq[int](), 7).value == 0

# SPEC: MITM-LIMIT-01
test "MITM-LIMIT-01 Given input beyond the limits, when computing, then each limit has its own error and the limits themselves pass":
  var tooMany: seq[int]
  for _ in 0 .. MaxItems:
    tooMany.add 1
  check countSubsetSum(tooMany, 1).error == meTooManyItems
  check closestSubsetSum(tooMany, 1).error == meTooManyItems
  check subsetSumExists(@[MaxItemValue + 1], 0).error == meItemTooLarge
  check countSubsetSum(@[-MaxItemValue - 1], 0).error == meItemTooLarge
  check countSubsetSum(@[1], MaxTarget + 1).error == meTargetTooLarge
  check closestSubsetSum(@[1], -MaxTarget - 1).error == meTargetTooLarge
  check countSubsetSum(@[MaxItemValue], MaxItemValue).value == 1
  check countSubsetSum(@[1], MaxTarget).isOk

# SPEC: MITM-SCALE-01
test "MITM-SCALE-01 Given thirty items, when counting, then the answer is reached without 2^30 work and matches the closed form":
  # 30 items, all equal to 1: the number of subsets summing to k is C(30, k).
  var ones: seq[int]
  for _ in 0 ..< 30:
    ones.add 1
  check countSubsetSum(ones, 0).value == 1
  check countSubsetSum(ones, 2).value == 435
  check countSubsetSum(ones, 15).value == 155_117_520
  check countSubsetSum(ones, 31).value == 0
