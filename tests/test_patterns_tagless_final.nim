import std/unittest
import propcheck
import nimcs/patterns/tagless_final

func oracleDot(xs: seq[(int, int)]): int {.raises: [].} =
  for (a, b) in xs: result += a * b

func oracleHorner(cs: seq[int]; x: int): int {.raises: [].} =
  if cs.len == 0: return 0
  result = cs[0]
  for i in 1 ..< cs.len: result = result * x + cs[i]

func hornerSize(cs: seq[int]): int {.raises: [].} =
  if cs.len == 0: 1 else: 1 + 4 * (cs.len - 1)

func pairsGen(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(-9, 9), intIn(-9, 9)), 0, 8)

func coeffsGen(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-9, 9), 0, 8)

func balanced(s: string): bool {.raises: [].} =
  var depth = 0
  for c in s:
    if c == '(': inc depth
    elif c == ')':
      dec depth
      if depth < 0: return false
  depth == 0

# SPEC: PAT-TAGLESSFINAL-01
test "PAT-TAGLESSFINAL-01 Given any inputs, when the programs run under Eval, then they equal plain arithmetic":
  let outcome = check(pair(pairsGen(), pair(coeffsGen(), intIn(-5, 5))),
    proc(p: (seq[(int, int)], (seq[int], int))): bool {.raises: [CatchableError].} =
      dotProduct[Eval](p[0]).value == oracleDot(p[0]) and
        horner[Eval](p[1][0], p[1][1]).value == oracleHorner(p[1][0], p[1][1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TAGLESSFINAL-02
test "PAT-TAGLESSFINAL-02 Given any inputs, when the programs run under Size, then the node count follows their shape":
  let outcome = check(pair(pairsGen(), coeffsGen()), proc(p: (seq[(int, int)], seq[int])): bool {.raises: [CatchableError].} =
    dotProduct[Size](p[0]).nodes == 1 + 4 * p[0].len and horner[Size](p[1], 2).nodes == hornerSize(p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TAGLESSFINAL-03
test "PAT-TAGLESSFINAL-03 Given any inputs, when a program is reified to a tree, then evaluating or counting the tree equals the direct interpretation":
  let outcome = check(pair(pairsGen(), pair(coeffsGen(), intIn(-5, 5))),
    proc(p: (seq[(int, int)], (seq[int], int))): bool {.raises: [CatchableError].} =
      let t1 = dotProduct[Ast](p[0])
      let t2 = horner[Ast](p[1][0], p[1][1])
      evalAst(t1) == dotProduct[Eval](p[0]).value and sizeAst(t1) == dotProduct[Size](p[0]).nodes and
        evalAst(t2) == horner[Eval](p[1][0], p[1][1]).value and sizeAst(t2) == horner[Size](p[1][0], p[1][1]).nodes)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TAGLESSFINAL-04
test "PAT-TAGLESSFINAL-04 Given any inputs, when printed by Show or by printing the reified tree, then the text is the same and balanced":
  let outcome = check(pair(pairsGen(), coeffsGen()), proc(p: (seq[(int, int)], seq[int])): bool {.raises: [CatchableError].} =
    let a = dotProduct[Show](p[0]).text
    let b = horner[Show](p[1], 3).text
    a == printAst(dotProduct[Ast](p[0])) and b == printAst(horner[Ast](p[1], 3)) and
      balanced(a) and balanced(b))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TAGLESSFINAL-04
test "PAT-TAGLESSFINAL-04 Given a small input, when shown, then the text is the expected expression":
  check dotProduct[Show](@[(2, 3), (4, -1)]).text == "((0+(2*3))+(4*-1))"

# SPEC: PAT-TAGLESSFINAL-05
test "PAT-TAGLESSFINAL-05 Given any input, when a program is negated, then Eval gives the negated value and Size grows by exactly one node":
  let outcome = check(pairsGen(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    negated[Eval](xs).value == -dotProduct[Eval](xs).value and
      negated[Size](xs).nodes == dotProduct[Size](xs).nodes + 1)
  checkpoint describe(outcome)
  check outcome.passed
