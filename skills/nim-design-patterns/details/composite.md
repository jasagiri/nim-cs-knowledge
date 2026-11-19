# Composite

## Intent
Treat one object and a group of objects uniformly in a part-whole structure (a file or a directory of
files). The OO pattern gives leaf and group a shared interface. In Nim the tree is **one object
variant** whose group case holds a `seq` of the same type (no `ref` needed), and every operation on
the whole tree is an instance of a single `fold`.

## Use when / avoid when
- Use for trees where a node is either a leaf or a list of nodes: file systems, UI trees,
  expressions, menus.
- Write a new operation as a choice of the two arguments of `fold`, not as a new recursive proc, so
  the recursion exists once.
- Avoid when the structure is a graph with sharing or cycles: a tree variant would duplicate or loop.
- Avoid a base class with `add`/`remove` on leaves; the variant makes illegal calls unrepresentable.

## Nim shape
`Entry` is either `ekFile` with a size or `ekDir` with children. `fold` takes one function for
leaves and one for groups, where the group function receives the already-folded children.

Module: `src/nimcs/patterns/composite.nim`.

```nim
import nimcs/patterns/composite

let tree = dir("root", @[
  file("a", 10),
  dir("sub", @[file("b", 20), file("c", 30)]),
  dir("empty", @[])])

doAssert tree.totalSize == 60
doAssert tree.fileCount == 3
doAssert tree.depth == 2
doAssert tree.leafSizes == @[10, 20, 30]

# A new operation is a new pair of functions, not a new recursion.
let names = tree.fold(
  proc(name: string; size: int): seq[string] {.noSideEffect, raises: [].} = @[name],
  proc(name: string; parts: seq[seq[string]]): seq[string] {.noSideEffect, raises: [].} =
    var all: seq[string] = @[]
    for p in parts: all.add(p)
    all)
doAssert names == @["a", "b", "c"]
```

## Laws and invariants
- The total size of a tree is the sum of the sizes of its leaves (GOF-COMPOSITE-01).
- `fileCount` equals the number of leaves and `leafSizes` lists them left to right
  (GOF-COMPOSITE-02).
- Adding an empty directory, or nesting children in one more directory, changes neither total nor
  count: the combine step is associative with an identity (GOF-COMPOSITE-03).
- `depth` of a file is 0 and of a directory one more than its deepest child (GOF-COMPOSITE-04).

## Complexity
`fold` visits each node once: O(n) time. Intermediate results of children are kept in a `seq`, so
extra space is O(width) per level plus recursion depth O(height). Very deep trees can overflow the
stack; flatten with an explicit work list if depth is unbounded.

## Pitfalls
Writing the recursion again for every operation, with slightly different traversal order and base
cases.

```nim bad
import nimcs/patterns/composite

func totalSize2(e: Entry): int =
  case e.kind
  of ekFile: e.size
  of ekDir:
    for c in e.children:
      result += totalSize2(c)

func fileCount2(e: Entry): int =
  case e.kind
  of ekFile: 1
  of ekDir:
    for c in e.children:
      result += fileCount2(c)
```

Fold once and give each operation two small functions (see `totalSize` and `fileCount` in the module).
The `case` on `e.kind` has no `else`, so adding a node kind makes every fold fail to compile until handled.

```nim
import nimcs/patterns/composite

let t = dir("d", @[file("x", 1), file("y", 2)])
let doubled = t.fold(
  proc(name: string; size: int): int {.noSideEffect, raises: [].} = size * 2,
  proc(name: string; parts: seq[int]): int {.noSideEffect, raises: [].} =
    var s = 0
    for p in parts: s += p
    s)
doAssert doubled == 2 * t.totalSize
```

## Related
- `decorator.md` (wrapping one node), `flyweight.md` (sharing leaves),   separating traversal from structure).

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
