import std/unittest
import propcheck
import nimcs/fp/adt

func divMod(a, b: int): (int, int) {.raises: [].} = (a div b, a mod b)

func shapeName(e: Expr): string {.raises: [].} =
  ## One `case` per level: a nested pattern is a nested `case`.
  case e.kind
  of ekNum: "number"
  of ekNeg:
    case e.operand.kind
    of ekNum: "negative literal"
    of ekNeg, ekAdd, ekMul, ekDiv: "negation"
  of ekAdd, ekMul, ekDiv: "binary"

func buildFrom(n: int): Expr {.raises: [].} =
  case abs(n) mod 6
  of 0: num(n)
  of 1: neg(num(n))
  of 2: neg(add(num(n), num(1)))
  of 3: add(num(n), num(2))
  of 4: mul(num(n), neg(num(3)))
  else: divide(num(n), num(2))

# SPEC: FP-ADT-08
test "FP-ADT-08 Given a tuple result, when unpacked in a let, a nested let or a loop, then each name holds the matching component":
  let (q, r) = divMod(17, 5)
  check (q, r) == (3, 2)
  let (a, (b, c)) = (1, (2, 3))
  check a + b * 10 + c * 100 == 321
  var seen: seq[int]
  for (i, x) in @[10, 20, 30].pairs:
    seen.add i + x
  check seen == @[10, 21, 32]
  var left = 1
  var right = 2
  (left, right) = (right, left)
  check (left, right) == (2, 1)
  let outcome = check(pair(intIn(-50, 50), intIn(1, 9)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let (quot, rem) = divMod(p[0], p[1])
    quot * p[1] + rem == p[0])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-ADT-09
test "FP-ADT-09 Given an expression, when a nested case matches its shape, then each shape is answered by exactly one branch":
  check shapeName(num(4)) == "number"
  check shapeName(neg(num(4))) == "negative literal"
  check shapeName(neg(neg(num(4)))) == "negation"
  check shapeName(add(num(1), num(2))) == "binary"
  let outcome = check(intIn(-30, 30), proc(n: int): bool {.raises: [CatchableError].} =
    let e = buildFrom(n)
    let d = shapeName(e)
    case e.kind
    of ekNum: d == "number"
    of ekNeg: d == (if e.operand.kind == ekNum: "negative literal" else: "negation")
    of ekAdd, ekMul, ekDiv: d == "binary")
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-ADT-10
test "FP-ADT-10 Given a case over a variant with a missing branch, when compiled, then it is rejected":
  check compiles(block:
    func covered(e: Expr): int =
      case e.kind
      of ekNum: 1
      of ekNeg: 2
      of ekAdd, ekMul, ekDiv: 3
    covered(num(1)))
  check not compiles(block:
    func missing(e: Expr): int =
      case e.kind
      of ekNum: 1
      of ekNeg: 2
      of ekAdd, ekMul: 3
    missing(num(1)))
