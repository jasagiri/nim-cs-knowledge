# Banker's queue

## Intent
A first-in-first-out queue with no mutation, built from two persistent lists: the front list holds what leaves next, the rear list holds what arrived last, in reverse. When the rear grows longer than the front, one reversal moves it to the front.

## Use when / avoid when
- Use it for breadth-first search, work lists and producer/consumer pipelines in functional code where each version of the queue is used once.
- Use it when you need `len` in O(1) alongside push and pop.
- Avoid it when the same old version is popped repeatedly (persistent use): the reversal cost is paid again each time and the amortized bound no longer holds. Use `deque` for double-ended needs, or a real-time queue (lazy rotations) for a worst-case bound.
- Avoid it when the queue is a priority queue: use `pairing_heap`.

## Nim shape
`BankersQueue[T]` holds `front`, `rear` and their lengths. The invariant `lenRear <= lenFront` is restored by `rebalanced` after every push and pop, so the front is empty only when the queue is empty and `peek` is O(1). `pop` of the empty queue returns the empty queue; `peek` returns `Option`.

```nim
import std/options
import nimcs/ds/bankers_queue

var q = emptyQueue[int]()
for i in 1 .. 3:
  q = q.push(i)
doAssert q.peek == some(1)
let rest = q.pop
doAssert rest.toSeq == @[2, 3]
doAssert q.toSeq == @[1, 2, 3]       # the old queue is untouched
```

The main module is `src/nimcs/ds/bankers_queue.nim`; it builds on `cons_list`.

## Laws and invariants
- Pushing items in order and popping until empty returns them in the same order (DS-BANKERSQUEUE-01).
- The empty queue has no `peek` and popping it leaves it empty (DS-BANKERSQUEUE-02).
- `push` and `pop` leave the queue they started from unchanged (DS-BANKERSQUEUE-03).
- Any mix of pushes and pops matches a `seq` model in contents, length and `peek` (DS-BANKERSQUEUE-04).
- A queue of thousands of elements fills and drains in order (DS-BANKERSQUEUE-05).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `push`, `pop` | O(1) amortized (worst case O(n) for one reversal) | O(1) new, O(n) on reversal |
| `peek`, `len`, `isEmpty` | O(1) | O(1) |
| `toSeq` | O(n) | O(n) |

Amortization holds for ephemeral use: each version used at most once.

## Pitfalls
Keeping a front-only list and appending at the back makes every push O(n).

```nim bad
import nimcs/ds/cons_list

func pushBack(q: ConsList[int]; x: int): ConsList[int] =
  q.append(fromSeq([x]))             # copies the whole queue on every push
```

Keep the rear separately and reverse it only when the front runs out; `BankersQueue` does exactly that.

```nim
import nimcs/ds/bankers_queue

let q = emptyQueue[int]().push(1).push(2)
doAssert q.toSeq == @[1, 2]
```

## Related
`cons_list.nim`, `deque.nim`, `pairing_heap.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `e443a6b88b011f39` Purely Functional Data Structures
