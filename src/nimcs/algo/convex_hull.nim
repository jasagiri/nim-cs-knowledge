## Convex hull of integer points by Andrew's monotone chain.
##
## Sort the points by (x, y), then build the lower chain and the upper chain, popping the last point
## whenever it would make a clockwise or straight turn. The two chains joined are the hull, in
## counter-clockwise order, starting at the lowest-leftmost point, with no three consecutive
## points collinear. The only arithmetic is the cross product of integer vectors, so there is no
## rounding: coordinates are limited to `|x|, |y| <= MaxCoord`, which keeps every cross product
## inside `int` (a difference of coordinates is at most 2e9, a product 4e18, a difference of two
## products 8e18 < 9.2e18). Use it for the outline of a point set, farthest pairs and bounding
## polygons; for floating-point coordinates a robust predicate is needed instead.

import std/algorithm
import nimcs/fp/result

const MaxCoord* = 1_000_000_000   ## coordinates must satisfy |x| <= MaxCoord and |y| <= MaxCoord

type
  Point* = object
    x*, y*: int

  HullError* = enum
    heCoordinateTooLarge   ## a coordinate is outside -MaxCoord .. MaxCoord

func point*(x, y: int): Point {.raises: [].} = Point(x: x, y: y)

func `==`*(a, b: Point): bool {.raises: [].} = a.x == b.x and a.y == b.y

func `<`*(a, b: Point): bool {.raises: [].} = (a.x, a.y) < (b.x, b.y)

func cross*(o, a, b: Point): int {.raises: [].} =
  ## The z-component of (a - o) x (b - o): positive when o -> a -> b turns counter-clockwise, zero
  ## when the three are collinear, negative when clockwise. Exact for coordinates within
  ## `MaxCoord` (GEO-CONVEXHULL-06).
  (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

func inRange(p: Point): bool {.raises: [].} =
  abs(p.x) <= MaxCoord and abs(p.y) <= MaxCoord

func chain(sorted: openArray[Point]): seq[Point] {.raises: [].} =
  ## One monotone chain over points already in ascending order; it keeps only strict left turns.
  for p in sorted:
    while result.len >= 2 and cross(result[^2], result[^1], p) <= 0:
      result.delete(result.high)
    result.add p

func convexHull*(points: openArray[Point]): Result[seq[Point], HullError] {.raises: [].} =
  ## The vertices of the convex hull, counter-clockwise from the smallest (x, y) point, collinear
  ## boundary points left out, duplicates ignored (GEO-CONVEXHULL-01, GEO-CONVEXHULL-02). No
  ## points give no vertices, a single distinct point gives that point, and a collinear set gives
  ## its two endpoints (GEO-CONVEXHULL-04). Fails when a coordinate is beyond `MaxCoord`.
  for p in points:
    if not p.inRange:
      return err(seq[Point], heCoordinateTooLarge)
  var sorted = @points
  sorted.sort
  var unique: seq[Point]
  for p in sorted:
    if unique.len == 0 or unique[^1] != p:
      unique.add p
  if unique.len <= 1:
    return ok(unique, HullError)
  var lower = chain(unique)
  var reversed = unique
  reversed.reverse
  var upper = chain(reversed)
  # Each chain ends where the other begins; drop that repeated end point once.
  lower.delete(lower.high)
  upper.delete(upper.high)
  ok(lower & upper, HullError)
