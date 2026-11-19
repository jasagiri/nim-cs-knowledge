import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/interpreter

func v(name: string): Expr {.raises: [].} =
  ## Test helper: names used below are valid identifiers, so the constructor succeeds.
  variable(name).value

# A random tree is read from a reverse-Polish program of small integer codes:
# 0..6 push a number (c - 3) * 500_000, 7..8 push a variable (x bound, z unbound), 9 negates the top,
# 13..18 push an out-of-range or boundary literal (Limit+1, -Limit-1, 2*Limit, Limit, low(int), high(int)),
# 10..12 pop two and push add / mul / div. An underflowing operator pushes 0 instead of failing.
func fromCodes(codes: seq[int]): Expr {.raises: [].} =
  var stack: seq[Expr]
  for c in codes:
    case c
    of 0 .. 6: stack.add num((c - 3) * 500_000)
    of 13: stack.add num(Limit + 1)
    of 14: stack.add num(-Limit - 1)
    of 15: stack.add num(2 * Limit)
    of 16: stack.add num(Limit)
    of 17: stack.add num(low(int))
    of 18: stack.add num(high(int))
    of 19: stack.add v("x1")
    of 20: stack.add v("_")
    of 7: stack.add v("x")
    of 8: stack.add v("z")
    of 9:
      if stack.len > 0: stack[^1] = neg(stack[^1]) else: stack.add num(0)
    else:
      if stack.len < 2:
        stack.add num(0)
      else:
        let b = stack.pop
        let a = stack.pop
        stack.add (case c
          of 10: add(a, b)
          of 11: mul(a, b)
          else: divide(a, b))
  result = num(0)
  for e in stack: result = add(result, e)

func env(): seq[Binding] {.raises: [].} = @[("x", 7), ("y", -3)]

func codesGen(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(0, 20), 0, 24)

# SPEC: GOF-INTERP-01
test "GOF-INTERP-01 Given constants and operators, when evaluated, then the result is the arithmetic value":
  check eval(add(num(2), mul(num(3), num(4))), env()).value == 14
  check eval(neg(divide(num(9), num(2))), env()).value == -4
  check eval(add(v("x"), v("y")), env()).value == 4

# SPEC: GOF-INTERP-02
test "GOF-INTERP-02 Given failing expressions, when evaluated, then the error names the first failure in reading order":
  check eval(v("z"), env()).error == evUnbound
  check eval(divide(num(1), num(0)), env()).error == evDivByZero
  check eval(add(v("z"), divide(num(1), num(0))), env()).error == evUnbound
  check eval(add(divide(num(1), num(0)), v("z")), env()).error == evDivByZero
  check eval(mul(num(Limit), num(2)), env()).error == evLimit
  check eval(num(Limit + 1), env()).error == evLimit

# SPEC: GOF-INTERP-03
test "GOF-INTERP-03 Given any expression, when constant-folded, then it evaluates to the same result or error":
  let outcome = check(codesGen(), proc(cs: seq[int]): bool {.raises: [CatchableError].} =
    let e = fromCodes(cs)
    eval(fold(e), env()) == eval(e, env()))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-INTERP-04
test "GOF-INTERP-04 Given any expression, when folded twice, then the second fold changes nothing":
  let outcome = check(codesGen(), proc(cs: seq[int]): bool {.raises: [CatchableError].} =
    let f = fold(fromCodes(cs))
    same(fold(f), f))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-INTERP-05
test "GOF-INTERP-05 Given any expression, when folded, then it is no larger than the original":
  let outcome = check(codesGen(), proc(cs: seq[int]): bool {.raises: [CatchableError].} =
    let e = fromCodes(cs)
    size(fold(e)) <= size(e))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-INTERP-06
test "GOF-INTERP-06 Given an expression without variables, when folded, then a successful evaluation leaves a single number":
  let outcome = check(codesGen(), proc(cs: seq[int]): bool {.raises: [CatchableError].} =
    var closed: seq[int]
    for c in cs:
      if c != 7 and c != 8: closed.add c
    let e = fromCodes(closed)
    let r = eval(e, env())
    if r.isErr: return true
    let f = fold(e)
    f.kind == ekNum and f.num == r.value)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-INTERP-07
test "GOF-INTERP-07 Given a failing constant subtree, when folded, then the subtree is kept so the error survives":
  let e = add(num(1), divide(num(4), num(0)))
  check same(fold(e), e)
  check eval(fold(e), env()).error == evDivByZero

# SPEC: GOF-INTERP-08
test "GOF-INTERP-08 Given an expression, when shown, then the text is fully parenthesised and unique per shape":
  check show(add(num(1), mul(num(2), v("x")))) == "(1 + (2 * x))"
  check show(mul(add(num(1), num(2)), v("x"))) == "((1 + 2) * x)"
  check show(neg(num(3))) == "(-3)"

# SPEC: GOF-INTERP-03
test "GOF-INTERP-03 Given literals outside the limit, when folded, then the result is still the error eval gives":
  let cases = [add(num(Limit + 1), num(-1)), mul(num(2 * Limit), num(0)),
               add(num(-Limit - 1), num(1)), divide(num(2 * Limit), num(2)),
               neg(num(Limit + 1))]
  for e in cases:
    check eval(e, env()).error == evLimit
    check eval(fold(e), env()) == eval(e, env())

# SPEC: GOF-INTERP-08
test "GOF-INTERP-08 Given any two expressions with identifier names, when shown, then the texts are equal exactly when the trees are":
  let outcome = check(pair(codesGen(), codesGen()), proc(p: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
    let a = fromCodes(p[0])
    let b = fromCodes(p[1])
    (show(a) == show(b)) == same(a, b) and show(a) == show(fromCodes(p[0])))
  checkpoint describe(outcome)
  check outcome.passed
  check show(neg(num(3))) != show(num(-3))

func isIdentifierRef(s: string): bool {.raises: [].} =
  ## Independent statement of the rule: letter or underscore first, then letters, digits, underscores.
  if s.len == 0: return false
  for i, c in s:
    let letter = c in {'a' .. 'z', 'A' .. 'Z', '_'}
    if not (letter or (i > 0 and c in {'0' .. '9'})): return false
  true

# SPEC: GOF-INTERP-09
test "GOF-INTERP-09 Given any string, when used as a variable name, then it is accepted exactly when it is an identifier":
  let outcome = check(stringOf("ab_Z09 +()-*/\"", 0, 5), proc(name: string): bool {.raises: [CatchableError].} =
    let r = variable(name)
    r.isOk == isIdentifierRef(name) and (r.isErr or (r.value.kind == ekVar and r.value.name == name)))
  checkpoint describe(outcome)
  check outcome.passed
  check variable("").error == veBadName
  check variable("a b").error == veBadName
  check variable("1x").error == veBadName
  check variable("_t1").isOk

# SPEC: GOF-INTERP-09
test "GOF-INTERP-09 Given code outside the module, when it builds a variable node by naming the fields, then it does not compile":
  check not compiles(Expr(kind: ekVar, name: "a + b"))
  check not compiles(Expr(kind: ekNum, num: 3))
  check not compiles(block:
    let e = num(1)
    e.num = 5)
  check compiles(variable("ok"))
  check num(7).num == 7
  check v("q").name == "q"
  check add(num(1), num(2)).left.num == 1
  check neg(num(4)).operand.num == 4
