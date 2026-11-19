# Skew-binary random-access list

## Intent
A persistent sequence that is as cheap as a cons list at the front and still supports indexing. It is a short list of complete binary trees whose sizes are 2^k - 1; because the sizes follow the skew-binary number system, adding an element never causes a long carry.

## Use when / avoid when
- Use it for a stack that also needs `get(i)` and functional `updated(i, x)`, for example environments, de Bruijn indices or functional arrays that grow at the front.
- Avoid it when you append at the back: use `pvector`.
- Avoid it when you never index: `cons_list` is simpler.

## Nim shape
`SkewList[T]` holds `spine: ConsList[Entry[T]]` and a size; an `Entry` is a weight and a tree. `cons` links the first two trees when their weights are equal, otherwise it starts a one-element tree. `tail` splits the first tree into its two halves. `get` and `updated` first find the tree by subtracting weights, then descend inside it. Out-of-range access returns `none`.

```nim
import std/options
import nimcs/ds/skew_list

let xs = fromSeq([10, 20, 30, 40, 50])
doAssert xs.get(3) == some(40)
doAssert xs.get(5).isNone
let ys = xs.updated(1, 99).get
doAssert ys.toSeq == @[10, 99, 30, 40, 50]
doAssert xs.toSeq == @[10, 20, 30, 40, 50]
doAssert xs.cons(0).tail.toSeq == xs.toSeq
doAssert xs.invariantsHold
```

The main module is `src/nimcs/ds/skew_list.nim`.

## Laws and invariants
- Built by consing, `toSeq` returns the items in order and `get(i)` is the i-th item; out of range is none (DS-SKEWLIST-01).
- `cons` then `tail` is the identity, and the head is the consed element (DS-SKEWLIST-02).
- `updated(i, x)` changes only index i and leaves the original unchanged (DS-SKEWLIST-03).
- After any sequence of `cons` and `tail`, weights are 2^k - 1, non-decreasing with at most the first two equal, they sum to the length, and the spine stays logarithmic (DS-SKEWLIST-04).
- The empty list has no head, its tail is empty and every index is out of range (DS-SKEWLIST-05).
- Every index of a 1000-element list finds its element (DS-SKEWLIST-06).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `cons`, `head`, `tail` | O(1) worst case | O(1) new |
| `get`, `updated` | O(log n) | `updated`: O(log n) new nodes |
| `toSeq`, `fromSeq` | O(n) | O(n) |

## Pitfalls
Indexing a cons list is O(n); a loop over all indices is quadratic.

```nim bad
import std/options
import nimcs/ds/cons_list

func nth(xs: ConsList[int]; i: int): Option[int] =
  var cur = xs
  for _ in 0 ..< i:
    cur = cur.tail                     # walks i links on every call
  cur.head
```

Use the skew list when you index.

```nim
import std/options
import nimcs/ds/skew_list

let xs = fromSeq([1, 2, 3])
doAssert xs.get(2) == some(3)          # O(log n) instead of O(n)
```

## Related
`cons_list.nim`, `pvector.nim`, `deque.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `e443a6b88b011f39` Purely Functional Data Structures
