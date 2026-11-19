import std/[unittest, options]
import propcheck
import nimcs/patterns/visitor

# A shape tree is read from a reverse-Polish style program: codes 0..4 push a leaf
# (rect or circle with small coordinates derived from the code and its position), code 5 wraps the
# whole stack top into a group of the top two (or one) items.
func fromCodes(codes: seq[int]): Shape {.raises: [].} =
  var stack: seq[Shape]
  for i, c in codes:
    case c
    of 0, 1: stack.add rect(i - 4, c * 3 - 2, c + i mod 5, 2 + i mod 3)
    of 2, 3, 4: stack.add circle(c * 2 - i, i mod 4 - 1, c - 1)
    else:
      if stack.len >= 2:
        let b = stack.pop
        let a = stack.pop
        stack.add group(@[a, b])
      elif stack.len == 1:
        stack[0] = group(@[stack[0]])
      else:
        stack.add group(@[])
  group(stack)

func codes(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(0, 5), 0, 20)

# Two visitors written both ways: a direct `case` and a ShapeFold.
func leafCountFold(): ShapeFold[int] {.raises: [].} =
  ShapeFold[int](
    rect: proc(x, y, w, h: int): int {.noSideEffect, raises: [].} = 1,
    circle: proc(cx, cy, r: int): int {.noSideEffect, raises: [].} = 1,
    group: proc(cs: seq[int]): int {.noSideEffect, raises: [].} =
      for c in cs: result += c)

func renderFold(): ShapeFold[string] {.raises: [].} =
  ShapeFold[string](
    rect: proc(x, y, w, h: int): string {.noSideEffect, raises: [].} =
      "<rect " & $x & " " & $y & " " & $w & " " & $h & "/>",
    circle: proc(cx, cy, r: int): string {.noSideEffect, raises: [].} =
      "<circle " & $cx & " " & $cy & " " & $r & "/>",
    group: proc(cs: seq[string]): string {.noSideEffect, raises: [].} =
      result = "<g>"
      for c in cs: result.add c
      result.add "</g>")

# SPEC: GOF-VISITOR-01
test "GOF-VISITOR-01 Given any shape, when counted or rendered by case and by a ShapeFold, then both encodings agree":
  let outcome = check(codes(), proc(cs: seq[int]): bool {.raises: [CatchableError].} =
    let s = fromCodes(cs)
    s.leafCount == s.accept(leafCountFold()) and s.render == s.accept(renderFold()))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-VISITOR-02
test "GOF-VISITOR-02 Given any shape and offset, when translated, then its bounds move by the same offset":
  let outcome = check(pair(codes(), pair(intIn(-9, 9), intIn(-9, 9))), proc(p: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
    let s = fromCodes(p[0])
    let b = s.bounds
    let t = s.translate(p[1][0], p[1][1]).bounds
    if b.isNone: return t.isNone
    let m = b.get
    t.isSome and t.get == Bounds(x0: m.x0 + p[1][0], y0: m.y0 + p[1][1], x1: m.x1 + p[1][0], y1: m.y1 + p[1][1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-VISITOR-03
test "GOF-VISITOR-03 Given any shape, when translated, then leaf count and footprint are unchanged":
  let outcome = check(pair(codes(), pair(intIn(-9, 9), intIn(-9, 9))), proc(p: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
    let s = fromCodes(p[0])
    let t = s.translate(p[1][0], p[1][1])
    t.leafCount == s.leafCount and t.footprint == s.footprint)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-VISITOR-04
test "GOF-VISITOR-04 Given any shape and two offsets, when translated twice, then it equals one translation by the sum":
  let outcome = check(pair(codes(), pair(pair(intIn(-9, 9), intIn(-9, 9)), pair(intIn(-9, 9), intIn(-9, 9)))), proc(p: (seq[int], ((int, int), (int, int)))): bool {.raises: [CatchableError].} =
    let s = fromCodes(p[0])
    let a = p[1][0]
    let b = p[1][1]
    s.translate(a[0], a[1]).translate(b[0], b[1]) == s.translate(a[0] + b[0], a[1] + b[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-VISITOR-05
test "GOF-VISITOR-05 Given any shape, when translated by zero, then it is unchanged":
  let outcome = check(codes(), proc(cs: seq[int]): bool {.raises: [CatchableError].} =
    let s = fromCodes(cs)
    s.translate(0, 0) == s)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-VISITOR-06
test "GOF-VISITOR-06 Given a group, when bounds are taken, then they contain the bounds of each child":
  let outcome = check(codes(), proc(cs: seq[int]): bool {.raises: [CatchableError].} =
    let s = fromCodes(cs)
    let b = s.bounds
    if s.children.len == 0 or b.isNone: return true
    for c in s.children:
      let cb = c.bounds
      if cb.isSome and not (b.get.x0 <= cb.get.x0 and b.get.y0 <= cb.get.y0 and
                            cb.get.x1 <= b.get.x1 and cb.get.y1 <= b.get.y1):
        return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-VISITOR-07
test "GOF-VISITOR-07 Given concrete shapes, when visited, then the values are as written":
  let s = group(@[rect(0, 0, 4, 2), circle(10, 10, 3), group(@[])])
  check s.leafCount == 2
  check s.bounds.get == Bounds(x0: 0, y0: 0, x1: 13, y1: 13)
  check s.footprint == 169
  check s.render == "<g><rect 0 0 4 2/><circle 10 10 3/><g></g></g>"
  check group(@[]).bounds.isNone
  check group(@[]).footprint == 0
  check rect(1, 1, -5, 2).w == 0
