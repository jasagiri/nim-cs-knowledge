# Red-black tree

## Intent
A balanced binary search tree kept balanced by node colours: the root is black, a red node has no red child, and every path from a node to a leaf has the same number of black nodes. Persistent insertion copies one path and rebalances locally.

## Use when / avoid when
- Use `RbMap` or `RbSet` when you need ordered iteration, a deterministic order or sorted output together with fast lookup.
- Use it when old versions of the map must stay valid.
- Avoid it for lookup-only maps with large keys sets where order does not matter: `hamt` has shallower paths.
- Avoid it if you need deletion in this package: it is not provided. Rebuild from `toSeq` without the key, or use `hamt` (which has `remove`).

## Nim shape
`RbMap[K, V]` is a value object (`root`, `size`) over `ref` nodes with a `red` flag. `ins` walks down and `balance` repairs a red-red violation by rotating the four possible shapes into one. `put` paints the root black. The key type needs `<`; equal keys are keys where neither is smaller. `RbSet[K]` is a map whose value is an empty object. `invariantsHold` checks the colour rules, that every key lies strictly between the keys of its nearest ancestors on each side (the full search order, not only parent against child) and the stored size, and `height` supports the logarithmic-height test.

```nim
import std/options
import nimcs/ds/rb_tree

let m = emptyMap[string, int]().put("b", 2).put("a", 1).put("b", 3)
doAssert m.get("b") == some(3)
doAssert m.get("z").isNone
doAssert m.toSeq == @[("a", 1), ("b", 3)]      # key order, no hash order
doAssert m.invariantsHold

let s = fromSeq([5, 3, 5, 1])
doAssert s.toSeq == @[1, 3, 5]
doAssert 3 in s
```

The main module is `src/nimcs/ds/rb_tree.nim`. `graft` is a low-level constructor that joins two maps under a node of a chosen colour without any rebalancing; it exists to rebuild a stored tree or to build a deliberately broken one and watch `invariantsHold` reject it.

## Laws and invariants
- A set built from any keys lists the sorted distinct keys (DS-RBTREE-01).
- A map returns the last value put for each key and none for absent keys, with the right size (DS-RBTREE-02).
- The red-black invariants hold after every insert, for any insertion order (DS-RBTREE-03).
- Inserting sorted keys still gives logarithmic height (DS-RBTREE-04).
- `put` leaves the old map unchanged (DS-RBTREE-05).
- The empty map has no keys and satisfies the invariants (DS-RBTREE-06).
- Including a key already in a set changes neither content nor size (DS-RBTREE-07).
- The invariant checker rejects a tree in which a key lies on the wrong side of an ancestor, not only of its parent (DS-RBTREE-08).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `put`, `get`, `contains`, `incl` | O(log n) worst case | `put`: O(log n) new nodes |
| `toSeq` | O(n) | O(n) |
| `len` | O(1) | O(1) |

Height is at most 2 log2(n + 1).

## Pitfalls
An unbalanced persistent search tree degrades to a list on sorted input.

```nim bad
type Node = ref object
  key: int
  left, right: Node

func insert(n: Node; k: int): Node =    # plain BST insert: sorted input gives height n
  if n.isNil: Node(key: k)
  elif k < n.key: Node(key: n.key, left: insert(n.left, k), right: n.right)
  else: Node(key: n.key, left: n.left, right: insert(n.right, k))
```

Use the balanced tree and check its height on sorted input.

```nim
import nimcs/ds/rb_tree

var m = emptyMap[int, int]()
for i in 1 .. 255:
  m = m.put(i, i)
doAssert m.height <= 16
```

## Related
`hamt.nim`, `trie.nim`, `union_find.nim`, `cons_list.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `7508271bf7980bd3` Data Structures
- `ed8c50dad686e4d3` Elementary Algorithms
- `fc4e34ece13d1024` Open Data Structures: An Introduction
