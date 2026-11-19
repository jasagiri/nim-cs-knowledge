## Interpreter: a grammar is a data type and the interpreter is a fold over it.
##
## The OO pattern gives each grammar rule a class with an `interpret(context)` method. In Nim the
## rules are the cases of one object variant (`Expr`), and each interpretation (evaluate, print,
## simplify) is one `func` with an exhaustive `case`. Adding an interpretation never touches the
## type; variable names are validated by `variable`, so `show` is injective. Adding a rule makes every `case` fail to compile until it is handled. Use it for small
## languages (formulas, filters, rules). For a full language reach for a parser generator and keep
## this shape for the tree after parsing.
##
## Arithmetic here is checked: every value must stay within `+-Limit`, so no operation can
## overflow `int`. Division by zero, an unbound variable and a limit breach are `EvalError`s.

import std/options
import nimcs/fp/result

const Limit* = 1_000_000_000

type
  ExprKind* = enum
    ekNum, ekVar, ekNeg, ekAdd, ekMul, ekDiv

  Expr* = ref object
    ## Immutable: the fields are private, so a node can only be made by the constructors below
    ## (`num`, `variable`, `neg`, `add`, `mul`, `divide`) and read through the accessors. That is
    ## what keeps variable names valid. Reading an accessor of the wrong kind (`num` of an `ekAdd`)
    ## is a precondition violation: test `kind` first, as the `case` in `eval` does.
    case kind: ExprKind
    of ekNum:
      num: int
    of ekVar:
      name: string
    of ekNeg:
      operand: Expr
    of ekAdd, ekMul, ekDiv:
      left, right: Expr

  Binding* = (string, int)

  EvalError* = enum
    evUnbound, evDivByZero, evLimit

  VarError* = enum
    veBadName   ## a variable name must be an identifier

func kind*(e: Expr): ExprKind {.raises: [].} = e.kind
func num*(e: Expr): int {.raises: [].} = e.num
func name*(e: Expr): string {.raises: [].} = e.name
func operand*(e: Expr): Expr {.raises: [].} = e.operand
func left*(e: Expr): Expr {.raises: [].} = e.left
func right*(e: Expr): Expr {.raises: [].} = e.right

func num*(n: int): Expr {.raises: [].} = Expr(kind: ekNum, num: n)
func isIdentifier(s: string): bool {.raises: [].} =
  if s.len == 0: return false
  for i, c in s:
    let letter = c in {'a' .. 'z', 'A' .. 'Z', '_'}
    if not (letter or (i > 0 and c in {'0' .. '9'})): return false
  true

func variable*(name: string): Result[Expr, VarError] {.raises: [].} =
  ## Smart constructor. A name is a letter or underscore followed by letters, digits and
  ## underscores; anything else (spaces, parentheses, operators, empty) would make `show` ambiguous
  ## and is refused. Build `Expr` nodes through the constructors, not by naming `ekVar` directly.
  if isIdentifier(name): ok(Expr(kind: ekVar, name: name), VarError)
  else: err(Expr, veBadName)
func neg*(e: Expr): Expr {.raises: [].} = Expr(kind: ekNeg, operand: e)
func add*(a, b: Expr): Expr {.raises: [].} = Expr(kind: ekAdd, left: a, right: b)
func mul*(a, b: Expr): Expr {.raises: [].} = Expr(kind: ekMul, left: a, right: b)
func divide*(a, b: Expr): Expr {.raises: [].} = Expr(kind: ekDiv, left: a, right: b)

func same*(a, b: Expr): bool {.raises: [].} =
  ## Structural equality.
  if a.kind != b.kind: return false
  case a.kind
  of ekNum: a.num == b.num
  of ekVar: a.name == b.name
  of ekNeg: same(a.operand, b.operand)
  of ekAdd, ekMul, ekDiv: same(a.left, b.left) and same(a.right, b.right)

func show*(e: Expr): string {.raises: [].} =
  ## One interpretation: a fully parenthesised rendering.
  case e.kind
  of ekNum: $e.num
  of ekVar: e.name
  of ekNeg: "(-" & show(e.operand) & ")"
  of ekAdd: "(" & show(e.left) & " + " & show(e.right) & ")"
  of ekMul: "(" & show(e.left) & " * " & show(e.right) & ")"
  of ekDiv: "(" & show(e.left) & " / " & show(e.right) & ")"

func size*(e: Expr): int {.raises: [].} =
  ## Number of nodes.
  case e.kind
  of ekNum, ekVar: 1
  of ekNeg: 1 + size(e.operand)
  of ekAdd, ekMul, ekDiv: 1 + size(e.left) + size(e.right)

func checked(n: int): Result[int, EvalError] {.raises: [].} =
  if n > Limit or n < -Limit: err(int, evLimit) else: ok(n, EvalError)

func lookup(env: openArray[Binding]; name: string): Option[int] {.raises: [].} =
  for b in env:
    if b[0] == name: return some(b[1])
  none(int)

func combine(kind: ExprKind; a, b: int): Result[int, EvalError] {.raises: [].} =
  ## The meaning of one binary node. Both operands are range-checked here, so `eval` and `fold`
  ## (which may hand over raw literals) agree on every input, including out-of-range literals.
  let ca = checked(a)
  if ca.isErr: return ca
  let cb = checked(b)
  if cb.isErr: return cb
  case kind
  of ekAdd: checked(a + b)
  of ekMul: checked(a * b)
  of ekDiv:
    if b == 0: err(int, evDivByZero) else: checked(a div b)
  of ekNum, ekVar, ekNeg: err(int, evLimit)   # not binary; unreachable through `eval`/`fold`

func eval*(e: Expr; env: openArray[Binding]): Result[int, EvalError] {.raises: [].} =
  ## Left operand first, so the first error in reading order is the one reported.
  case e.kind
  of ekNum: checked(e.num)
  of ekVar:
    let v = lookup(env, e.name)
    if v.isNone: err(int, evUnbound) else: checked(v.get)
  of ekNeg:
    let r = eval(e.operand, env)
    if r.isErr: r else: checked(-r.value)
  of ekAdd, ekMul, ekDiv:
    let l = eval(e.left, env)
    if l.isErr: return l
    let r = eval(e.right, env)
    if r.isErr: return r
    combine(e.kind, l.value, r.value)

func foldBinary(kind: ExprKind; l, r: Expr;
                rebuild: proc(a, b: Expr): Expr {.noSideEffect, raises: [].}): Expr {.raises: [].} =
  if l.kind == ekNum and r.kind == ekNum:
    let v = combine(kind, l.num, r.num)
    if v.isOk: return num(v.value)
  rebuild(l, r)

func fold*(e: Expr): Expr {.raises: [].} =
  ## Constant folding: replaces every subtree made only of numbers that evaluates successfully.
  ## A subtree that would fail (division by zero, limit) is kept, so `eval` still reports it.
  case e.kind
  of ekNum, ekVar: e
  of ekNeg:
    let o = fold(e.operand)
    if o.kind == ekNum:
      let inRange = checked(o.num)   # -low(int) would overflow, so check before negating
      if inRange.isOk:
        let r = checked(-o.num)
        if r.isOk: return num(r.value)
    neg(o)
  of ekAdd: foldBinary(ekAdd, fold(e.left), fold(e.right), add)
  of ekMul: foldBinary(ekMul, fold(e.left), fold(e.right), mul)
  of ekDiv: foldBinary(ekDiv, fold(e.left), fold(e.right), divide)
