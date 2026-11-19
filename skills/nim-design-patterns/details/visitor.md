# Visitor

## Intent
Add new operations to a family of types without editing them. The OO pattern simulates this with double dispatch: `accept(visitor)` calls `visitCircle`, `visitRect`, and so on. A closed set of shapes is already an object variant in Nim, so each operation is a `func` with an exhaustive `case`, and double dispatch is not needed. This is the closed-world side of the expression problem: adding an operation touches no existing code, adding a shape makes every `case` fail to compile until it is handled.

## Use when / avoid when
- Use the plain `case` function when the set of shapes is fixed (or changes rarely) and operations keep growing: bounds, rendering, counting, transformations.
- Use `ShapeFold` (a fold packaged as a first-class value, applied by `accept`) when an operation is built, stored or chosen at run time, or when callers should not write the recursion themselves. It does not open the shape set: a new shape still means changing `Shape`, `accept` and every `ShapeFold` value.
- If the set of shapes must be open (other modules add shapes), do not use a shared variant: give each shape value its own procs (the last block of "Nim shape").
  Export the record and its fields (`OpenShape* = object` with `area*`, `label*`) so a constructor in
  another module can build one; adding a kind is then a new module, with no edit to the first.
- Avoid when the structure is not a tree of a closed set of kinds: use `iterator_pattern` for plain traversal.
- Avoid a class hierarchy with `method` and double dispatch; Nim has no need for it.

## Nim shape
The module is `src/nimcs/patterns/visitor.nim`. `Shape` is a variant: rectangle, circle, group of shapes (the `seq` provides the recursion). `leafCount`, `bounds`, `footprint`, `translate` and `render` are visitors written as `case`. `ShapeFold[R]` is a record of three procs (rect, circle, group-of-results) and `accept(shape, fold)` applies it bottom-up.

```nim
import std/options
import nimcs/patterns/visitor

let s = group(@[rect(0, 0, 4, 2), circle(10, 10, 3)])
doAssert s.leafCount == 2
doAssert s.bounds.get == Bounds(x0: 0, y0: 0, x1: 13, y1: 13)
doAssert s.translate(1, 1).bounds.get.x0 == 1
doAssert s.render == "<g><rect 0 0 4 2/><circle 10 10 3/></g>"
```

A new operation written outside the module as a fold; the caller writes no recursion:

```nim
import nimcs/patterns/visitor

let totalWidth = ShapeFold[int](
  rect: proc(x, y, w, h: int): int {.noSideEffect, raises: [].} = w,
  circle: proc(cx, cy, r: int): int {.noSideEffect, raises: [].} = 2 * r,
  group: proc(cs: seq[int]): int {.noSideEffect, raises: [].} =
    for c in cs: result += c)

let s = group(@[rect(0, 0, 4, 2), circle(10, 10, 3), group(@[rect(0, 0, 1, 1)])])
doAssert s.accept(totalWidth) == 11
```

When shapes are open, each shape carries its operations as procs, so a new kind is a new value and no existing code changes (a new operation then means a new field everywhere):

A constructor that can be given an impossible shape (a negative side, three lengths that break the
triangle inequality) returns `Option[OpenShape]` or a `Result`, so no closure ever computes from
bad input (Heron's formula takes the square root of a negative number and gives NaN). `not (x > 0.0)`
also rejects NaN. Areas are `float`, compared with a tolerance:

```nim
import std/[math, options]

type
  OpenShape = object
    area: proc(): float {.noSideEffect, raises: [].}
    label: proc(): string {.noSideEffect, raises: [].}

func square(side: float): Option[OpenShape] {.raises: [].} =
  if not (side > 0.0): return none(OpenShape)
  some OpenShape(area: proc(): float {.noSideEffect, raises: [].} = side * side,
                 label: proc(): string {.noSideEffect, raises: [].} = "square")

func triangle(a, b, c: float): Option[OpenShape] {.raises: [].} =
  if not (a > 0.0 and b > 0.0 and c > 0.0 and a + b > c and b + c > a and a + c > b):
    return none(OpenShape)
  let s = (a + b + c) / 2
  some OpenShape(area: proc(): float {.noSideEffect, raises: [].} = sqrt(s * (s - a) * (s - b) * (s - c)),
                 label: proc(): string {.noSideEffect, raises: [].} = "triangle")

let shapes = [square(3.0).get, triangle(3.0, 4.0, 5.0).get]
doAssert abs(shapes[0].area() + shapes[1].area() - 15.0) < 1e-9
doAssert shapes[1].label() == "triangle"
doAssert triangle(1.0, 1.0, 5.0).isNone and square(-1.0).isNone
```

## Laws and invariants
- A direct `case` and a `ShapeFold` through `accept` agree for the same operation (GOF-VISITOR-01).
- Translating moves the bounds by the offset (GOF-VISITOR-02) and keeps leaf count and footprint (GOF-VISITOR-03).
- Two translations equal one translation by the sum (GOF-VISITOR-04); translating by zero changes nothing (GOF-VISITOR-05).
- A group's bounds contain each child's bounds (GOF-VISITOR-06); concrete shapes give the documented values (GOF-VISITOR-07).

## Complexity
Each visitor is O(n) in the number of nodes and uses stack depth equal to the nesting depth. `translate` allocates a new tree (O(n)); `render` builds one string by appending (linear in output size for typical shapes). `accept` allocates one result `seq` per group.

## Pitfalls
Visiting with `method` and a `visitor` object per operation, which needs a base class, `ref` objects and a case for every combination:

```nim bad
type
  Shape = ref object of RootObj
  Circle = ref object of Shape
  Visitor = ref object of RootObj

method accept(s: Shape; v: Visitor) {.base.} = discard
method accept(s: Circle; v: Visitor) = visitCircle(v, s)   # one such method per shape
```

Fix: `case s.kind` in a `func` per operation, or `ShapeFold` when an operation must be a value. When the shapes themselves must be open, use per-value procs (above). Using `else` in the `case` defeats the point (a new shape is then silently mishandled); list every kind. A fold must treat the empty group deliberately (here `bounds` returns `none`), not return a made-up box.

## Related
- `interpreter.nim` (an expression tree with several interpretations)
- `iterator_pattern.nim` (traversal without computing a result)
- `strategy.nim` (a record of procs is a bundle of strategies)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
