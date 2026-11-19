## Bridge: shapes (abstraction) and backends (implementation) vary separately.
##
## The OO pattern splits a hierarchy in two so that N shapes and M backends need N + M definitions,
## not N * M. That only works if the implementation side offers a small, *fixed* set of primitives
## that every abstraction lowers to. Here the only primitive is `line`: a `Backend` is an object
## with one proc field, a `Shape` lowers itself to line `Segment`s (`lower`), and `draw` feeds them
## to the backend. A new shape needs only a `lower` case; a new backend needs only a `line` proc;
## neither touches the other. (If the backend had one primitive per shape kind, adding a shape
## would edit every backend and this would not be a bridge.) Use it when two axes would multiply.
## Circles are approximated by an octagon with integer coordinates.

type
  Point* = object
    x*, y*: int

  Segment* = object
    a*, b*: Point

  Backend* = object
    name*: string
    line*: proc(a, b: Point): string {.noSideEffect, raises: [].}

  ShapeKind* = enum
    skRect, skCircle

  Shape* = object
    case kind*: ShapeKind
    of skRect:
      x*, y*, w*, h*: int
    of skCircle:
      cx*, cy*, r*: int

func pt(x, y: int): Point {.raises: [].} =
  Point(x: x, y: y)

func lower*(s: Shape): seq[Segment] {.raises: [].} =
  ## The shape's closed outline as line segments, independent of any backend.
  var corners: seq[Point] = @[]
  case s.kind
  of skRect:
    corners = @[pt(s.x, s.y), pt(s.x + s.w, s.y), pt(s.x + s.w, s.y + s.h), pt(s.x, s.y + s.h)]
  of skCircle:
    let d = s.r * 7 div 10 # r * cos 45 degrees, rounded down
    corners = @[pt(s.cx + s.r, s.cy), pt(s.cx + d, s.cy + d), pt(s.cx, s.cy + s.r),
                pt(s.cx - d, s.cy + d), pt(s.cx - s.r, s.cy), pt(s.cx - d, s.cy - d),
                pt(s.cx, s.cy - s.r), pt(s.cx + d, s.cy - d)]
  for i in 0 ..< corners.len:
    result.add(Segment(a: corners[i], b: corners[(i + 1) mod corners.len]))

func svgBackend*(): Backend {.raises: [].} =
  Backend(
    name: "svg",
    line: proc(a, b: Point): string {.noSideEffect, raises: [].} =
      "<line x1=" & $a.x & " y1=" & $a.y & " x2=" & $b.x & " y2=" & $b.y & "/>")

func asciiBackend*(): Backend {.raises: [].} =
  Backend(
    name: "ascii",
    line: proc(a, b: Point): string {.noSideEffect, raises: [].} =
      "LINE " & $a.x & "," & $a.y & " " & $b.x & "," & $b.y)

func draw*(s: Shape; b: Backend): seq[string] {.raises: [].} =
  ## One backend call per lowered segment.
  for seg in lower(s):
    result.add(b.line(seg.a, seg.b))

func drawAll*(shapes: seq[Shape]; b: Backend): seq[string] {.raises: [].} =
  for s in shapes:
    result.add(draw(s, b))

func moved*(s: Shape; dx, dy: int): Shape {.raises: [].} =
  ## A shape operation that is independent of every backend.
  case s.kind
  of skRect: Shape(kind: skRect, x: s.x + dx, y: s.y + dy, w: s.w, h: s.h)
  of skCircle: Shape(kind: skCircle, cx: s.cx + dx, cy: s.cy + dy, r: s.r)
