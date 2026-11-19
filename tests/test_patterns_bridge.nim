import std/unittest
import propcheck
import nimcs/patterns/bridge

func shapes(): Gen[Shape] {.raises: [ValueError].} =
  pair(boolean(), pair(pair(intIn(-9, 9), intIn(-9, 9)), pair(intIn(1, 9), intIn(1, 9)))).map(
    proc(p: (bool, ((int, int), (int, int)))): Shape {.raises: [].} =
      let ((a, b), (c, d)) = p[1]
      if p[0]: Shape(kind: skRect, x: a, y: b, w: c, h: d)
      else: Shape(kind: skCircle, cx: a, cy: b, r: c))

func backends(): Gen[Backend] {.raises: [ValueError].} =
  pick([svgBackend(), asciiBackend()])

# A backend written here, outside the module: the module must not need to know it.
func reversedBackend(): Backend {.raises: [].} =
  Backend(name: "rev", line: proc(a, b: Point): string {.noSideEffect, raises: [].} =
    $b.x & "," & $b.y & "<-" & $a.x & "," & $a.y)

func segmentsOf(s: Shape): seq[Segment] {.raises: [].} =
  lower(s)

# SPEC: GOF-BRIDGE-01
test "GOF-BRIDGE-01 Given a shape and a backend, when drawn, then the result is the backend's line for each lowered segment":
  let outcome = check(pair(shapes(), backends()), proc(p: (Shape, Backend)): bool {.raises: [CatchableError].} =
    let (s, b) = p
    var expected: seq[string] = @[]
    for seg in lower(s):
      expected.add(b.line(seg.a, seg.b))
    draw(s, b) == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BRIDGE-01
test "GOF-BRIDGE-01 Given a rectangle, when drawn by each backend, then the known strings appear":
  let r = Shape(kind: skRect, x: 1, y: 2, w: 3, h: 4)
  check draw(r, svgBackend()) == @[
    "<line x1=1 y1=2 x2=4 y2=2/>", "<line x1=4 y1=2 x2=4 y2=6/>",
    "<line x1=4 y1=6 x2=1 y2=6/>", "<line x1=1 y1=6 x2=1 y2=2/>"]
  check draw(r, asciiBackend()).len == 4
  check draw(r, asciiBackend())[0] == "LINE 1,2 4,2"

# SPEC: GOF-BRIDGE-02
test "GOF-BRIDGE-02 Given two lists of shapes, when drawn together, then it is the concatenation of drawing each":
  let outcome = check(pair(pair(seqOf(shapes(), 0, 5), seqOf(shapes(), 0, 5)), backends()),
    proc(p: ((seq[Shape], seq[Shape]), Backend)): bool {.raises: [CatchableError].} =
      let ((xs, ys), b) = p
      drawAll(xs & ys, b) == drawAll(xs, b) & drawAll(ys, b))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BRIDGE-03
test "GOF-BRIDGE-03 Given any shape, when lowered, then the segments do not depend on the backend and form a closed outline":
  let outcome = check(shapes(), proc(s: Shape): bool {.raises: [CatchableError].} =
    let segs = segmentsOf(s)
    var closed = segs.len == (if s.kind == skRect: 4 else: 8)
    for i in 0 ..< segs.len:
      if segs[i].b != segs[(i + 1) mod segs.len].a: closed = false
    closed)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BRIDGE-03
test "GOF-BRIDGE-03 Given a backend defined outside the module, when it draws any shape, then it works without changing shapes or module":
  let outcome = check(shapes(), proc(s: Shape): bool {.raises: [CatchableError].} =
    let rev = reversedBackend()
    let drawn = draw(s, rev)
    drawn.len == lower(s).len and (drawn.len == 0 or drawn[0] ==
      $lower(s)[0].b.x & "," & $lower(s)[0].b.y & "<-" & $lower(s)[0].a.x & "," & $lower(s)[0].a.y))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BRIDGE-03
test "GOF-BRIDGE-03 Given a shape, when moved and drawn by any backend, then it equals drawing the lowered segments shifted":
  let outcome = check(pair(pair(shapes(), pair(intIn(-5, 5), intIn(-5, 5))), backends()),
    proc(p: ((Shape, (int, int)), Backend)): bool {.raises: [CatchableError].} =
      let ((s, d), b) = p
      var expected: seq[string] = @[]
      for seg in lower(s):
        expected.add(b.line(Point(x: seg.a.x + d[0], y: seg.a.y + d[1]),
                            Point(x: seg.b.x + d[0], y: seg.b.y + d[1])))
      draw(moved(s, d[0], d[1]), b) == expected)
  checkpoint describe(outcome)
  check outcome.passed
