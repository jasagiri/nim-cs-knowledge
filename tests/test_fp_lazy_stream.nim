import std/unittest
import propcheck
import nimcs/fp/lazy_stream

func succ1(x: int): int {.raises: [].} = x + 1
func sq(x: int): int {.raises: [].} = x * x
func isEven(x: int): bool {.raises: [].} = x mod 2 == 0
func small(x: int): bool {.raises: [].} = x < 10

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-30, 30), 0, 12)

# SPEC: FP-LAZYSTREAM-01
test "FP-LAZYSTREAM-01 Given a sequence, when turned into a stream and collected, then the elements come back in order up to the limit":
  check fromSeq([1, 2, 3]).toSeq(10) == @[1, 2, 3]
  check emptyStream[int]().toSeq(10).len == 0
  let outcome = check(pair(ints(), intIn(0, 15)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    fromSeq(p[0]).toSeq(p[1]) == p[0][0 ..< min(p[0].len, p[1])])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-LAZYSTREAM-02
test "FP-LAZYSTREAM-02 Given a sequence, when mapped and filtered as a stream, then the result equals the eager map and filter":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    var mapped, filtered: seq[int]
    for x in xs:
      mapped.add sq(x)
      if isEven(x):
        filtered.add x
    fromSeq(xs).map(sq).toSeq(100) == mapped and fromSeq(xs).filter(isEven).toSeq(100) == filtered)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-LAZYSTREAM-03
test "FP-LAZYSTREAM-03 Given an infinite stream, when take n and collected, then exactly n elements are produced":
  check iterate(0, succ1).take(5).toSeq(100) == @[0, 1, 2, 3, 4]
  check iterate(0, succ1).take(0).toSeq(100).len == 0
  let outcome = check(intIn(0, 40), proc(n: int): bool {.raises: [CatchableError].} =
    iterate(7, succ1).take(n).toSeq(1000).len == n)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-LAZYSTREAM-04
test "FP-LAZYSTREAM-04 Given an infinite stream, when filter and map are chained before take, then only the needed prefix is computed":
  # Terminating at all is the evidence: an eager version would never return.
  let firstEvenSquares = iterate(1, succ1).filter(isEven).map(sq).take(4).toSeq(100)
  check firstEvenSquares == @[4, 16, 36, 64]
  check iterate(1, succ1).takeWhile(small).toSeq(1000) == @[1, 2, 3, 4, 5, 6, 7, 8, 9]

# SPEC: FP-LAZYSTREAM-04
test "FP-LAZYSTREAM-04 Given a step that would overflow past the needed prefix, when take n is collected, then the step is not run for the unneeded element":
  # succ1(high(int)) would raise OverflowDefect: it only passes if nothing beyond the prefix is computed.
  check iterate(high(int) - 2, succ1).take(3).toSeq(10) == @[high(int) - 2, high(int) - 1, high(int)]
  check iterate(high(int) - 1, succ1).map(succ1).take(1).toSeq(10) == @[high(int)]

# SPEC: FP-LAZYSTREAM-08
test "FP-LAZYSTREAM-08 Given a long sequence, when streamed and collected, then every element comes back in order":
  var big = newSeq[int](20_000)
  for i in 0 ..< big.len:
    big[i] = i
  let walked = fromSeq(big).toSeq(big.len)
  check walked.len == big.len
  check walked[^1] == big.len - 1

# SPEC: FP-LAZYSTREAM-05
test "FP-LAZYSTREAM-05 Given a stream, when walked twice, then both walks give the same elements":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let s = fromSeq(xs).filter(isEven).map(sq)
    s.toSeq(100) == s.toSeq(100))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-LAZYSTREAM-06
test "FP-LAZYSTREAM-06 Given a stream, when take n then take m, then it equals take of the smaller":
  let outcome = check(pair(intIn(0, 20), intIn(0, 20)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let s = iterate(0, succ1)
    s.take(p[0]).take(p[1]).toSeq(100) == s.take(min(p[0], p[1])).toSeq(100))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-LAZYSTREAM-07
test "FP-LAZYSTREAM-07 Given a limit, when an infinite stream is collected, then at most the limit elements are returned":
  check iterate(0, succ1).toSeq(6) == @[0, 1, 2, 3, 4, 5]
  check iterate(0, succ1).toSeq(0).len == 0
