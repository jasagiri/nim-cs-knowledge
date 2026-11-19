import std/unittest
import propcheck
import nimcs/fp/[result, adt]

# Builds an expression from a list of codes with a stack: 0..9 push a number, anything else pops
# two operands (or one, for code mod 4 == 0) and pushes a node. The leftover stack is summed.
func build(codes: seq[int]): Expr {.raises: [].} =
  var stack: seq[Expr]
  for c in codes:
    if c < 10:
      # Codes 0..2 are the extreme values, so overflow paths are reached.
      stack.add num(case c
        of 0: low(int)
        of 1: high(int)
        of 2: low(int) + 1
        else: c - 3)
    elif c mod 4 == 0 and stack.len >= 1:
      stack[^1] = neg(stack[^1])
    elif stack.len >= 2:
      let b = stack.pop
      let a = stack.pop
      stack.add(case c mod 4
        of 1: add(a, b)
        of 2: mul(a, b)
        else: divide(a, b))
    else:
      stack.add num(c)
  result = num(0)
  for e in stack:
    result = add(result, e)

func exprs(): Gen[Expr] {.raises: [ValueError].} =
  seqOf(intIn(0, 40), 0, 14).map(build)

# SPEC: FP-ADT-01
test "FP-ADT-01 Given constructors, when eval, then each shape gives its arithmetic value":
  check eval(num(7)) == ok(7, EvalError)
  check eval(neg(num(7))) == ok(-7, EvalError)
  check eval(add(num(2), mul(num(3), num(4)))) == ok(14, EvalError)
  check eval(divide(num(7), num(2))) == ok(3, EvalError)

# SPEC: FP-ADT-02
test "FP-ADT-02 Given a failing operation, when eval, then the error is a value and the left error wins":
  check eval(divide(num(1), num(0))) == err(int, divideByZero)
  check eval(add(num(high(int)), num(1))) == err(int, overflow)
  check eval(mul(num(high(int)), num(2))) == err(int, overflow)
  check eval(neg(num(low(int)))) == err(int, overflow)
  check eval(divide(num(low(int)), num(-1))) == err(int, overflow)
  check eval(add(divide(num(1), num(0)), add(num(high(int)), num(1)))) == err(int, divideByZero)
  check eval(add(num(1), divide(num(1), num(0)))) == err(int, divideByZero)

# SPEC: FP-ADT-03
test "FP-ADT-03 Given any expression, when simplified, then eval is unchanged":
  let outcome = check(exprs(), proc(e: Expr): bool {.raises: [CatchableError].} =
    eval(simplify(e)) == eval(e))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-ADT-04
test "FP-ADT-04 Given any expression, when simplified twice, then it equals simplifying once":
  let outcome = check(exprs(), proc(e: Expr): bool {.raises: [CatchableError].} =
    simplify(simplify(e)) == simplify(e))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-ADT-04
test "FP-ADT-04 Given known redexes, when simplified, then they disappear":
  check simplify(add(num(0), num(5))) == num(5)
  check simplify(mul(num(1), add(num(2), num(3)))) == num(5)
  check simplify(divide(num(4), num(0))) == divide(num(4), num(0))
  check simplify(neg(neg(num(3)))) == num(3)
  check simplify(divide(add(num(2), num(0)), num(1))) == num(2)

# SPEC: FP-ADT-05
test "FP-ADT-05 Given any expression, when simplified, then it is never larger":
  let outcome = check(exprs(), proc(e: Expr): bool {.raises: [CatchableError].} =
    size(simplify(e)) <= size(e))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-ADT-03
test "FP-ADT-03 Given a double negation of the smallest int, when simplified, then the overflow is kept":
  let e = neg(neg(num(low(int))))
  check eval(e) == err(int, overflow)
  check eval(simplify(e)) == eval(e)
  let f = neg(neg(add(num(low(int) + 1), num(-1))))
  check eval(simplify(f)) == eval(f)

# SPEC: FP-ADT-06
test "FP-ADT-06 Given two expressions, when shown, then the texts are equal exactly when the trees are":
  let outcome = check(pair(exprs(), exprs()), proc(p: (Expr, Expr)): bool {.raises: [CatchableError].} =
    (show(p[0]) == show(p[1])) == (p[0] == p[1]))
  checkpoint describe(outcome)
  check outcome.passed
  check show(neg(num(1))) != show(num(-1))

# SPEC: FP-ADT-06
test "FP-ADT-06 Given an expression, when shown, then the text is fully parenthesised":
  check show(add(num(1), mul(num(2), num(3)))) == "(1 + (2 * 3))"
  check show(neg(divide(num(8), num(2)))) == "neg((8 / 2))"
  check size(add(num(1), mul(num(2), num(3)))) == 5

# SPEC: FP-ADT-07
test "FP-ADT-07 Given two trees with equal shape and numbers, when compared, then they are equal though not the same node":
  let a = add(num(1), num(2))
  let b = add(num(1), num(2))
  check a == b
  check not (a == add(num(2), num(1)))
  check not (a == mul(num(1), num(2)))
  check not (num(1) == neg(num(1)))
