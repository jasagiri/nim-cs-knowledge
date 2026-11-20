import std/[unittest, options, algorithm, sequtils]
import propcheck
import nimcs/fp/result
import nimcs/ds/kd_tree

proc pts(): Gen[seq[Point]] {.raises: [ValueError].} =
  let c = intIn(-12, 12).map(proc(i: int): float {.raises: [].} = float(i))
  seqOf(pair(c, c).map(proc(p: (float, float)): Point {.raises: [].} = point(p[0], p[1])), 0, 50)

func lexLess(a, b: Point): int =
  if a < b: -1 elif b < a: 1 else: 0

func bruteNearest(ps: seq[Point]; q: Point): Option[Point] =
  if ps.len == 0: return none(Point)
  var best = ps[0]
  for p in ps:
    let dp = dist2(p, q)
    let db = dist2(best, q)
    if dp < db or (dp == db and p < best): best = p
  some(best)

func build(ps: seq[Point]): KdTree =
  buildKdTree(ps).value

suite "kd_tree":
  # SPEC: DS-KDTREE-01
  test "DS-KDTREE-01 Given any points, when the tree is built, then it holds exactly those points and its invariants hold":
    let outcome = check(pts(),
      proc(ps: seq[Point]): bool {.raises: [CatchableError].} =
        let t = build(ps)
        t.toSeq == ps.sorted(lexLess) and t.len == ps.len and t.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-KDTREE-02
  test "DS-KDTREE-02 Given points and a query, when asking for the nearest, then it equals the brute-force answer with the smallest point on ties":
    let outcome = check(pair(pts(), pair(intIn(-15, 15), intIn(-15, 15))),
      proc(t: (seq[Point], (int, int))): bool {.raises: [CatchableError].} =
        let q = point(float(t[1][0]), float(t[1][1]))
        build(t[0]).nearest(q) == bruteNearest(t[0], q))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-KDTREE-03
  test "DS-KDTREE-03 Given points and a rectangle, when querying, then the answer is the brute-force filter in lexicographic order":
    let outcome = check(pair(pts(), pair(pair(intIn(-15, 15), intIn(-15, 15)), pair(intIn(-15, 15), intIn(-15, 15)))),
      proc(t: (seq[Point], ((int, int), (int, int)))): bool {.raises: [CatchableError].} =
        let r = rect(float(t[1][0][0]), float(t[1][0][1]), float(t[1][1][0]), float(t[1][1][1]))
        let want = t[0].filterIt(r.xLo <= it.x and it.x <= r.xHi and r.yLo <= it.y and it.y <= r.yHi)
        build(t[0]).inRect(r) == want.sorted(lexLess))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-KDTREE-04
  test "DS-KDTREE-04 Given the empty tree, when asking, then nearest is none and every rectangle is empty":
    let t = build(@[])
    check t.isEmpty and t.len == 0 and t.height == 0
    check t.nearest(point(0, 0)).isNone
    check t.inRect(rect(-1, 1, -1, 1)).len == 0
    check t.invariantsHold

  # SPEC: DS-KDTREE-05
  test "DS-KDTREE-05 Given a NaN, infinite or oversized coordinate, when building, then badCoordinate is returned":
    check buildKdTree([point(0, 0), point(NaN, 1)]) == err(KdTree, badCoordinate)
    check buildKdTree([point(Inf, 1)]) == err(KdTree, badCoordinate)
    check buildKdTree([point(1, -Inf)]) == err(KdTree, badCoordinate)
    check buildKdTree([point(1, 2e150)]) == err(KdTree, badCoordinate)
    check buildKdTree([point(1, 1e150)]).isOk

  # SPEC: DS-KDTREE-06
  test "DS-KDTREE-06 Given the same points in any input order, when building, then nearest and rectangle answers are identical":
    let outcome = check(pair(pts(), pair(intIn(-15, 15), intIn(-15, 15))),
      proc(t: (seq[Point], (int, int))): bool {.raises: [CatchableError].} =
        let q = point(float(t[1][0]), float(t[1][1]))
        let a = build(t[0])
        let b = build(t[0].reversed)
        let r = rect(q.x - 3, q.x + 3, q.y - 3, q.y + 3)
        a.nearest(q) == b.nearest(q) and a.inRect(r) == b.inRect(r) and a.toSeq == b.toSeq)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-KDTREE-07
  test "DS-KDTREE-07 Given duplicate points, when building and querying, then each copy is kept and counted":
    let t = build(@[point(1, 1), point(1, 1), point(2, 2)])
    check t.len == 3
    check t.inRect(rect(0, 1, 0, 1)) == @[point(1, 1), point(1, 1)]
    check t.nearest(point(1, 1)) == some(point(1, 1))

  # SPEC: DS-KDTREE-08
  test "DS-KDTREE-08 Given a large grid, when building, then the height stays logarithmic":
    var grid: seq[Point]
    for i in 0 ..< 100:
      for j in 0 ..< 100:
        grid.add point(float(i), float(j))
    let t = build(grid)
    check t.len == 10_000
    check t.height <= 14                    # ceil(log2(10001)) = 14 for a median-split tree
    check t.nearest(point(49.4, 50.6)) == some(point(49, 51))
    check t.inRect(rect(10, 12, 20, 21)).len == 6

  # SPEC: DS-KDTREE-09
  test "DS-KDTREE-09 Given a tree, when queried, then it is not changed (the value is immutable)":
    let t = build(@[point(3, 3), point(1, 1)])
    let before = t.toSeq
    check t.nearest(point(0, 0)) == some(point(1, 1))
    check t.inRect(rect(0, 5, 0, 5)).len == 2
    check t.toSeq == before
