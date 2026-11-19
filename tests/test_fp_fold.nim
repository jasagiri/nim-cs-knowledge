import std/[unittest, options, algorithm, math]
import std/sequtils
import propcheck
import nimcs/fp/fold

func plus(acc, x: int): int {.raises: [].} = acc + x
func minus(acc, x: int): int {.raises: [].} = acc - x
func cons(x: int; acc: seq[int]): seq[int] {.raises: [].} = @[x] & acc
func snoc(acc: seq[int]; x: int): seq[int] {.raises: [].} = acc & @[x]
func countOne(acc: int; x: int): int {.raises: [].} = acc + 1
func subR(x, acc: int): int {.raises: [].} = x - acc

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-50, 50), 0, 12)

# SPEC: FP-FOLD-01
test "FP-FOLD-01 Given a sequence, when foldLeft with plus from zero, then it is the sum, and an empty input gives init":
  check foldLeft([1, 2, 3], 0, plus) == 6
  check foldLeft(newSeq[int](), 42, plus) == 42
  # std/sequtils is imported unqualified above: its foldl and this module's foldLeft coexist.
  check [1, 2, 3].foldl(a + b) == 6
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    foldLeft(xs, 0, plus) == xs.sum)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FOLD-02
test "FP-FOLD-02 Given two sequences, when folded as one concatenation or in two steps, then the results agree":
  let outcome = check(pair(ints(), ints()), proc(p: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
    foldLeft(p[0] & p[1], 7, minus) == foldLeft(p[1], foldLeft(p[0], 7, minus), minus))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FOLD-03
test "FP-FOLD-03 Given a sequence, when foldRight with cons from empty, then the list is rebuilt, and foldLeft with snoc rebuilds it too":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    foldRight(xs, newSeq[int](), cons) == xs and foldLeft(xs, newSeq[int](), snoc) == xs)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FOLD-04
test "FP-FOLD-04 Given an associative commutative step, when foldLeft and foldRight, then they agree; with minus they differ":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    foldLeft(xs, 0, plus) == foldRight(xs, 0, proc(x, acc: int): int {.noSideEffect, raises: [].} = x + acc))
  checkpoint describe(outcome)
  check outcome.passed
  check foldLeft([10, 3, 2], 0, minus) == -15
  check foldRight([10, 3, 2], 0, subR) == 9

# SPEC: FP-FOLD-05
test "FP-FOLD-05 Given a sequence, when scan, then it starts at init, ends at the foldLeft result, and each step applies f":
  check scan([1, 2, 3], 0, plus) == @[0, 1, 3, 6]
  check scan(newSeq[int](), 5, plus) == @[5]
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let s = scan(xs, 3, plus)
    var stepsOk = s.len == xs.len + 1 and s[0] == 3 and s[^1] == foldLeft(xs, 3, plus)
    for i in 0 ..< xs.len:
      stepsOk = stepsOk and s[i + 1] == s[i] + xs[i]
    stepsOk)
  checkpoint describe(outcome)
  check outcome.passed

func countdownStep(n: int): Option[(int, int)] {.raises: [].} =
  if n <= 0: none((int, int)) else: some((n, n - 1))

func forever(n: int): Option[(int, int)] {.raises: [].} = some((n, n + 1))

# SPEC: FP-FOLD-06
test "FP-FOLD-06 Given a seed, when unfold, then it stops at none, and never exceeds the limit":
  check unfold(3, countdownStep, 100) == @[3, 2, 1]
  check unfold(0, countdownStep, 100).len == 0
  check unfold(0, forever, 4) == @[0, 1, 2, 3]
  check unfold(0, forever, 0).len == 0
  let outcome = check(pair(intIn(-5, 30), intIn(0, 10)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let got = unfold(p[0], countdownStep, p[1])
    got.len == min(max(p[0], 0), p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FOLD-07
test "FP-FOLD-07 Given a sequence, when length, map, filter and reverse are written as folds, then they equal the standard versions":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let lengthOk = foldLeft(xs, 0, countOne) == xs.len
    let mapped = foldRight(xs, newSeq[int](), proc(x: int; acc: seq[int]): seq[int] {.noSideEffect, raises: [].} = @[x * 2] & acc)
    let filtered = foldRight(xs, newSeq[int](), proc(x: int; acc: seq[int]): seq[int] {.noSideEffect, raises: [].} =
      if x > 0: @[x] & acc else: acc)
    let reversed = foldLeft(xs, newSeq[int](), proc(acc: seq[int]; x: int): seq[int] {.noSideEffect, raises: [].} = @[x] & acc)
    lengthOk and mapped == xs.mapIt(it * 2) and filtered == xs.filterIt(it > 0) and reversed == xs.reversed)
  checkpoint describe(outcome)
  check outcome.passed
