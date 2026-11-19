# Segment tree

## Intent
An immutable tree over an array whose every node stores the combination of the elements below it, for a monoid (an associative `combine` with an `identity`). Range queries combine O(log n) stored values; a point update copies one path.

## Use when / avoid when
- Use it for repeated range sums, minima, maxima, gcds or any associative summary over an array that also receives point updates.
- Use it when old versions must stay valid (a persistent segment tree).
- Avoid it when the data never changes: a prefix-sum array answers sums in O(1).
- Avoid it when the operation is not associative: the result would depend on how the tree splits ranges.

## Nim shape
`Monoid[T]` is an object with `identity` and a `combine` proc type marked `noSideEffect` and `raises: []`, built with `initMonoid`. `SegTree[T]` stores the monoid, a root and the size. A node is a `ref` with a value and two children. `query(l, r)` takes a half-open range and returns `Option`: none for an invalid range, the identity for an empty one. `updated(i, x)` returns `Option[SegTree]`. The order of `combine` arguments follows the index order, so non-commutative monoids such as string concatenation work.

```nim
import std/options
import nimcs/ds/segment_tree

let sums = initMonoid(0, proc(a, b: int): int = a + b)
let tree = sums.fromSeq([5, 3, 8, 1, 9])
doAssert tree.query(1, 4) == some(12)       # 3 + 8 + 1
doAssert tree.query(2, 2) == some(0)        # empty range: the identity
doAssert tree.query(0, 9).isNone
let t2 = tree.updated(2, 0).get
doAssert t2.query(1, 4) == some(4)
doAssert tree.query(1, 4) == some(12)       # the old tree is unchanged
doAssert tree.total == 26
```

The main module is `src/nimcs/ds/segment_tree.nim`.

## Laws and invariants
- A range query equals the fold of the corresponding slice (DS-SEGTREE-01).
- Elements are combined in index order, so non-commutative monoids are respected (DS-SEGTREE-02).
- After `updated`, queries see the new value; the old tree is unchanged (DS-SEGTREE-03).
- An empty range returns the identity; invalid ranges return none (DS-SEGTREE-04).
- The empty tree has total equal to the identity and every access is none or empty (DS-SEGTREE-05).
- `total` equals the query over the whole range (DS-SEGTREE-06).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `fromSeq` | O(n) | O(n) |
| `query` | O(log n) | O(log n) stack |
| `updated` | O(log n) | O(log n) new nodes |
| `get`, `total` | O(log n), O(1) | O(1) |

## Pitfalls
Folding the slice for every query is O(n) per query.

```nim bad
import std/options

func rangeSum(xs: seq[int]; l, r: int): Option[int] =
  if l < 0 or r > xs.len or l > r: return none(int)
  var total = 0
  for i in l ..< r:                    # O(r - l) per query
    total += xs[i]
  some(total)
```

Precompute the tree once and answer in O(log n).

```nim
import std/options
import nimcs/ds/segment_tree

let minimum = initMonoid(high(int), proc(a, b: int): int = min(a, b))
let tree = minimum.fromSeq([4, 2, 7, 1, 8])
doAssert tree.query(0, 3) == some(2)
doAssert tree.query(2, 5) == some(1)
```

## Related
`pvector.nim`, `union_find.nim`, `rb_tree.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `b8f40165091faa5d` CSES Problem Set
- `7508271bf7980bd3` Data Structures
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
