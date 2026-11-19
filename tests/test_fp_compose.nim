import std/[unittest, sequtils]
import propcheck
import nimcs/fp/compose

func inc1(x: int): int {.raises: [].} = x + 1
func dbl(x: int): int {.raises: [].} = x * 2
func neg(x: int): int {.raises: [].} = -x
func toText(x: int): string {.raises: [].} = $x
func textLen(s: string): int {.raises: [].} = s.len

# SPEC: FP-COMPOSE-01
test "FP-COMPOSE-01 Given f and g, when composed, then compose(f, g)(x) is f(g(x)) and andThen runs in reading order":
  check compose(inc1, dbl)(5) == 11
  check andThen(inc1, dbl)(5) == 12
  check compose(textLen, toText)(12345) == 5
  check andThen(toText, textLen)(12345) == 5

# SPEC: FP-COMPOSE-02
test "FP-COMPOSE-02 Given three functions, when grouped either way, then composition is associative":
  let outcome = check(intIn(-100, 100), proc(x: int): bool {.raises: [CatchableError].} =
    compose(compose(inc1, dbl), neg)(x) == compose(inc1, compose(dbl, neg))(x))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-COMPOSE-03
test "FP-COMPOSE-03 Given f, when composed with identity on either side, then f is unchanged":
  let outcome = check(intIn(-100, 100), proc(x: int): bool {.raises: [CatchableError].} =
    compose(dbl, identity[int])(x) == dbl(x) and compose(identity[int], dbl)(x) == dbl(x))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-COMPOSE-04
test "FP-COMPOSE-04 Given f and g, when andThen is compared to compose with swapped arguments, then they are the same function":
  let outcome = check(intIn(-100, 100), proc(x: int): bool {.raises: [CatchableError].} =
    andThen(inc1, dbl)(x) == compose(dbl, inc1)(x))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-COMPOSE-05
test "FP-COMPOSE-05 Given a list of steps, when composeAll, then they run first to last and none is identity":
  let steps = @[Fn[int, int](inc1), Fn[int, int](dbl), Fn[int, int](neg)]
  check composeAll(steps)(3) == -8
  check composeAll(newSeq[Fn[int, int]]())(9) == 9
  let outcome = check(intIn(-100, 100), proc(x: int): bool {.raises: [CatchableError].} =
    composeAll(steps)(x) == neg(dbl(inc1(x))))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-COMPOSE-06
test "FP-COMPOSE-06 Given a sequence, when map is applied twice or once with the composition, then the results are equal (map fusion)":
  let outcome = check(seqOf(intIn(-100, 100), 0, 12), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    xs.map(dbl).map(inc1) == xs.map(compose(inc1, dbl)))
  checkpoint describe(outcome)
  check outcome.passed
