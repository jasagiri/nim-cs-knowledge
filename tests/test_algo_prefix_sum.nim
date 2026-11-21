import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/algo/prefix_sum

type
  Update = (int, int, int)   # (start, end, delta) before reduction into 0 .. n

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-20, 20), 0, 30)

proc grids(): Gen[seq[seq[int]]] {.raises: [ValueError].} =
  ## A rectangular grid of 0 .. 5 rows and 0 .. 5 columns, cut from a flat list of numbers.
  pair(pair(intIn(0, 5), intIn(0, 5)), seqOf(intIn(-9, 9), 25, 25)).map(
    proc(c: ((int, int), seq[int])): seq[seq[int]] {.raises: [].} =
      for i in 0 ..< c[0][0]:
        result.add c[1][i * 5 ..< i * 5 + c[0][1]])

func bruteSum(xs: seq[int]; l, r: int): int {.raises: [].} =
  for i in l ..< r:
    result += xs[i]

func bruteRect(g: seq[seq[int]]; r0, c0, r1, c1: int): int {.raises: [].} =
  for i in r0 ..< r1:
    for j in c0 ..< c1:
      result += g[i][j]

# SPEC: TECH-PREFIX-01
test "TECH-PREFIX-01 Given any numbers, when the prefix table is built, then it has one more entry, starts at zero and adds each element":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let p = prefixOf(xs)
    if p.count != xs.len: return false
    for i in 0 .. xs.len:
      if p.rangeSum(0, i) != ok(bruteSum(xs, 0, i), SpanError): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
  check prefixOf(newSeq[int]()).count == 0

# SPEC: TECH-PREFIX-02
test "TECH-PREFIX-02 Given any numbers and any valid range, when its sum is asked, then it equals the sum added element by element":
  let outcome = check(pair(ints(), pair(intIn(0, 30), intIn(0, 30))), proc(c: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
    let xs = c[0]
    let l = min(c[1][0], c[1][1]) mod (xs.len + 1)
    let r = l + max(c[1][0], c[1][1]) mod (xs.len - l + 1)
    let p = prefixOf(xs)
    # the sum of a range is additive over a split point inside it
    let m = l + (r - l) div 2
    p.rangeSum(l, r) == ok(bruteSum(xs, l, r), SpanError) and
      p.rangeSum(l, m).value + p.rangeSum(m, r).value == p.rangeSum(l, r).value)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-PREFIX-02
test "TECH-PREFIX-02 Given a known sequence, when ranges are asked, then the empty range is zero":
  let p = prefixOf([3, -1, 4, 1, -5])
  check p.rangeSum(1, 4) == ok(4, SpanError)
  check p.rangeSum(0, 5) == ok(2, SpanError)
  check p.rangeSum(2, 2) == ok(0, SpanError)

# SPEC: TECH-PREFIX-03
test "TECH-PREFIX-03 Given an outside or reversed range, when asked, then each has its own error":
  let p = prefixOf([1, 2, 3])
  check p.rangeSum(-1, 2) == err(int, reOutOfBounds)
  check p.rangeSum(0, 4) == err(int, reOutOfBounds)
  check p.rangeSum(2, 1) == err(int, reReversed)
  check prefixOf(newSeq[int]()).rangeSum(0, 1) == err(int, reOutOfBounds)

# SPEC: TECH-PREFIX-04
test "TECH-PREFIX-04 Given any numbers, when differences and running sums are applied in either order, then the original comes back":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    fromDifferences(differences(xs)) == xs and differences(fromDifferences(xs)) == xs)
  checkpoint describe(outcome)
  check outcome.passed
  check differences([5, 7, 7, 4]) == @[5, 2, 0, -3]

# SPEC: TECH-PREFIX-05
test "TECH-PREFIX-05 Given range additions, when applied through a difference array, then the result equals adding each range element by element":
  let outcome = check(pair(intIn(0, 12), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(-5, 5))), 0, 10)),
    proc(c: (int, seq[(int, (int, int))])): bool {.raises: [CatchableError].} =
      let n = c[0]
      var adds: seq[Update]
      var expected = newSeq[int](n)
      for (a, rest) in c[1]:
        let l = a mod (n + 1)
        let r = l + rest[0] mod (n - l + 1)
        adds.add (l, r, rest[1])
        for i in l ..< r:
          expected[i] += rest[1]
      applyRangeAdds(n, adds) == ok(expected, SpanError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-PREFIX-05
test "TECH-PREFIX-05 Given overlapping updates, when applied, then deltas add where ranges overlap and an empty range changes nothing":
  check applyRangeAdds(5, [(0, 3, 2), (2, 5, 10), (4, 4, 99)]) == ok(@[2, 2, 12, 10, 10], SpanError)
  check applyRangeAdds(0, newSeq[Update]()) == ok(newSeq[int](), SpanError)

# SPEC: TECH-PREFIX-06
test "TECH-PREFIX-06 Given an update outside the array, a reversed update or a negative size, when applied, then each has its own error":
  check applyRangeAdds(3, [(0, 4, 1)]) == err(seq[int], reOutOfBounds)
  check applyRangeAdds(3, [(-1, 2, 1)]) == err(seq[int], reOutOfBounds)
  check applyRangeAdds(3, [(2, 1, 1)]) == err(seq[int], reReversed)
  check applyRangeAdds(-1, newSeq[Update]()) == err(seq[int], reOutOfBounds)

# SPEC: TECH-PREFIX-07
test "TECH-PREFIX-07 Given any grid and any valid rectangle, when its sum is asked, then it equals the sum added cell by cell":
  let outcome = check(pair(grids(), pair(pair(intIn(0, 5), intIn(0, 5)), pair(intIn(0, 5), intIn(0, 5)))),
    proc(c: (seq[seq[int]], ((int, int), (int, int)))): bool {.raises: [CatchableError].} =
      let g = c[0]
      let cols = if g.len == 0: 0 else: g[0].len
      let r0 = min(c[1][0][0], c[1][0][1]) mod (g.len + 1)
      let r1 = r0 + max(c[1][0][0], c[1][0][1]) mod (g.len - r0 + 1)
      let c0 = min(c[1][1][0], c[1][1][1]) mod (cols + 1)
      let c1 = c0 + max(c[1][1][0], c[1][1][1]) mod (cols - c0 + 1)
      let p = prefixOf2D(g)
      p.isOk and p.value.rowCount == g.len and p.value.columnCount == cols and
        p.value.rectSum(r0, c0, r1, c1) == ok(bruteRect(g, r0, c0, r1, c1), SpanError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-PREFIX-07
test "TECH-PREFIX-07 Given a small grid, when rectangles are asked, then the whole grid, one cell and an empty rectangle come out right":
  let p = prefixOf2D(@[@[1, 2, 3], @[4, 5, 6]]).value
  check p.rectSum(0, 0, 2, 3) == ok(21, SpanError)
  check p.rectSum(1, 1, 2, 2) == ok(5, SpanError)
  check p.rectSum(0, 1, 2, 3) == ok(16, SpanError)
  check p.rectSum(1, 1, 1, 3) == ok(0, SpanError)

# SPEC: TECH-PREFIX-08
test "TECH-PREFIX-08 Given a rectangle outside the grid or reversed on either axis, when asked, then each has its own error":
  let p = prefixOf2D(@[@[1, 2], @[3, 4]]).value
  check p.rectSum(0, 0, 3, 2) == err(int, reOutOfBounds)
  check p.rectSum(0, 0, 2, 3) == err(int, reOutOfBounds)
  check p.rectSum(-1, 0, 1, 1) == err(int, reOutOfBounds)
  check p.rectSum(0, -1, 1, 1) == err(int, reOutOfBounds)
  check p.rectSum(2, 0, 1, 1) == err(int, reReversed)
  check p.rectSum(0, 2, 1, 1) == err(int, reReversed)

# SPEC: TECH-PREFIX-09
test "TECH-PREFIX-09 Given rows of different lengths, when the table is built, then the error says ragged; empty grids are fine":
  check prefixOf2D(@[@[1, 2], @[3]]) == err(PrefixSums2D, reRagged)
  check prefixOf2D(@[@[1], @[2, 3]]) == err(PrefixSums2D, reRagged)
  check prefixOf2D(newSeq[seq[int]]()).isOk
  let rowsOfNothing = prefixOf2D(@[newSeq[int](), newSeq[int]()])
  check rowsOfNothing.isOk
  check rowsOfNothing.value.rectSum(0, 0, 2, 0) == ok(0, SpanError)
