# Bridge

## Intent
Two dimensions vary independently (shapes and rendering backends). With inheritance that is a class
per pair. The OO pattern splits them: an abstraction holds a reference to an implementation
interface. The saving (N + M definitions instead of N x M) exists only if the implementation side
is a small **fixed** set of primitives that every abstraction lowers to. Here the primitive is a
single `line`: a `Backend` is an object with one proc field, a `Shape` lowers itself to line
segments (`lower`), and `draw` feeds the segments to the backend. A new shape adds one `lower` case
and touches no backend; a new backend adds one `line` proc and touches no shape.

## Use when / avoid when
- Use when two independent axes would otherwise multiply (shape x backend, message x transport,
  report x output format) **and** you can name a small primitive set that sits between them.
- Use a generic proc over the backend type when the backend is fixed at compile time and you want
  static dispatch; the record of procs is for choosing at run time.
- Avoid giving the backend one primitive per shape kind (`rect`, `circle`, ...): then every new
  shape edits every backend, the axes are coupled, and it is not a bridge.
- Avoid when one axis has a single value: a plain proc is enough.

## Nim shape
`lower` has no backend argument and `Backend` knows nothing of shape kinds, so the only thing the
axes share is `Point`, `Segment` and the `line` signature. The cost of the design is that a backend
cannot use a native circle or rectangle primitive; if it must, add a second primitive deliberately
and give every backend a default for it.

Module: `src/nimcs/patterns/bridge.nim`.

```nim
import nimcs/patterns/bridge

let r = Shape(kind: skRect, x: 1, y: 2, w: 3, h: 4)
doAssert draw(r, asciiBackend()) == @[
  "LINE 1,2 4,2", "LINE 4,2 4,6", "LINE 4,6 1,6", "LINE 1,6 1,2"]
doAssert draw(r, svgBackend()).len == 4
doAssert draw(r.moved(10, 0), asciiBackend())[0] == "LINE 11,2 14,2"

# A backend written in the client: no change to Shape or to the module.
let dots = Backend(name: "dots", line: proc(a, b: Point): string {.noSideEffect, raises: [].} =
  $a.x & "." & $a.y)
doAssert draw(r, dots) == @["1.2", "4.2", "4.6", "1.6"]
```

The static-dispatch form, with the backend as a generic parameter:

```nim
type
  Text = object
  Loud = object

func emit(_: Text; s: string): string = s
func emit(_: Loud; s: string): string = s & "!"

func announce[B](b: B; names: seq[string]): seq[string] =
  for n in names:
    result.add(b.emit("hi " & n))

doAssert announce(Loud(), @["a"]) == @["hi a!"]
doAssert announce(Text(), @["a"]) == @["hi a"]
```

## Laws and invariants
- `draw` is exactly the backend's `line` applied to each segment of `lower(shape)`, in order
  (GOF-BRIDGE-01).
- `drawAll` of a concatenation is the concatenation of the `drawAll`s, for every backend
  (GOF-BRIDGE-02).
- `lower` takes no backend and yields a closed outline (4 segments for a rectangle, 8 for a
  circle); a backend defined outside the module draws every shape; drawing a moved shape equals
  drawing the shifted segments (GOF-BRIDGE-03).

## Complexity
`draw` is O(segments of the shape) plus the backend's cost per segment; `drawAll` is O(total
segments). Each backend call is an indirect call. Circles are an octagon: precision is traded for
the fixed primitive.

## Pitfalls
A backend with one primitive per shape kind re-couples the axes: N shapes x M backends definitions.

```nim bad
type Backend = object
  rect: proc(x, y, w, h: int): string
  circle: proc(cx, cy, r: int): string
  # adding a triangle means adding a field here and editing every backend
```

Keep the interface to a primitive every shape can lower to (see `Backend.line` above).

## Related
- `abstract_factory.md`, `adapter.md`, `decorator.md`, `strategy.md` (a proc value for one varying behaviour).

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
