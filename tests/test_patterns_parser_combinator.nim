import std/unittest
import propcheck
import std/strutils
import nimcs/fp/result
import nimcs/patterns/parser_combinator

func rpn(tokens: seq[int]; scale: int): (Expr, int) {.raises: [].} =
  ## Builds a tree and, alongside, its value by an independent stack evaluation.
  ## Tokens 0..9 push a number, 10..12 combine the top two (add, sub, mul).
  var stack: seq[(Expr, int)]
  for t in tokens:
    if t <= 9 or stack.len < 2:
      let v = (t mod 10) * scale
      stack.add (num(v), v)
    else:
      let b = stack.pop
      let a = stack.pop
      case t
      of 10: stack.add (bin(opAdd, a[0], b[0]), a[1] + b[1])
      of 11: stack.add (bin(opSub, a[0], b[0]), a[1] - b[1])
      else: stack.add (bin(opMul, a[0], b[0]), a[1] * b[1])
  if stack.len == 0: return (num(0), 0)
  result = stack[0]
  for i in 1 ..< stack.len:
    result = (bin(opAdd, result[0], stack[i][0]), result[1] + stack[i][1])

func tokenGen(maxLen: int): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(0, 12), 0, maxLen)

func digitRun(s: string): int {.raises: [].} =
  for c in s:
    if c in {'0' .. '9'}: inc result else: return

# SPEC: PAT-PARSERCOMBINATOR-01
test "PAT-PARSERCOMBINATOR-01 Given any expression tree, when printed and parsed, then the same tree comes back":
  let outcome = check(tokenGen(20), proc(tokens: seq[int]): bool {.raises: [CatchableError].} =
    let e = rpn(tokens, 11)[0]
    let r = parseArithmetic(print(e))
    r.isOk and r.value == e)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARSERCOMBINATOR-02
test "PAT-PARSERCOMBINATOR-02 Given any three numbers, when parsed from text, then precedence and left associativity match host arithmetic":
  let outcome = check(pair(intIn(0, 99), pair(intIn(0, 99), intIn(0, 99))), proc(p: (int, (int, int))): bool {.raises: [CatchableError].} =
    let a = p[0]
    let b = p[1][0]
    let c = p[1][1]
    func value(s: string): int =
      let r = parseArithmetic(s)
      if r.isErr: return low(int)
      let v = evaluate(r.value)
      if v.isErr: low(int) else: v.value
    value($a & "-" & $b & "-" & $c) == a - b - c and
      value($a & "+" & $b & "*" & $c) == a + b * c and
      value($a & "*" & $b & "+" & $c) == a * b + c and
      value($a & "-" & $b & "+" & $c) == a - b + c and
      value("(" & $a & "+" & $b & ")*" & $c) == (a + b) * c)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARSERCOMBINATOR-03
test "PAT-PARSERCOMBINATOR-03 Given arbitrary text, when parsed, then the answer is a value: an error inside the text, or a tree that reprints to the same tree":
  let outcome = check(stringOf("012+-*() x", 0, 14), proc(s: string): bool {.raises: [CatchableError].} =
    let r = parseArithmetic(s)
    if r.isErr:
      r.error.pos >= 0 and r.error.pos <= s.len
    else:
      parseArithmetic(print(r.value)) == r)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARSERCOMBINATOR-03
test "PAT-PARSERCOMBINATOR-03 Given a valid expression followed by junk, when parsed, then the error points at the junk":
  let outcome = check(tokenGen(10), proc(tokens: seq[int]): bool {.raises: [CatchableError].} =
    let text = print(rpn(tokens, 1)[0])
    let r = parseArithmetic(text & "x")
    r.isErr and r.error.pos == text.len)
  checkpoint describe(outcome)
  check outcome.passed
  check parseArithmetic("").isErr
  check parseArithmetic("1+").isErr
  check parseArithmetic("(1").isErr
  check parseArithmetic("1234567890").isErr

# SPEC: PAT-PARSERCOMBINATOR-04
test "PAT-PARSERCOMBINATOR-04 Given any text, when many digits is run, then it succeeds and consumes exactly the leading digits":
  let outcome = check(stringOf("0129ab +", 0, 12), proc(s: string): bool {.raises: [CatchableError].} =
    let r = many(digit())(s, 0)
    r.isOk and r.value.next == digitRun(s) and r.value.value.len == digitRun(s))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARSERCOMBINATOR-04
test "PAT-PARSERCOMBINATOR-04 Given two alternatives, when the first succeeds, then orElse gives exactly its result":
  let outcome = check(stringOf("ab1", 0, 4), proc(s: string): bool {.raises: [CatchableError].} =
    let p = charP('a')
    let both = orElse(p, digit())
    let direct = p(s, 0)
    if direct.isOk: both(s, 0) == direct else: true)
  checkpoint describe(outcome)
  check outcome.passed
  check orElse(charP('a'), digit())("7", 0).isOk
  check orElse(charP('a'), digit())("b", 0).isErr

# SPEC: PAT-PARSERCOMBINATOR-05
test "PAT-PARSERCOMBINATOR-05 Given any tree, when printed with spaces between tokens and parsed, then the same tree comes back":
  let outcome = check(tokenGen(20), proc(tokens: seq[int]): bool {.raises: [CatchableError].} =
    let e = rpn(tokens, 11)[0]
    let r = parseArithmetic(" " & printSpaced(e) & "  ")
    r.isOk and r.value == e)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARSERCOMBINATOR-06
test "PAT-PARSERCOMBINATOR-06 Given any small expression, when printed, parsed and evaluated, then the value equals the stack model":
  let outcome = check(tokenGen(8), proc(tokens: seq[int]): bool {.raises: [CatchableError].} =
    let (e, expected) = rpn(tokens, 1)
    let r = parseArithmetic(print(e))
    r.isOk and evaluate(r.value).isOk and evaluate(r.value).value == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARSERCOMBINATOR-06
test "PAT-PARSERCOMBINATOR-06 Given an intermediate value beyond 2^31, when evaluated, then the answer is an out-of-range error":
  let r = parseArithmetic("99999*99999*99999")
  check r.isOk
  check evaluate(r.value).isErr
  check evaluate(r.value).error == eeOutOfRange

# SPEC: PAT-PARSERCOMBINATOR-07
test "PAT-PARSERCOMBINATOR-07 Given nesting beyond the limit, when parsed, then the answer is an error value, not a crash":
  for n in [MaxNesting + 1, 500]:
    let r = parseArithmetic("(".repeat(n) & "1" & ")".repeat(n))
    check r.isErr
    check r.error.expected == "nesting of at most " & $MaxNesting & " levels"
  check parseArithmetic("(".repeat(100_000) & "1" & ")".repeat(100_000)).isErr
  let atLimit = parseArithmetic("(".repeat(MaxNesting) & "1" & ")".repeat(MaxNesting))
  check atLimit.isOk
  check evaluate(atLimit.value).value == 1

# SPEC: PAT-PARSERCOMBINATOR-07
test "PAT-PARSERCOMBINATOR-07 Given input longer than the limit, when parsed, then it is refused; at the limit a long chain parses, prints and evaluates":
  check parseArithmetic("1+".repeat(MaxInputLen) & "1").isErr
  let chain = "1+".repeat(MaxInputLen div 2 - 1) & "1"
  check chain.len <= MaxInputLen
  let r = parseArithmetic(chain)
  check r.isOk
  check evaluate(r.value).value == MaxInputLen div 2
  check print(r.value).len > chain.len
  check r.value == r.value

# SPEC: PAT-PARSERCOMBINATOR-03
test "PAT-PARSERCOMBINATOR-03 Given an input where every alternative fails at the same place, when parsed, then the error lists what was expected":
  check parseArithmetic("(").error == ParseError(pos: 1, expected: "a digit or '('")
  check parseArithmetic("1+").error == ParseError(pos: 2, expected: "a digit or '('")
  check parseArithmetic("(1").error == ParseError(pos: 2, expected: "')'")
