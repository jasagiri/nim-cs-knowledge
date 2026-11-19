# Persistent union-find

## Intent
Disjoint sets with `find` and `union`, built on persistent maps so that `union` returns a new structure and earlier versions stay valid. It answers "are a and b in the same group?" while allowing you to go back.

## Use when / avoid when
- Use it for backtracking search, speculative merges, undo, or any algorithm that revisits earlier states (offline connectivity with rollback, constraint solving).
- Use it for Kruskal-style algorithms when you need to keep intermediate forests.
- Avoid it when only the latest state matters and speed counts: use the imperative array version with path compression (near-constant amortized time). This one pays an O(log n) map lookup per step and, without compression, an O(log n) path.

## Nim shape
`UnionFind` holds `parent` and `rank` as `RbMap[int, int]` and a component count. Unknown elements are their own representative, so `find` is total. `union` registers both elements, finds the roots and links the root of lower rank under the other (union by rank), which bounds a root path by log2 of the element count. `findCompress` returns the root and a new structure with the path shortened; you only profit if you keep the returned structure. The trade-off against the imperative version: an array with path compression mutates in place and loses the old state; here nothing is overwritten, each update copies O(log n) map nodes, and compression must be threaded through your code.

```nim
import nimcs/ds/union_find

let u0 = emptyUnionFind()
let u1 = u0.union(1, 2).union(3, 4)
let u2 = u1.union(2, 3)
doAssert u1.components == 2
doAssert u2.components == 1
doAssert u2.same(1, 4)
doAssert not u1.same(1, 4)            # the earlier version is still valid
let (root, shorter) = u2.findCompress(4)
doAssert root == u2.find(4)
doAssert shorter.pathLength(4) <= 1
```

The main module is `src/nimcs/ds/union_find.nim`; it builds on `rb_tree`.

## Laws and invariants
- `same` agrees with a naive label-propagation reference (DS-UNIONFIND-01).
- `same` is reflexive, symmetric and transitive (DS-UNIONFIND-02).
- Repeating a union changes neither the relation nor the component count (DS-UNIONFIND-03).
- `union` leaves the earlier version answering as before (DS-UNIONFIND-04).
- With union by rank, a root path has at most log2(n) links (DS-UNIONFIND-05).
- `findCompress` returns the same representative, a path of at most one link, and the same component count (DS-UNIONFIND-06).
- An unknown element is its own set and `find` does not register it (DS-UNIONFIND-07).
- With random unions over many elements every root path stays within floor(log2 of the element count) (DS-UNIONFIND-08).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `find`, `same` | O(log n) links, each an O(log n) map lookup | O(1) |
| `union`, `add` | O(log n) plus the two finds | O(log n) new map nodes |
| `findCompress` | O(path length x log n) | new nodes for the compressed links |

## Pitfalls
Linking roots without comparing ranks lets a chain form, and `find` becomes O(n).

```nim bad
import std/tables

func linkBadly(parent: Table[int, int]; a, b: int): Table[int, int] =
  result = parent                      # always hangs a under b: 0->1->2->3... is a chain
  result[a] = b
```

Link by rank, as `union` does, and check `pathLength` in a test.

```nim
import nimcs/ds/union_find

var u = emptyUnionFind()
for i in 0 ..< 15:
  u = u.union(i, i + 1)
doAssert u.pathLength(0) <= 4
```

## Related
`rb_tree.nim`, `hamt.nim`, `segment_tree.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `473f0313d72c526b` Algorithms, 4th Edition
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `7508271bf7980bd3` Data Structures
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `254fe28ac0bfd53e` Last Moment DSA Sheet(79) – Ace Interviews
- `b8cf0456394ed527` Learn Programming with OCaml: Algorithms and Data Structures
- `6f359c1814ec309e` Princeton University Algorithms, Part 1
