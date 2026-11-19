# Leftist heap

## Intent
A mergeable persistent min-heap. It is a binary tree in heap order whose right spine is never longer than its left spine (the leftist property), so merging two heaps walks only short right spines and every other operation is a merge.

## Use when / avoid when
- Use it when priority queues must be combined often and you want a worst-case O(log n) bound on merge, insert and deleteMin.
- Use it as the first mergeable heap to learn: the code is short and the invariant is easy to state and test.
- Avoid it when constants matter more than the worst case: `pairing_heap` is usually faster in practice.
- Avoid it when you need decrease-key or removal of an arbitrary element: none of the heaps here supports it.

## Nim shape
`LeftistHeap[T]` is a value object with a `ref` root node and a size. A node stores its `rank` (right-spine length). `make` places the child of larger rank on the left, which is what maintains the property. The element type needs `<`. `invariantsHold` checks heap order, the leftist property and the stored ranks, so a test can assert them after every step.

```nim
import std/options
import nimcs/ds/leftist_heap

let a = fromSeq([5, 1, 9])
let b = fromSeq([4, 2])
let both = a.merge(b)
doAssert both.findMin == some(1)
doAssert both.toSortedSeq == @[1, 2, 4, 5, 9]
doAssert both.deleteMin.findMin == some(2)
doAssert a.len == 3                   # a is unchanged
```

The main module is `src/nimcs/ds/leftist_heap.nim`. The left spine can be as long as the heap (descending inserts), so a custom `=destroy` frees nodes with a work list instead of one recursive call per node; a node still shared with another heap is left to its last owner. Measured in a release build with an 8 MB stack: five million descending inserts build and drop without a crash.

The three heap modules (`leftist_heap`, `pairing_heap`, `binomial_heap`) export the same names (`emptyHeap`, `fromSeq`, `insert`, `merge`, ...). With one of them imported, call them as usual. When several are imported, qualify the calls that cannot be told apart by their argument types with the module name, as in the block below (`fromSeq` and `emptyHeap` have no heap argument to choose by).

```nim
import std/options
import nimcs/ds/leftist_heap
import nimcs/ds/pairing_heap

let a = leftist_heap.fromSeq([3, 1, 2])
let b = pairing_heap.fromSeq([6, 5, 4])
doAssert a.findMin == some(1)          # `findMin` is told apart by the argument type
doAssert b.findMin == some(4)
doAssert pairing_heap.emptyHeap[int]().isEmpty
```

## Laws and invariants
- Inserting items and draining with `deleteMin` yields them sorted (DS-LEFTISTHEAP-01).
- `merge` holds exactly the union of both heaps, in either argument order, with the empty heap as identity (DS-LEFTISTHEAP-02).
- `findMin` is the minimum and `deleteMin` removes one copy of it (DS-LEFTISTHEAP-03).
- Updates leave the old heap unchanged (DS-LEFTISTHEAP-04).
- The empty heap has no minimum and `deleteMin` leaves it empty (DS-LEFTISTHEAP-05).
- Heap order, leftist property and ranks hold after every insert and deleteMin (DS-LEFTISTHEAP-06).
- One million descending inserts (a left spine as long as the heap) can be used and dropped without overflowing the stack (DS-LEFTISTHEAP-07).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `merge`, `insert`, `deleteMin` | O(log n) worst case | O(log n) new nodes |
| `findMin`, `len`, `isEmpty` | O(1) | O(1) |
| `toSortedSeq` | O(n log n) | O(n) |

## Pitfalls
Merging by putting the smaller tree on the left unconditionally loses the bound: the right spine can grow to n.

```nim bad
type Node = ref object
  elem: int
  left, right: Node

func merge(a, b: Node): Node =         # no rank: the right spine can grow to n nodes
  if a.isNil: b
  elif b.isNil: a
  elif b.elem < a.elem: Node(elem: b.elem, left: b.left, right: merge(a, b.right))
  else: Node(elem: a.elem, left: a.left, right: merge(a.right, b))
```

Keep the rank comparison; test the invariant instead of trusting the shape.

```nim
import nimcs/ds/leftist_heap

var h = emptyHeap[int]()
for x in [3, 1, 2]:
  h = h.insert(x)
doAssert h.invariantsHold
```

## Related
`pairing_heap.nim`, `binomial_heap.nim`, `cons_list.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `7508271bf7980bd3` Data Structures
