## Static 2-d tree: nearest neighbour and rectangle queries over a fixed set of points.
##
## The tree is built once from a sequence of points. At each level the points are sorted along one
## axis (x at the root, then y, then x again), the median becomes the node, and the two halves
## become its subtrees, so the tree is balanced with height about log2 n. Nothing is updated
## afterwards: the tree is an immutable value, safe to share. `nearest` descends towards the query
## point and visits the far side only when the splitting line is at least as close as the best
## point found so far; `inRect` visits only subtrees that can overlap the rectangle. Results are
## deterministic: a tie in distance goes to the lexicographically smaller point, and `inRect`
## returns points in lexicographic order. Use it for repeated spatial queries over points that do
## not change; for a set that changes, rebuild, or use a structure with updates (`treap` on one
## coordinate when one axis is enough).

import std/[algorithm, options]
import nimcs/fp/result

const maxCoord* = 1e150
  ## Coordinates must satisfy `abs(c) <= maxCoord`, so that a squared distance cannot overflow.

type
  Point* = object
    x*, y*: float
  Rect* = object
    ## The closed rectangle `[xLo, xHi] x [yLo, yHi]`; empty when a low bound exceeds its high one.
    xLo*, xHi*, yLo*, yHi*: float
  KdError* = enum
    badCoordinate   ## a coordinate is NaN, infinite or larger than `maxCoord` in magnitude
  Node = ref object
    pt: Point
    left, right: Node
  KdTree* = object
    root: Node
    size: int

func point*(x, y: float): Point {.raises: [].} =
  Point(x: x, y: y)

func rect*(xLo, xHi, yLo, yHi: float): Rect {.raises: [].} =
  Rect(xLo: xLo, xHi: xHi, yLo: yLo, yHi: yHi)

func `==`*(a, b: Point): bool {.raises: [].} =
  a.x == b.x and a.y == b.y

func `<`*(a, b: Point): bool {.raises: [].} =
  ## Lexicographic order: by x, then by y.
  a.x < b.x or (a.x == b.x and a.y < b.y)

func dist2*(a, b: Point): float {.raises: [].} =
  ## Squared Euclidean distance (exact comparison without a square root).
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy

func validCoord(c: float): bool =
  abs(c) <= maxCoord               # false for NaN and for the infinities

func coord(p: Point; axis: int): float =
  if axis == 0: p.x else: p.y

func cmpOnAxis(a, b: Point; axis: int): int =
  ## Order by the axis coordinate, with the full lexicographic order as a deterministic tie-break.
  let ca = coord(a, axis)
  let cb = coord(b, axis)
  if ca < cb: -1
  elif cb < ca: 1
  elif a < b: -1
  elif b < a: 1
  else: 0

func build(pts: seq[Point]; axis: int): Node =
  if pts.len == 0: return nil
  var sorted = pts
  sorted.sort(proc(a, b: Point): int = cmpOnAxis(a, b, axis))
  let mid = sorted.len div 2
  Node(pt: sorted[mid], left: build(sorted[0 ..< mid], 1 - axis),
    right: build(sorted[mid + 1 ..< sorted.len], 1 - axis))

func buildKdTree*(points: openArray[Point]): Result[KdTree, KdError] {.raises: [].} =
  ## Builds the tree. Duplicate points are kept. A point with a coordinate that is NaN, infinite or
  ## beyond `maxCoord` makes the whole build fail with `badCoordinate`.
  for p in points:
    if not validCoord(p.x) or not validCoord(p.y):
      return err(KdTree, badCoordinate)
  ok(KdTree(root: build(@points, 0), size: points.len), KdError)

func len*(t: KdTree): int {.raises: [].} =
  t.size

func isEmpty*(t: KdTree): bool {.raises: [].} =
  t.root.isNil

func better(cand, best: Point; q: Point): bool =
  let dc = dist2(cand, q)
  let db = dist2(best, q)
  dc < db or (dc == db and cand < best)

func nearestIn(n: Node; q: Point; axis: int; best: Option[Point]): Option[Point] =
  if n.isNil: return best
  var cur = best
  if cur.isNone or better(n.pt, cur.get, q):
    cur = some(n.pt)
  let diff = coord(q, axis) - coord(n.pt, axis)
  let (near, far) = if diff < 0: (n.left, n.right) else: (n.right, n.left)
  cur = nearestIn(near, q, 1 - axis, cur)
  # The far side can hold an equally close point, so the test is `<=`, not `<`.
  if diff * diff <= dist2(cur.get, q):
    cur = nearestIn(far, q, 1 - axis, cur)
  cur

func nearest*(t: KdTree; q: Point): Option[Point] {.raises: [].} =
  ## The stored point closest to `q`; among equally close points the lexicographically smallest.
  ## None for an empty tree. `q` must have coordinates within `maxCoord` in magnitude.
  nearestIn(t.root, q, 0, none(Point))

func inside(r: Rect; p: Point): bool =
  r.xLo <= p.x and p.x <= r.xHi and r.yLo <= p.y and p.y <= r.yHi

func collectIn(n: Node; r: Rect; axis: int; acc: var seq[Point]) =
  if n.isNil: return
  let c = coord(n.pt, axis)
  let lo = if axis == 0: r.xLo else: r.yLo
  let hi = if axis == 0: r.xHi else: r.yHi
  if lo <= c: collectIn(n.left, r, 1 - axis, acc)      # the left side holds coordinates <= c
  if inside(r, n.pt): acc.add n.pt
  if c <= hi: collectIn(n.right, r, 1 - axis, acc)     # the right side holds coordinates >= c

func inRect*(t: KdTree; r: Rect): seq[Point] {.raises: [].} =
  ## All stored points inside the closed rectangle `r` (duplicates repeated), in lexicographic order.
  collectIn(t.root, r, 0, result)
  result.sort(proc(a, b: Point): int =
    if a < b: -1 elif b < a: 1 else: 0)

func toSeq*(t: KdTree): seq[Point] {.raises: [].} =
  ## Every stored point, in lexicographic order.
  collectIn(t.root, Rect(xLo: -maxCoord, xHi: maxCoord, yLo: -maxCoord, yHi: maxCoord), 0, result)
  result.sort(proc(a, b: Point): int =
    if a < b: -1 elif b < a: 1 else: 0)

func heightOf(n: Node): int =
  if n.isNil: 0 else: 1 + max(heightOf(n.left), heightOf(n.right))

func height*(t: KdTree): int {.raises: [].} =
  heightOf(t.root)

func invariantsHold*(t: KdTree): bool {.raises: [].} =
  ## At every node, the left subtree has axis coordinates <= the node's and the right subtree has
  ## coordinates >= the node's; subtree sizes differ by at most one; the node count is `len`.
  func count(n: Node): int =
    if n.isNil: 0 else: 1 + count(n.left) + count(n.right)
  func within(n: Node; axis: int; bound: float; below: bool): bool =
    if n.isNil: true
    else:
      let c = coord(n.pt, axis)
      (if below: c <= bound else: c >= bound) and within(n.left, axis, bound, below) and
        within(n.right, axis, bound, below)
  func ok(n: Node; axis: int): bool =
    if n.isNil: true
    else:
      let c = coord(n.pt, axis)
      within(n.left, axis, c, true) and within(n.right, axis, c, false) and
        abs(count(n.left) - count(n.right)) <= 1 and ok(n.left, 1 - axis) and ok(n.right, 1 - axis)
  count(t.root) == t.size and ok(t.root, 0)
