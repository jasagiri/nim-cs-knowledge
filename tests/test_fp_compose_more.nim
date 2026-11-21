import std/[unittest, sequtils, sugar, sets]
import propcheck
import nimcs/fp/compose

func inc1(x: int): int {.raises: [].} = x + 1
func dbl(x: int): int {.raises: [].} = x * 2

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-20, 20), 0, 10)

# SPEC: FP-COMPOSE-07
test "FP-COMPOSE-07 Given a composition built from two function values, when the variable holding one is reassigned, then the composition keeps the function it was built from":
  var f: Fn[int, int] = inc1
  let after = andThen(f, dbl)
  f = dbl
  check f(3) == 6
  check after(3) == 8

# SPEC: FP-COMPOSE-08
test "FP-COMPOSE-08 Given a closure over a var, when the var changes, then the closure sees the new value; a let copy keeps the old one":
  var k = 1
  let live = proc(x: int): int = x + k
  let frozenK = k
  let frozen = proc(x: int): int = x + frozenK
  k = 10
  check live(1) == 11
  check frozen(1) == 2

func times(k: int): Fn[int, int] {.raises: [].} =
  ## The factor is a parameter, so every call has its own frame to capture.
  result = proc(x: int): int {.noSideEffect, raises: [].} = x * k

proc sharedLoopVar(): seq[int] =
  var made: seq[proc(x: int): int]
  for i in 0 ..< 4:
    made.add(proc(x: int): int = x * i)
  made.mapIt(it(10))

proc viaFunction(): seq[int] =
  var made: seq[Fn[int, int]]
  for i in 0 ..< 4:
    made.add(times(i))
  made.mapIt(it(10))

# SPEC: FP-COMPOSE-09
test "FP-COMPOSE-09 Given closures made in a for loop, when called later, then they share the loop variable unless each is built by a function call":
  check sharedLoopVar() == @[30, 30, 30, 30]
  check viaFunction() == @[0, 10, 20, 30]

# SPEC: FP-COMPOSE-10
test "FP-COMPOSE-10 Given a list, when collect filters and maps in one comprehension, then the result equals filter then map, and it can build a set":
  check collect(for x in [1, 2, 3, 4]: (if x mod 2 == 0: x * x)) == @[4, 16]
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let viaCollect = collect(newSeq):
      for x in xs:
        if x mod 2 == 0: dbl(x)
    viaCollect == xs.filter(proc(x: int): bool = x mod 2 == 0).map(dbl))
  checkpoint describe(outcome)
  check outcome.passed
  let squares = collect(initHashSet):
    for x in [1, -1, 2]:
      {x * x}
  check squares == [1, 4].toHashSet

# SPEC: FP-COMPOSE-11
test "FP-COMPOSE-11 Given a function that takes and returns functions, when it is partially applied, then it gives the same results as the two-argument form":
  func addTo(n: int): Fn[int, int] {.raises: [].} =
    result = proc(x: int): int {.noSideEffect, raises: [].} = x + n
  let outcome = check(pair(intIn(-50, 50), intIn(-50, 50)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    addTo(p[0])(p[1]) == p[0] + p[1] and compose(addTo(p[0]), dbl)(p[1]) == p[0] + 2 * p[1])
  checkpoint describe(outcome)
  check outcome.passed
