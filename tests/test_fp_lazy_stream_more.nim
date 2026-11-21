import std/unittest
import nimcs/fp/lazy_stream

func guardedNext(x: int): int {.raises: [].} =
  ## Fails loudly if it is ever asked for the element after 3: the proof that it was evaluated.
  doAssert x < 3, "next was applied to " & $x
  x + 1

func succ1(x: int): int {.raises: [].} = x + 1

func isThreeGuarded(x: int): bool {.raises: [].} =
  doAssert x < 4, "predicate was applied to " & $x
  x == 3

func smallGuarded(x: int): bool {.raises: [].} =
  doAssert x < 3, "predicate was applied to " & $x
  true

# SPEC: FP-LAZYSTREAM-09
test "FP-LAZYSTREAM-09 Given a stream whose step fails beyond element 3, when only a pipeline is built, then nothing is evaluated":
  let built = iterate(0, guardedNext).map(succ1).filter(smallGuarded).take(100)
  check built.toSeq(0).len == 0
  let untouched = iterate(0, guardedNext)
  check untouched.toSeq(1) == @[0]

# SPEC: FP-LAZYSTREAM-10
test "FP-LAZYSTREAM-10 Given the same stream, when walked for more elements, then the step runs exactly as often as elements are pulled":
  let s = iterate(0, guardedNext)
  check s.toSeq(4) == @[0, 1, 2, 3]
  expect AssertionDefect:
    check s.toSeq(5).len == 5

# SPEC: FP-LAZYSTREAM-11
test "FP-LAZYSTREAM-11 Given take(n), when the stream is walked past n, then the source is not pulled beyond the n-th element":
  check iterate(0, guardedNext).take(4).toSeq(100) == @[0, 1, 2, 3]
  expect AssertionDefect:
    check iterate(0, guardedNext).take(5).toSeq(100).len == 5

# SPEC: FP-LAZYSTREAM-12
test "FP-LAZYSTREAM-12 Given filter, when the first match is taken, then the predicate has run on the skipped elements and the match but on nothing after it":
  check iterate(0, succ1).filter(isThreeGuarded).take(1).toSeq(100) == @[3]
  expect AssertionDefect:
    check iterate(0, succ1).filter(isThreeGuarded).take(2).toSeq(100).len == 2
