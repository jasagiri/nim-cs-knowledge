import std/[unittest]
import propcheck
import nimcs/fp/equational_reasoning

func isNeg(x: int): bool {.raises: [].} = x < 0
func square(x: int): int {.raises: [].} = x * x

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-30, 30), 0, 12)

# SPEC: FP-EQUATIONALREASONING-01
test "FP-EQUATIONALREASONING-01 Given a list of integers, when the staged pipeline is replaced by the fused loop, then the totals are equal":
  check stagedTotal([1, 2, 3, 4]) == 5 + 9
  check fusedTotal(newSeq[int]()) == 0
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    stagedTotal(xs) == fusedTotal(xs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-EQUATIONALREASONING-02
test "FP-EQUATIONALREASONING-02 Given any text, when the repeated strip is removed, then the normalised text is equal":
  check normalizeStaged("  Hello \t") == "hello"
  let outcome = check(stringOf(" \t\nAbC", 0, 10), proc(s: string): bool {.raises: [CatchableError].} =
    normalizeStaged(s) == normalizeOnce(s) and normalizeOnce(normalizeOnce(s)) == normalizeOnce(s))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-EQUATIONALREASONING-03
test "FP-EQUATIONALREASONING-03 Given a bound n, when the loop is replaced by the closed form, then the sums are equal":
  check rangeSumLoop(0) == 0 and rangeSumFormula(0) == 0
  check rangeSumLoop(100_000) == rangeSumFormula(100_000)
  let outcome = check(intIn(0, 2000), proc(n: int): bool {.raises: [CatchableError].} =
    rangeSumLoop(n) == rangeSumFormula(n))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-EQUATIONALREASONING-04
test "FP-EQUATIONALREASONING-04 Given a list and a chunk size, when counting chunk by chunk, then the count equals the direct count and counting splits over concatenation":
  check countIf([1, -2, 3, -4], isNeg) == 2
  let outcome = check(pair(ints(), pair(ints(), intIn(1, 5))),
    proc(t: (seq[int], (seq[int], int))): bool {.raises: [CatchableError].} =
      let (a, (b, chunk)) = t
      countIfChunked(a, isNeg, chunk) == countIf(a, isNeg) and
        countIf(a & b, isNeg) == countIf(a, isNeg) + countIf(b, isNeg))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-EQUATIONALREASONING-05
test "FP-EQUATIONALREASONING-05 Given a pure function, when a call is bound to a name or repeated, then both forms agree; given an effect, then they differ":
  let outcome = check(intIn(-30, 30), proc(x: int): bool {.raises: [CatchableError].} =
    let y = square(x)
    y + y == square(x) + square(x) and y + y == 2 * square(x))
  checkpoint describe(outcome)
  check outcome.passed
  var calls = 0
  let counting = proc(): int =
    inc calls
    calls
  # Replacing `a` by its definition is not valid here: each call changes the answer.
  let once = counting()
  let twiceBound = once + once
  let twiceInlined = counting() + counting()
  check twiceBound == 2
  check twiceInlined != twiceBound

# SPEC: FP-EQUATIONALREASONING-06
test "FP-EQUATIONALREASONING-06 Given floats, when a sum is reassociated, then the result can differ":
  let xs = @[0.1, 0.2, 0.3]
  check sumLeft(xs) != sumRight(xs)
  check sumLeft(@[1.0, 2.0, 4.0]) == sumRight(@[1.0, 2.0, 4.0])
