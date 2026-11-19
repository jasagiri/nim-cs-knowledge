import std/unittest
import propcheck
import nimcs/algo/lis

func quadraticLength(xs: seq[int]): int {.raises: [].} =
  ## The O(n^2) table the fast algorithm is checked against.
  var best = newSeq[int](xs.len)
  for i in 0 ..< xs.len:
    best[i] = 1
    for j in 0 ..< i:
      if xs[j] < xs[i] and best[j] + 1 > best[i]:
        best[i] = best[j] + 1
    if best[i] > result:
      result = best[i]

# SPEC: DP-LIS-01
test "DP-LIS-01 Given known sequences, when taking the lis, then the length matches the hand-worked answer":
  check lisLength(@[10, 9, 2, 5, 3, 7, 101, 18]) == 4
  check lisLength(@[0, 1, 0, 3, 2, 3]) == 4
  check lisLength(@[7, 7, 7, 7]) == 1
  check lisLength(newSeq[int]()) == 0
  check lisLength(@[5, 4, 3, 2, 1]) == 1
  check lisLength(@[1, 2, 3, 4]) == 4
  check lis(@['d', 'a', 'b', 'c']) == @['a', 'b', 'c']

# SPEC: DP-LIS-02
test "DP-LIS-02 Given any sequence, when taking the lis, then its length equals the quadratic table's":
  let outcome = check(seqOf(intIn(-5, 5), 0, 30), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    lisLength(xs) == quadraticLength(xs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-LIS-03
test "DP-LIS-03 Given any sequence, when taking the lis, then it is strictly increasing and read off the input in order":
  let outcome = check(seqOf(intIn(-5, 5), 0, 30), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let idx = lisIndices(xs)
    let vals = lis(xs)
    var ok = idx.len == vals.len
    for k in 0 ..< idx.len:
      ok = ok and idx[k] >= 0 and idx[k] < xs.len and vals[k] == xs[idx[k]]
      if k > 0:
        ok = ok and idx[k - 1] < idx[k] and vals[k - 1] < vals[k]
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-LIS-04
test "DP-LIS-04 Given a sequence with several longest answers, when taking the lis twice, then the same one is returned":
  let xs = @[1, 2, 1, 2, 3, 0, 4]
  check lis(xs) == lis(xs)
  check lisIndices(xs) == lisIndices(xs)
  check lis(@[2, 1, 4, 3]) == @[1, 3]   # both [2,4] and [1,3] are longest; the smaller ending wins
