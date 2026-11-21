import std/[algorithm, sequtils, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/convex_hull

proc clouds(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(-6, 6), intIn(-6, 6)), 0, 12)

func pointsOf(raw: seq[(int, int)]): seq[Point] {.raises: [].} =
  for (x, y) in raw:
    result.add point(x, y)

func hullOf(points: seq[Point]): seq[Point] {.raises: [].} =
  ## The generated coordinates are small, so the hull cannot fail.
  convexHull(points).value

func onSegment(a, b, p: Point): bool {.raises: [].} =
  cross(a, b, p) == 0 and min(a.x, b.x) <= p.x and p.x <= max(a.x, b.x) and
    min(a.y, b.y) <= p.y and p.y <= max(a.y, b.y)

func inClosedTriangle(a, b, c, p: Point): bool {.raises: [].} =
  if cross(a, b, c) == 0:
    return onSegment(a, b, p) or onSegment(b, c, p) or onSegment(a, c, p)
  let d1 = cross(a, b, p)
  let d2 = cross(b, c, p)
  let d3 = cross(c, a, p)
  (d1 >= 0 and d2 >= 0 and d3 >= 0) or (d1 <= 0 and d2 <= 0 and d3 <= 0)

func extremePoints(points: seq[Point]): seq[Point] {.raises: [].} =
  ## Oracle: a distinct point is a vertex of the hull exactly when it lies in no closed triangle
  ## (or segment) made of other distinct points. Cubic, for tiny inputs only.
  var unique = points.sorted
  unique = unique.deduplicate(isSorted = true)
  for p in unique:
    var others: seq[Point]
    for q in unique:
      if q != p: others.add q
    var inside = false
    for i in 0 ..< others.len:
      for j in i ..< others.len:
        for k in j ..< others.len:
          if inClosedTriangle(others[i], others[j], others[k], p): inside = true
    if not inside: result.add p

# SPEC: GEO-CONVEXHULL-01
test "GEO-CONVEXHULL-01 Given a square with interior and edge points, when hulled, then only the four corners remain":
  let pts = @[point(0, 0), point(2, 0), point(4, 0), point(4, 4), point(0, 4), point(2, 2),
              point(4, 2), point(1, 3), point(0, 0)]
  check hullOf(pts) == @[point(0, 0), point(4, 0), point(4, 4), point(0, 4)]

# SPEC: GEO-CONVEXHULL-01
test "GEO-CONVEXHULL-01 Given any small point set, when hulled, then the vertices are exactly the extreme points":
  let outcome = check(clouds(), proc(raw: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let pts = pointsOf(raw)
    hullOf(pts).sorted == extremePoints(pts))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GEO-CONVEXHULL-02
test "GEO-CONVEXHULL-02 Given any point set with three or more vertices, when hulled, then it starts lowest-leftmost and every turn is strictly counter-clockwise":
  let outcome = check(clouds(), proc(raw: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let pts = pointsOf(raw)
    let h = hullOf(pts)
    if h.len < 3: return true
    var ok = h[0] == pts.sorted[0]
    for i in 0 ..< h.len:
      ok = ok and cross(h[i], h[(i + 1) mod h.len], h[(i + 2) mod h.len]) > 0
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GEO-CONVEXHULL-03
test "GEO-CONVEXHULL-03 Given any point set, when hulled, then every input point is on or left of every hull edge":
  let outcome = check(clouds(), proc(raw: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let pts = pointsOf(raw)
    let h = hullOf(pts)
    var ok = true
    if h.len >= 3:
      for i in 0 ..< h.len:
        for p in pts:
          ok = ok and cross(h[i], h[(i + 1) mod h.len], p) >= 0
    for v in h:
      ok = ok and v in pts
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GEO-CONVEXHULL-04
test "GEO-CONVEXHULL-04 Given no points, one point, repeated points or collinear points, when hulled, then the degenerate hulls come back":
  check hullOf(newSeq[Point]()).len == 0
  check hullOf(@[point(3, 4)]) == @[point(3, 4)]
  check hullOf(@[point(3, 4), point(3, 4), point(3, 4)]) == @[point(3, 4)]
  check hullOf(@[point(2, 2), point(0, 0), point(1, 1), point(3, 3)]) == @[point(0, 0), point(3, 3)]
  check hullOf(@[point(1, 5), point(1, 0), point(1, 3)]) == @[point(1, 0), point(1, 5)]

# SPEC: GEO-CONVEXHULL-05
test "GEO-CONVEXHULL-05 Given any point set, when hulled again or shuffled or doubled, then the hull is unchanged":
  let outcome = check(clouds(), proc(raw: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let pts = pointsOf(raw)
    let h = hullOf(pts)
    h == hullOf(h) and h == hullOf(pts.reversed) and h == hullOf(pts & pts))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GEO-CONVEXHULL-06
test "GEO-CONVEXHULL-06 Given turns left, right and straight, when taking the cross product, then its sign says which":
  check cross(point(0, 0), point(1, 0), point(1, 1)) > 0
  check cross(point(0, 0), point(1, 0), point(1, -1)) < 0
  check cross(point(0, 0), point(1, 1), point(2, 2)) == 0
  check cross(point(-MaxCoord, -MaxCoord), point(MaxCoord, -MaxCoord), point(MaxCoord, MaxCoord)) ==
    4_000_000_000_000_000_000

# SPEC: GEO-CONVEXHULL-07
test "GEO-CONVEXHULL-07 Given coordinates at and beyond the limit, when hulled, then the limit is accepted and one past it fails":
  check convexHull(@[point(MaxCoord, MaxCoord), point(-MaxCoord, -MaxCoord), point(MaxCoord, -MaxCoord)]).isOk
  check convexHull(@[point(0, 0), point(MaxCoord + 1, 0)]).error == heCoordinateTooLarge
  check convexHull(@[point(0, -MaxCoord - 1)]).isErr
