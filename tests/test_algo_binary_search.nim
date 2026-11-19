import std/[options, sequtils, unittest]
import std/algorithm except lowerBound, upperBound, binarySearch
import propcheck
import nimcs/algo/binary_search

# A sorted sequence with duplicates, and a probe value that may or may not occur in it.
proc cases(): Gen[(seq[int], int)] {.raises: [ValueError].} =
  pair(seqOf(intIn(-8, 8), 0, 25).map(proc(xs: seq[int]): seq[int] {.raises: [].} = sorted(xs)), intIn(-9, 9))

# SPEC: SEARCH-LOWER-01
test "SEARCH-LOWER-01 Given a sorted sequence and a value, when lowerBound is taken, then everything before it is smaller and everything from it is not":
  let outcome = check(cases(), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, x) = c
    let i = lowerBound(xs, x)
    xs[0 ..< i].allIt(it < x) and xs[i ..< xs.len].allIt(it >= x))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SEARCH-UPPER-01
test "SEARCH-UPPER-01 Given a sorted sequence and a value, when upperBound is taken, then everything before it is at most the value and everything from it is larger":
  let outcome = check(cases(), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, x) = c
    let i = upperBound(xs, x)
    xs[0 ..< i].allIt(it <= x) and xs[i ..< xs.len].allIt(it > x))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SEARCH-RANGE-01
test "SEARCH-RANGE-01 Given a sorted sequence and a value, when both bounds are taken, then they span exactly the copies of the value":
  let outcome = check(cases(), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, x) = c
    upperBound(xs, x) - lowerBound(xs, x) == xs.count(x))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SEARCH-FIND-01
test "SEARCH-FIND-01 Given a sorted sequence and a value, when searched, then the first equal index is found exactly when the value is present":
  let outcome = check(cases(), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, x) = c
    let found = binarySearch(xs, x)
    if x in xs: found == some(xs.find(x)) else: found.isNone)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SEARCH-LOWER-01
# SPEC: SEARCH-UPPER-01
test "SEARCH-LOWER-01 Given a descending sequence, when a descending comparator is passed, then the bounds follow that order":
  let xs = @[9, 7, 7, 4, 1]
  let after = proc(a, b: int): bool {.noSideEffect, raises: [].} = a > b
  check lowerBound(xs, 7, after) == 1
  check upperBound(xs, 7, after) == 3
  check lowerBound(xs, 5, after) == 3
  check binarySearch(xs, 4, after) == some(3)
  check binarySearch(xs, 5, after).isNone

# SPEC: SEARCH-LOWER-01
test "SEARCH-LOWER-01 Given an empty sequence, when searched, then the bounds are zero and nothing is found":
  check lowerBound(newSeq[int](), 3) == 0
  check upperBound(newSeq[int](), 3) == 0
  check binarySearch(newSeq[int](), 3).isNone

# SPEC: SEARCH-PARTITION-01
test "SEARCH-PARTITION-01 Given a monotone predicate, when partitionPoint is taken, then it is the first index where the predicate holds":
  let outcome = check(cases(), proc(c: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, threshold) = c
    let atLeast = proc(e: int): bool {.noSideEffect, raises: [].} = e >= threshold
    let expected = block:
      var at = xs.len
      for i, e in xs:
        if e >= threshold:
          at = i
          break
      at
    partitionPoint(xs, atLeast) == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SEARCH-FIRST-01
test "SEARCH-FIRST-01 Given a monotone predicate on a range, when firstTrue is taken, then it is the least index satisfying it, or the upper end":
  let outcome = check(pair(intIn(0, 200), pair(intIn(0, 5), intIn(0, 20))), proc(c: (int, (int, int))): bool {.raises: [CatchableError].} =
    let (target, (lo, width)) = c
    let hi = lo + width
    let big = proc(i: int): bool {.noSideEffect, raises: [].} = i * i * 3 >= target
    let expected = block:
      var at = hi
      for i in lo ..< hi:
        if big(i):
          at = i
          break
      at
    firstTrue(lo, hi, big) == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SEARCH-FIRST-01
test "SEARCH-FIRST-01 Given an empty range, when firstTrue is taken, then it returns the lower end without calling the predicate":
  check firstTrue(4, 4, proc(i: int): bool {.noSideEffect, raises: [].} = true) == 4

# SPEC: SEARCH-FIRST-01
test "SEARCH-FIRST-01 Given a range spanning the whole int type, when firstTrue is taken, then no arithmetic overflows":
  let atLeast5 = proc(i: int): bool {.noSideEffect, raises: [].} = i >= 5
  check firstTrue(low(int), high(int), atLeast5) == 5
  check firstTrue(low(int), high(int), proc(i: int): bool {.noSideEffect, raises: [].} = false) == high(int)
  check firstTrue(low(int), high(int), proc(i: int): bool {.noSideEffect, raises: [].} = true) == low(int)
  check firstTrue(low(int), 0, proc(i: int): bool {.noSideEffect, raises: [].} = i >= -3) == -3
  check firstTrue(-1, 0, proc(i: int): bool {.noSideEffect, raises: [].} = true) == -1

# SPEC: SEARCH-FIRST-01
test "SEARCH-FIRST-01 Given any range and threshold over the whole int type, when firstTrue is taken, then it is the larger of lower end and threshold, capped at the upper end":
  let outcome = check(pair(intIn(low(int), high(int)), pair(intIn(low(int), high(int)), intIn(low(int), high(int)))),
      proc(c: (int, (int, int))): bool {.raises: [CatchableError].} =
    let (a, (b, t)) = c
    let (lo, hi) = (min(a, b), max(a, b))
    let expected = if max(lo, t) < hi: max(lo, t) else: hi
    firstTrue(lo, hi, proc(i: int): bool {.noSideEffect, raises: [].} = i >= t) == expected)
  checkpoint describe(outcome)
  check outcome.passed
