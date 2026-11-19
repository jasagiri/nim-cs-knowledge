## Parser combinators: small parsers are values, and bigger parsers are functions of them.
##
## A `Parser[T]` takes the input and a position and returns either a value with the position
## after it, or a `ParseError` saying where and what was expected. Nothing is thrown and nothing
## is mutated, so a parser is a pure function you can test on any string. Combinators (`thenP`,
## `orElse`, `many`, `chainl1`, `between`) build larger parsers from smaller ones, and the
## grammar of arithmetic below reads like its own specification. Use it for small formats where a
## parser generator is too heavy; for large or ambiguous grammars use a generator. Alternatives
## are tried left to right and the first success wins (no backtracking into a chosen branch).

import nimcs/fp/result

type
  ParseError* = object
    pos*: int
    expected*: string

  Parsed*[T] = object
    value*: T
    next*: int  ## position just after what was consumed

  Parser*[T] = proc(input: string; pos: int): Result[Parsed[T], ParseError] {.noSideEffect, raises: [].}

  CharTest* = proc(c: char): bool {.noSideEffect, raises: [].}

  BinOp* = enum
    opAdd, opSub, opMul

  ExprKind* = enum
    ekNum, ekBin

  Expr* = ref ExprNode
  ExprNode* = object
    ## An immutable tree: build it with `num` and `bin`, never assign to a field.
    case kind*: ExprKind
    of ekNum:
      value*: int
    of ekBin:
      op*: BinOp
      left*, right*: Expr

  EvalError* = enum
    eeOutOfRange

const MaxLiteral* = 999_999_999
const MaxNesting* = 64      ## deepest parenthesis nesting `parseArithmetic` accepts
const MaxInputLen* = 1024   ## longest input `parseArithmetic` accepts, in bytes
const ValueLimit* = 2_147_483_648  ## intermediate results beyond +-2^31 are refused

# ── combinators ────────────────────────────────────────────────────────────

func satisfy*(test: CharTest; what: string): Parser[char] {.raises: [].} =
  ## One character that passes `test`; `what` names it in the error.
  proc(input: string; pos: int): Result[Parsed[char], ParseError] {.noSideEffect, raises: [].} =
    if pos >= 0 and pos < input.len and test(input[pos]):
      ok(Parsed[char](value: input[pos], next: pos + 1), ParseError)
    else:
      err(Parsed[char], ParseError(pos: pos, expected: what))

func charP*(c: char): Parser[char] {.raises: [].} =
  satisfy(proc(x: char): bool {.noSideEffect, raises: [].} = x == c, "'" & c & "'")

func digit*(): Parser[char] {.raises: [].} =
  satisfy(proc(x: char): bool {.noSideEffect, raises: [].} = x in {'0' .. '9'}, "a digit")

func mapP*[T, U](p: Parser[T]; f: proc(x: T): U {.noSideEffect, raises: [].}): Parser[U] {.raises: [].} =
  ## Changes the value of a successful parse.
  proc(input: string; pos: int): Result[Parsed[U], ParseError] {.noSideEffect, raises: [].} =
    let r = p(input, pos)
    if r.isOk: ok(Parsed[U](value: f(r.value.value), next: r.value.next), ParseError)
    else: err(Parsed[U], r.error)

func flatMapP*[T, U](p: Parser[T]; f: proc(x: T): Result[U, string] {.noSideEffect, raises: [].}): Parser[U] {.raises: [].} =
  ## Like `mapP`, but `f` may refuse the value; its message becomes the error at the start position.
  proc(input: string; pos: int): Result[Parsed[U], ParseError] {.noSideEffect, raises: [].} =
    let r = p(input, pos)
    if r.isErr: return err(Parsed[U], r.error)
    let mapped = f(r.value.value)
    if mapped.isOk: ok(Parsed[U](value: mapped.value, next: r.value.next), ParseError)
    else: err(Parsed[U], ParseError(pos: pos, expected: mapped.error))

func thenP*[A, B](p: Parser[A]; q: Parser[B]): Parser[(A, B)] {.raises: [].} =
  ## `p` then `q`; both values are kept.
  proc(input: string; pos: int): Result[Parsed[(A, B)], ParseError] {.noSideEffect, raises: [].} =
    let a = p(input, pos)
    if a.isErr: return err(Parsed[(A, B)], a.error)
    let b = q(input, a.value.next)
    if b.isErr: err(Parsed[(A, B)], b.error)
    else: ok(Parsed[(A, B)](value: (a.value.value, b.value.value), next: b.value.next), ParseError)

func orElse*[T](p, q: Parser[T]): Parser[T] {.raises: [].} =
  ## `p`'s result when it succeeds, otherwise `q`'s. When both fail, the error is the one that
  ## got further; when they failed at the same position, the expectations are joined with "or".
  proc(input: string; pos: int): Result[Parsed[T], ParseError] {.noSideEffect, raises: [].} =
    let a = p(input, pos)
    if a.isOk: return a
    let b = q(input, pos)
    if b.isOk: return b
    if a.error.pos > b.error.pos: err(Parsed[T], a.error)
    elif b.error.pos > a.error.pos: err(Parsed[T], b.error)
    elif a.error.expected == b.error.expected: err(Parsed[T], b.error)
    else: err(Parsed[T], ParseError(pos: a.error.pos, expected: a.error.expected & " or " & b.error.expected))

func many*[T](p: Parser[T]): Parser[seq[T]] {.raises: [].} =
  ## Zero or more repetitions; it never fails. A repetition that consumes nothing ends the loop,
  ## so a parser that can succeed on empty input cannot make it spin.
  proc(input: string; pos: int): Result[Parsed[seq[T]], ParseError] {.noSideEffect, raises: [].} =
    var items: seq[T]
    var cur = pos
    while true:
      let r = p(input, cur)
      if r.isErr or r.value.next <= cur: break
      items.add r.value.value
      cur = r.value.next
    ok(Parsed[seq[T]](value: items, next: cur), ParseError)

func many1*[T](p: Parser[T]): Parser[seq[T]] {.raises: [].} =
  ## One or more repetitions; the error is that of the first attempt.
  proc(input: string; pos: int): Result[Parsed[seq[T]], ParseError] {.noSideEffect, raises: [].} =
    let first = p(input, pos)
    if first.isErr: return err(Parsed[seq[T]], first.error)
    let rest = many(p)(input, first.value.next)
    if rest.isErr: return err(Parsed[seq[T]], rest.error)
    ok(Parsed[seq[T]](value: @[first.value.value] & rest.value.value, next: rest.value.next), ParseError)

func skipSpaces*(): Parser[int] {.raises: [].} =
  ## Skips blanks and returns how many; never fails.
  many(satisfy(proc(x: char): bool {.noSideEffect, raises: [].} = x == ' ', "a space")).mapP(
    proc(xs: seq[char]): int {.noSideEffect, raises: [].} = xs.len)

func token*[T](p: Parser[T]): Parser[T] {.raises: [].} =
  ## `p` followed by any blanks, whose count is dropped.
  proc(input: string; pos: int): Result[Parsed[T], ParseError] {.noSideEffect, raises: [].} =
    let r = p(input, pos)
    if r.isErr: return r
    let blanks = skipSpaces()(input, r.value.next)
    if blanks.isErr: return err(Parsed[T], blanks.error)
    ok(Parsed[T](value: r.value.value, next: blanks.value.next), ParseError)

func between*[O, T, C](open: Parser[O]; p: Parser[T]; close: Parser[C]): Parser[T] {.raises: [].} =
  ## `open`, then `p`, then `close`; keeps only `p`'s value.
  proc(input: string; pos: int): Result[Parsed[T], ParseError] {.noSideEffect, raises: [].} =
    let o = open(input, pos)
    if o.isErr: return err(Parsed[T], o.error)
    let inner = p(input, o.value.next)
    if inner.isErr: return inner
    let c = close(input, inner.value.next)
    if c.isErr: return err(Parsed[T], c.error)
    ok(Parsed[T](value: inner.value.value, next: c.value.next), ParseError)

func lazyP*[T](make: proc(): Parser[T] {.noSideEffect, raises: [].}): Parser[T] {.raises: [].} =
  ## Builds the parser only when it first runs, which lets a grammar rule refer to itself.
  proc(input: string; pos: int): Result[Parsed[T], ParseError] {.noSideEffect, raises: [].} =
    make()(input, pos)

func chainl1*[T, O](operand: Parser[T]; op: Parser[O];
                    combine: proc(o: O; l, r: T): T {.noSideEffect, raises: [].}): Parser[T] {.raises: [].} =
  ## `operand (op operand)*`, combined from the left: `1-2-3` is `(1-2)-3`. Once an operator has
  ## been read, a missing operand is an error rather than a silent stop.
  proc(input: string; pos: int): Result[Parsed[T], ParseError] {.noSideEffect, raises: [].} =
    let first = operand(input, pos)
    if first.isErr: return first
    var acc = first.value.value
    var cur = first.value.next
    while true:
      let o = op(input, cur)
      if o.isErr: break
      let rhs = operand(input, o.value.next)
      if rhs.isErr: return err(Parsed[T], rhs.error)
      acc = combine(o.value.value, acc, rhs.value.value)
      cur = rhs.value.next
    ok(Parsed[T](value: acc, next: cur), ParseError)

# ── the expression type ────────────────────────────────────────────────────

func `==`*(a, b: Expr): bool {.raises: [].} =
  ## Structural equality (the default for `ref` would compare addresses).
  if a.isNil or b.isNil: return a.isNil and b.isNil
  if a.kind != b.kind: return false
  case a.kind
  of ekNum: a.value == b.value
  of ekBin: a.op == b.op and a.left == b.left and a.right == b.right

func num*(v: range[0 .. MaxLiteral]): Expr {.raises: [].} =
  ## A literal. Out-of-range values raise a `RangeDefect`: callers can check the bound.
  Expr(kind: ekNum, value: v)

func bin*(op: BinOp; left, right: Expr): Expr {.raises: [].} =
  Expr(kind: ekBin, op: op, left: left, right: right)

func opChar(op: BinOp): char {.raises: [].} =
  case op
  of opAdd: '+'
  of opSub: '-'
  of opMul: '*'

func print*(e: Expr): string {.raises: [].} =
  ## Fully parenthesised, no spaces: `((1+2)*3)`. `parseArithmetic` reads it back to the same tree.
  case e.kind
  of ekNum: $e.value
  of ekBin: "(" & print(e.left) & $opChar(e.op) & print(e.right) & ")"

func printSpaced*(e: Expr): string {.raises: [].} =
  ## Like `print` with one blank between tokens: `( ( 1 + 2 ) * 3 )`.
  case e.kind
  of ekNum: $e.value
  of ekBin: "( " & printSpaced(e.left) & " " & $opChar(e.op) & " " & printSpaced(e.right) & " )"

func evaluate*(e: Expr): Result[int, EvalError] {.raises: [].} =
  ## Evaluates in `int`; an intermediate value beyond +-2^31 is `eeOutOfRange`, which also keeps
  ## every product inside 64 bits.
  case e.kind
  of ekNum: ok(e.value, EvalError)
  of ekBin:
    let l = evaluate(e.left)
    if l.isErr: return l
    let r = evaluate(e.right)
    if r.isErr: return r
    let v =
      case e.op
      of opAdd: l.value + r.value
      of opSub: l.value - r.value
      of opMul: l.value * r.value
    if abs(v) > ValueLimit: err(int, eeOutOfRange) else: ok(v, EvalError)

# ── the grammar ────────────────────────────────────────────────────────────
#   expr   = term   (('+' | '-') term)*
#   term   = factor ('*' factor)*
#   factor = number | '(' expr ')'

func exprP*(): Parser[Expr] {.raises: [].}

func numberP(): Parser[Expr] {.raises: [].} =
  token(many1(digit())).flatMapP(
    proc(ds: seq[char]): Result[Expr, string] {.noSideEffect, raises: [].} =
      if ds.len > 9:
        err(Expr, "a number of at most 9 digits")
      else:
        var n = 0
        for c in ds: n = n * 10 + (ord(c) - ord('0'))
        ok(num(n), string))

func combineOp(o: BinOp; l, r: Expr): Expr {.raises: [].} = bin(o, l, r)

func addOp(): Parser[BinOp] {.raises: [].} =
  let plus = token(charP('+')).mapP(proc(c: char): BinOp {.noSideEffect, raises: [].} = opAdd)
  let minus = token(charP('-')).mapP(proc(c: char): BinOp {.noSideEffect, raises: [].} = opSub)
  orElse(plus, minus)

func mulOp(): Parser[BinOp] {.raises: [].} =
  token(charP('*')).mapP(proc(c: char): BinOp {.noSideEffect, raises: [].} = opMul)

func factorP(): Parser[Expr] {.raises: [].} =
  orElse(numberP(), between(token(charP('(')), lazyP(exprP), token(charP(')'))))

func termP(): Parser[Expr] {.raises: [].} =
  chainl1(factorP(), mulOp(), combineOp)

func exprP*(): Parser[Expr] {.raises: [].} =
  chainl1(termP(), addOp(), combineOp)

func parseArithmetic*(input: string): Result[Expr, ParseError] {.raises: [].} =
  ## Parses the whole input (blanks allowed around tokens). Unconsumed input is an error at the
  ## position where it starts. Input longer than `MaxInputLen` or nested deeper than `MaxNesting`
  ## is refused with an error before parsing, because recursion depth (here and in `print`,
  ## `evaluate`, `==`) follows nesting and chain length. `exprP()` called directly has no limit.
  if input.len > MaxInputLen:
    return err(Expr, ParseError(pos: MaxInputLen, expected: "input of at most " & $MaxInputLen & " bytes"))
  var depth = 0
  for i, c in input:
    if c == '(':
      inc depth
      if depth > MaxNesting:
        return err(Expr, ParseError(pos: i, expected: "nesting of at most " & $MaxNesting & " levels"))
    elif c == ')' and depth > 0:
      dec depth
  let lead = skipSpaces()(input, 0)
  if lead.isErr: return err(Expr, lead.error)
  let r = exprP()(input, lead.value.next)
  if r.isErr: return err(Expr, r.error)
  if r.value.next != input.len:
    return err(Expr, ParseError(pos: r.value.next, expected: "end of input"))
  ok(r.value.value, ParseError)
