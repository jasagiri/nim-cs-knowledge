## Tagless final: write the program once against an interface, choose the meaning by choosing a type.
##
## A program such as `dotProduct` is a generic function over a type `R` that satisfies `ExprSym`:
## it can make a literal and combine two values. It never says what `R` is. Instantiate it with
## `Eval` and you get the number, with `Show` the text, with `Size` a node count, with `Ast` a
## data tree. Compared with `free_interpreter` the program is not data you can inspect or
## rewrite, but there is no interpreter loop and no instruction type: adding an interpreter means
## adding a type and four small funcs, and adding an operation means adding a func to the concept
## and to each interpreter. Use it when the set of operations is stable and the set of
## interpretations grows.

type
  Eval* = distinct int     ## interpretation: the value
  Show* = distinct string  ## interpretation: fully parenthesised text
  Size* = distinct int     ## interpretation: number of nodes

  AstKind = enum
    akLit, akAdd, akMul, akNeg

  AstNode = object
    case kind: AstKind
    of akLit: n: int
    of akAdd, akMul:
      left, right: Ast
    of akNeg: inner: Ast

  Ast* = ref AstNode  ## interpretation: the program reified as an immutable tree

  ExprSym* = concept
    ## The interface a program is written against.
    proc lit(t: typedesc[Self]; n: int): Self
    proc add(a, b: Self): Self
    proc mul(a, b: Self): Self
    proc neg(a: Self): Self

# ── Eval ───────────────────────────────────────────────────────────────────

func lit*(t: typedesc[Eval]; n: int): Eval {.raises: [].} = Eval(n)
func add*(a, b: Eval): Eval {.raises: [].} = Eval(int(a) + int(b))
func mul*(a, b: Eval): Eval {.raises: [].} = Eval(int(a) * int(b))
func neg*(a: Eval): Eval {.raises: [].} = Eval(-int(a))
func value*(e: Eval): int {.raises: [].} = int(e)

# ── Show ───────────────────────────────────────────────────────────────────

func lit*(t: typedesc[Show]; n: int): Show {.raises: [].} = Show($n)
func add*(a, b: Show): Show {.raises: [].} = Show("(" & string(a) & "+" & string(b) & ")")
func mul*(a, b: Show): Show {.raises: [].} = Show("(" & string(a) & "*" & string(b) & ")")
func neg*(a: Show): Show {.raises: [].} = Show("-(" & string(a) & ")")
func text*(s: Show): string {.raises: [].} = string(s)

# ── Size ───────────────────────────────────────────────────────────────────

func lit*(t: typedesc[Size]; n: int): Size {.raises: [].} = Size(1)
func add*(a, b: Size): Size {.raises: [].} = Size(int(a) + int(b) + 1)
func mul*(a, b: Size): Size {.raises: [].} = Size(int(a) + int(b) + 1)
func neg*(a: Size): Size {.raises: [].} = Size(int(a) + 1)
func nodes*(s: Size): int {.raises: [].} = int(s)

# ── Ast (the initial encoding, for comparison) ─────────────────────────────

func lit*(t: typedesc[Ast]; n: int): Ast {.raises: [].} = Ast(kind: akLit, n: n)
func add*(a, b: Ast): Ast {.raises: [].} = Ast(kind: akAdd, left: a, right: b)
func mul*(a, b: Ast): Ast {.raises: [].} = Ast(kind: akMul, left: a, right: b)
func neg*(a: Ast): Ast {.raises: [].} = Ast(kind: akNeg, inner: a)

func evalAst*(a: Ast): int {.raises: [].} =
  ## Evaluates a reified tree; equals interpreting the program under `Eval`.
  case a.kind
  of akLit: a.n
  of akAdd: evalAst(a.left) + evalAst(a.right)
  of akMul: evalAst(a.left) * evalAst(a.right)
  of akNeg: -evalAst(a.inner)

func sizeAst*(a: Ast): int {.raises: [].} =
  case a.kind
  of akLit: 1
  of akAdd, akMul: sizeAst(a.left) + sizeAst(a.right) + 1
  of akNeg: sizeAst(a.inner) + 1

func printAst*(a: Ast): string {.raises: [].} =
  case a.kind
  of akLit: $a.n
  of akAdd: "(" & printAst(a.left) & "+" & printAst(a.right) & ")"
  of akMul: "(" & printAst(a.left) & "*" & printAst(a.right) & ")"
  of akNeg: "-(" & printAst(a.inner) & ")"

# ── programs: written once, for every interpretation ───────────────────────

func dotProduct*[R: ExprSym](pairs: openArray[(int, int)]): R {.raises: [].} =
  ## 0 + a1*b1 + a2*b2 + ..., left to right.
  result = lit(R, 0)
  for (a, b) in pairs:
    result = add(result, mul(lit(R, a), lit(R, b)))

func horner*[R: ExprSym](coeffs: openArray[int]; x: int): R {.raises: [].} =
  ## The polynomial with the given coefficients (highest degree first) at `x`, by Horner's rule.
  if coeffs.len == 0:
    return lit(R, 0)
  result = lit(R, coeffs[0])
  for i in 1 ..< coeffs.len:
    result = add(mul(result, lit(R, x)), lit(R, coeffs[i]))

func negated*[R: ExprSym](pairs: openArray[(int, int)]): R {.raises: [].} =
  ## A program built from another program: the negated dot product.
  neg(dotProduct[R](pairs))
