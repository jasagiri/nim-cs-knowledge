import std/[algorithm, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/two_pointers

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-9, 9), 0, 16)

proc naturals(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(0, 9), 0, 16)

func bruteForcePair(xs: seq[int]; target: int): Result[(int, int), PairError] {.raises: [].} =
  ## Smallest i first, then largest j, trying every pair.
  for i in 0 ..< xs.len:
    for j in countdown(xs.len - 1, i + 1):
      if xs[i] + xs[j] == target:
        return ok((i, j), PairError)
  err((int, int), peNoPair)

func bruteForceWindow(xs: seq[int]; bound: int): Window {.raises: [].} =
  ## Longest, then earliest, trying every start and length.
  for start in 0 ..< xs.len:
    var sum = 0
    for stop in start ..< xs.len:
      sum += xs[stop]
      if sum <= bound and stop - start + 1 > result.len:
        result = Window(start: start, len: stop - start + 1)

# SPEC: TECH-TWOPTR-01
test "TECH-TWOPTR-01 Given a sorted sequence and a target, when the pair is asked, then it equals a brute-force search over all pairs":
  let outcome = check(pair(ints(), intIn(-18, 18)), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let xs = c[0].sorted
    pairWithSum(xs, c[1]) == bruteForcePair(xs, c[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-TWOPTR-01
test "TECH-TWOPTR-01 Given a known sequence, when the pair is asked, then the indices are those of the two summands":
  check pairWithSum(@[1, 3, 4, 6, 9], 10) == ok((0, 4), PairError)
  check pairWithSum(@[2, 2, 2, 2], 4) == ok((0, 3), PairError)

# SPEC: TECH-TWOPTR-02
test "TECH-TWOPTR-02 Given no pair that adds up, when asked, then the error says no pair":
  check pairWithSum(@[1, 2, 4], 100) == err((int, int), peNoPair)
  check pairWithSum(newSeq[int](), 0) == err((int, int), peNoPair)
  check pairWithSum(@[5], 10) == err((int, int), peNoPair)   # one element cannot pair with itself

# SPEC: TECH-TWOPTR-03
test "TECH-TWOPTR-03 Given an unsorted sequence, when asked, then the error says not sorted":
  check pairWithSum(@[3, 1, 2], 4) == err((int, int), peNotSorted)

# SPEC: TECH-WINDOW-01
test "TECH-WINDOW-01 Given non-negative numbers and a bound, when the longest window is asked, then it equals a brute-force search":
  let outcome = check(pair(naturals(), intIn(0, 40)), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let w = longestWindowAtMost(c[0], c[1])
    if not w.isOk: return false
    var sum = 0
    for i in w.value.start ..< w.value.start + w.value.len:
      sum += c[0][i]
    w.value == bruteForceWindow(c[0], c[1]) and sum <= c[1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-WINDOW-01
test "TECH-WINDOW-01 Given a known sequence, when the longest window is asked, then the earliest longest one is returned":
  check longestWindowAtMost(@[1, 2, 1, 1, 5, 1, 1, 1], 3) == ok(Window(start: 5, len: 3), WindowError)
  check longestWindowAtMost(@[1, 1, 3, 1, 1], 2) == ok(Window(start: 0, len: 2), WindowError)
  check longestWindowAtMost(@[9, 9], 3) == ok(Window(start: 0, len: 0), WindowError)
  check longestWindowAtMost(newSeq[int](), 3) == ok(Window(start: 0, len: 0), WindowError)

# SPEC: TECH-WINDOW-02
test "TECH-WINDOW-02 Given any numbers and a size, when the window sums are asked, then each equals the re-added sum of its window":
  let outcome = check(pair(ints(), intIn(1, 6)), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, size) = c
    let sums = windowSums(xs, size)
    if not sums.isOk: return false
    var expected: seq[int]
    for start in 0 .. xs.len - size:
      var s = 0
      for k in start ..< start + size:
        s += xs[k]
      expected.add s
    sums.value == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-WINDOW-03
test "TECH-WINDOW-03 Given a negative element, when the longest window is asked, then the error names it":
  check longestWindowAtMost(@[1, -1, 2], 5) == err(Window, weNegativeElement)

# SPEC: TECH-WINDOW-04
test "TECH-WINDOW-04 Given a negative bound, when the longest window is asked, then the error names it":
  check longestWindowAtMost(@[1, 2], -1) == err(Window, weNegativeBound)

# SPEC: TECH-WINDOW-05
test "TECH-WINDOW-05 Given a size below one, when window sums are asked, then the error says bad size":
  check windowSums(@[1, 2, 3], 0) == err(seq[int], weBadSize)
  check windowSums(@[1, 2], 3) == ok(newSeq[int](), WindowError)
