## Algebraic data types: a closed set of shapes as an object variant (ADR-NCK-0002 S2, S3).
##
## `Expr` is an arithmetic expression tree: a number, a negation, or a sum, product or quotient of
## two sub-expressions. Every routine over it is a `case` on `kind` with one branch per shape and
## no `else`, so adding a shape to `ExprKind` makes the compiler list every routine that must learn
## about it. Nodes are `ref` to immutable data (S3: `ref` only for recursion); nothing here mutates
## a node after construction. `eval` is total: arithmetic that cannot be done (division by zero,
## `int` overflow) is an `EvalError` value, never an exception.

import nimcs/fp/result

type
  ExprKind* = enum
    ekNum, ekNeg, ekAdd, ekMul, ekDiv

  Expr* = ref object
    case kind*: ExprKind
    of ekNum:
      value*: int
    of ekNeg:
      operand*: Expr
    of ekAdd, ekMul, ekDiv:
      left*, right*: Expr

  EvalError* = enum
    divideByZero, overflow

func num*(n: int): Expr {.raises: [].} = Expr(kind: ekNum, value: n)
func neg*(e: Expr): Expr {.raises: [].} = Expr(kind: ekNeg, operand: e)
func add*(a, b: Expr): Expr {.raises: [].} = Expr(kind: ekAdd, left: a, right: b)
func mul*(a, b: Expr): Expr {.raises: [].} = Expr(kind: ekMul, left: a, right: b)
func divide*(a, b: Expr): Expr {.raises: [].} = Expr(kind: ekDiv, left: a, right: b)

func `==`*(a, b: Expr): bool {.raises: [].} =
  ## Structural equality (the default for `ref` would compare addresses).
  case a.kind
  of ekNum: b.kind == ekNum and a.value == b.value
  of ekNeg: b.kind == ekNeg and a.operand == b.operand
  of ekAdd: b.kind == ekAdd and a.left == b.left and a.right == b.right
  of ekMul: b.kind == ekMul and a.left == b.left and a.right == b.right
  of ekDiv: b.kind == ekDiv and a.left == b.left and a.right == b.right

func addChecked(a, b: int): Result[int, EvalError] {.raises: [].} =
  if (b > 0 and a > high(int) - b) or (b < 0 and a < low(int) - b): err(int, overflow)
  else: ok(a + b, EvalError)

func mulChecked(a, b: int): Result[int, EvalError] {.raises: [].} =
  if a == 0 or b == 0: return ok(0, EvalError)
  let tooBig =
    if a > 0:
      (if b > 0: a > high(int) div b else: b < low(int) div a)
    else:
      (if b > 0: a < low(int) div b else: a < high(int) div b)
  if tooBig: err(int, overflow) else: ok(a * b, EvalError)

func divChecked(a, b: int): Result[int, EvalError] {.raises: [].} =
  if b == 0: err(int, divideByZero)
  elif a == low(int) and b == -1: err(int, overflow)
  else: ok(a div b, EvalError)

func evalWith(e: Expr; op: proc(a, b: int): Result[int, EvalError] {.noSideEffect, raises: [].}):
    Result[int, EvalError] {.raises: [].}

func eval*(e: Expr): Result[int, EvalError] {.raises: [].} =
  ## The value of `e`, or the first error met (left operand before right).
  case e.kind
  of ekNum:
    ok(e.value, EvalError)
  of ekNeg:
    let inner = eval(e.operand)
    if inner.isErr: inner
    elif inner.value == low(int): err(int, overflow)
    else: ok(-inner.value, EvalError)
  of ekAdd: evalWith(e, addChecked)
  of ekMul: evalWith(e, mulChecked)
  of ekDiv: evalWith(e, divChecked)

func evalWith(e: Expr; op: proc(a, b: int): Result[int, EvalError] {.noSideEffect, raises: [].}):
    Result[int, EvalError] {.raises: [].} =
  ## Evaluates both operands of a binary node (left first) and combines them with `op`.
  ## Precondition: `e.kind` is `ekAdd`, `ekMul` or `ekDiv` (only `eval` calls this).
  let l = eval(e.left)
  if l.isErr: return l
  let r = eval(e.right)
  if r.isErr: return r
  op(l.value, r.value)

func size*(e: Expr): int {.raises: [].} =
  ## Number of nodes.
  case e.kind
  of ekNum: 1
  of ekNeg: 1 + size(e.operand)
  of ekAdd, ekMul, ekDiv: 1 + size(e.left) + size(e.right)

func show*(e: Expr): string {.raises: [].} =
  ## Fully parenthesised text, e.g. `(1 + (2 * 3))`; a negation is `neg(...)`, so that
  ## `neg(num(1))` and `num(-1)` print differently (`show` is injective on trees).
  case e.kind
  of ekNum: $e.value
  of ekNeg: "neg(" & show(e.operand) & ")"
  of ekAdd: "(" & show(e.left) & " + " & show(e.right) & ")"
  of ekMul: "(" & show(e.left) & " * " & show(e.right) & ")"
  of ekDiv: "(" & show(e.left) & " / " & show(e.right) & ")"

func `$`*(e: Expr): string {.raises: [].} = show(e)

func isNum(e: Expr; n: int): bool {.raises: [].} =
  e.kind == ekNum and e.value == n

func simplify*(e: Expr): Expr {.raises: [].} =
  ## Rewrites bottom-up: constant folding when it cannot overflow, `0 + x`, `x + 0`, `1 * x`,
  ## `x * 1` and `x / 1` disappear. `--x` is deliberately kept unless `x` is a number: `-x`
  ## overflows for the smallest `int`, so dropping a double negation could turn an error into a value. `eval(simplify(e)) == eval(e)`, and simplifying twice
  ## gives the same tree as simplifying once.
  case e.kind
  of ekNum:
    e
  of ekNeg:
    let x = simplify(e.operand)
    if x.kind == ekNum and x.value != low(int): num(-x.value)
    else: neg(x)
  of ekAdd:
    let a = simplify(e.left)
    let b = simplify(e.right)
    if a.isNum(0): b
    elif b.isNum(0): a
    elif a.kind == ekNum and b.kind == ekNum and addChecked(a.value, b.value).isOk:
      num(a.value + b.value)
    else: add(a, b)
  of ekMul:
    let a = simplify(e.left)
    let b = simplify(e.right)
    if a.isNum(1): b
    elif b.isNum(1): a
    elif a.kind == ekNum and b.kind == ekNum and mulChecked(a.value, b.value).isOk:
      num(a.value * b.value)
    else: mul(a, b)
  of ekDiv:
    let a = simplify(e.left)
    let b = simplify(e.right)
    if b.isNum(1): a
    else: divide(a, b)
