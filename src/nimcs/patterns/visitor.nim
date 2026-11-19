## Visitor: an object variant plus one exhaustive `case` per operation.
##
## The OO pattern simulates "add an operation to a class hierarchy without editing it" with
## double dispatch (`accept(visitor)` calling `visitCircle`, ...). A closed set of shapes is
## already an object variant here, and each operation is a `func` with a `case` over it: adding an
## operation touches no existing code, adding a shape makes every `case` fail to compile until
## handled. That is the closed-world side of the expression problem.
##
## `ShapeFold[R]` is the same traversal packaged as a first-class value: a record with one proc per
## shape kind, applied bottom-up by `accept` (a catamorphism). It lets a caller build, store, pass
## or choose an operation at run time without writing the recursion, but it does not open the
## shape set: a new `ShapeKind` still means changing `Shape`, `accept` and every `ShapeFold` value.
## If shapes themselves must be open (added by other modules), give each shape value its own
## procs instead of a shared variant (see the details page). Prefer the plain `case`.
## Coordinates are integers, so every law is exact.

import std/options

type
  ShapeKind* = enum
    skRect, skCircle, skGroup

  Shape* = object
    case kind*: ShapeKind
    of skRect:
      x*, y*, w*, h*: int     ## top-left corner and size, w and h >= 0
    of skCircle:
      cx*, cy*, r*: int       ## centre and radius, r >= 0
    of skGroup:
      children*: seq[Shape]

  Bounds* = object
    x0*, y0*, x1*, y1*: int   ## inclusive-exclusive box: x0 <= x1, y0 <= y1

  ShapeFold*[R] = object
    ## A fold as a value: one proc per case; `group` receives the already folded children.
    rect*: proc(x, y, w, h: int): R {.noSideEffect, raises: [].}
    circle*: proc(cx, cy, r: int): R {.noSideEffect, raises: [].}
    group*: proc(children: seq[R]): R {.noSideEffect, raises: [].}

func `==`*(a, b: Bounds): bool {.raises: [].} =
  a.x0 == b.x0 and a.y0 == b.y0 and a.x1 == b.x1 and a.y1 == b.y1

func `$`*(b: Bounds): string {.raises: [].} =
  "[" & $b.x0 & "," & $b.y0 & " .. " & $b.x1 & "," & $b.y1 & ")"

func rect*(x, y, w, h: int): Shape {.raises: [].} =
  ## Negative sizes are treated as zero.
  Shape(kind: skRect, x: x, y: y, w: max(0, w), h: max(0, h))

func circle*(cx, cy, r: int): Shape {.raises: [].} =
  Shape(kind: skCircle, cx: cx, cy: cy, r: max(0, r))

func group*(children: seq[Shape]): Shape {.raises: [].} =
  Shape(kind: skGroup, children: children)

func `==`*(a, b: Shape): bool {.raises: [].} =
  if a.kind != b.kind: return false
  case a.kind
  of skRect: a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
  of skCircle: a.cx == b.cx and a.cy == b.cy and a.r == b.r
  of skGroup:
    if a.children.len != b.children.len: return false
    for i in 0 ..< a.children.len:
      if not (a.children[i] == b.children[i]): return false
    true

func leafCount*(s: Shape): int {.raises: [].} =
  case s.kind
  of skRect, skCircle: result = 1
  of skGroup:
    for c in s.children: result += leafCount(c)

func union(a, b: Bounds): Bounds {.raises: [].} =
  Bounds(x0: min(a.x0, b.x0), y0: min(a.y0, b.y0), x1: max(a.x1, b.x1), y1: max(a.y1, b.y1))

func bounds*(s: Shape): Option[Bounds] {.raises: [].} =
  ## Smallest box containing the shape; `none` for a group with no leaves.
  case s.kind
  of skRect: result = some(Bounds(x0: s.x, y0: s.y, x1: s.x + s.w, y1: s.y + s.h))
  of skCircle: result = some(Bounds(x0: s.cx - s.r, y0: s.cy - s.r, x1: s.cx + s.r, y1: s.cy + s.r))
  of skGroup:
    result = none(Bounds)
    for c in s.children:
      let b = bounds(c)
      if b.isSome:
        result = if result.isSome: some(union(result.get, b.get)) else: b

func footprint*(s: Shape): int {.raises: [].} =
  ## Area of the bounding box (0 for a group with no leaves).
  let b = bounds(s)
  if b.isNone: 0 else: (b.get.x1 - b.get.x0) * (b.get.y1 - b.get.y0)

func translate*(s: Shape; dx, dy: int): Shape {.raises: [].} =
  ## A visitor that returns a new shape of the same form.
  case s.kind
  of skRect: Shape(kind: skRect, x: s.x + dx, y: s.y + dy, w: s.w, h: s.h)
  of skCircle: Shape(kind: skCircle, cx: s.cx + dx, cy: s.cy + dy, r: s.r)
  of skGroup:
    var moved: seq[Shape]
    for c in s.children: moved.add translate(c, dx, dy)
    Shape(kind: skGroup, children: moved)

func render*(s: Shape): string {.raises: [].} =
  ## A textual rendering, one tag per leaf.
  case s.kind
  of skRect: result = "<rect " & $s.x & " " & $s.y & " " & $s.w & " " & $s.h & "/>"
  of skCircle: result = "<circle " & $s.cx & " " & $s.cy & " " & $s.r & "/>"
  of skGroup:
    result = "<g>"
    for c in s.children: result.add render(c)
    result.add "</g>"

func accept*[R](s: Shape; v: ShapeFold[R]): R {.raises: [].} =
  ## Applies a record-of-procs visitor, bottom-up.
  case s.kind
  of skRect: v.rect(s.x, s.y, s.w, s.h)
  of skCircle: v.circle(s.cx, s.cy, s.r)
  of skGroup:
    var results: seq[R]
    for c in s.children: results.add accept(c, v)
    v.group(results)
