# Deque

## Intent
A double-ended queue with no mutation. Two lists hold the two ends; whenever one list becomes more than twice as long as the other (plus one), the elements are split evenly again so neither end can run dry for long.

## Use when / avoid when
- Use it when elements enter or leave at both ends: sliding windows, undo/redo buffers, palindromes, 0-1 BFS.
- Use it when each version is used once (ephemeral use): the O(n) split happens only after Omega(n) cheap operations, so the amortized cost is O(1).
- Do not rely on the bound when one old version is pushed to or popped from again and again: from a version just short of a rebalance every operation costs O(n). Use a real-time deque (lazy rotations) when you need a worst-case bound.
- Avoid it when only one end pops: `bankers_queue` is simpler.
- Avoid it for indexed access: use `pvector` or `skew_list`.

## Nim shape
`Deque[T]` has `front`, `rear` (stored reversed) and both lengths. `pushFront`/`pushBack` cons onto a list; `popFront`/`popBack` drop from a list; `balanced` rebuilds from `toSeq` when the length ratio exceeds `balanceFactor` (2). Empty-case answers are values: `peekFront` and `peekBack` return `Option`, popping the empty deque returns the empty deque.

```nim
import std/options
import nimcs/ds/deque

let d = emptyDeque[int]().pushBack(2).pushBack(3).pushFront(1)
doAssert d.toSeq == @[1, 2, 3]
doAssert d.peekFront == some(1)
doAssert d.peekBack == some(3)
doAssert d.popBack.toSeq == @[1, 2]
doAssert d.len == 3                   # d itself is unchanged
```

The main module is `src/nimcs/ds/deque.nim`.

## Laws and invariants
- Pushing at the back keeps order: `fromSeq(xs).toSeq == xs` (DS-DEQUE-01).
- Pushing at the front reverses order (DS-DEQUE-02).
- Any mix of pushes and pops at both ends matches a `seq` model in contents, ends and length (DS-DEQUE-03).
- Operations leave the old deque unchanged (DS-DEQUE-04).
- The empty deque has no ends and popping it leaves it empty (DS-DEQUE-05).
- Thousands of pushes at one end drained from the other keep order (DS-DEQUE-06).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `pushFront`, `pushBack`, `popFront`, `popBack` | O(1) amortized for ephemeral use; O(n) worst case on a rebalance, and a persistent program can hit that worst case on every call | O(1) new, O(n) on rebalance |
| `peekFront`, `peekBack`, `len` | O(1) | O(1) |

## Pitfalls
Popping from the end of a plain list is O(n).

```nim bad
import nimcs/ds/cons_list

func popLast(xs: ConsList[int]): ConsList[int] =
  xs.reverse.tail.reverse             # two full copies for one pop
```

A deque keeps both ends within reach.

```nim
import nimcs/ds/deque

let d = fromSeq([1, 2, 3]).popBack
doAssert d.toSeq == @[1, 2]
```

## Related
`cons_list.nim`, `bankers_queue.nim`, `skew_list.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `7508271bf7980bd3` Data Structures
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `04a7132319218b7b` Matters Computational: Ideas, Algorithms, Source Code
- `fc4e34ece13d1024` Open Data Structures: An Introduction
- `e443a6b88b011f39` Purely Functional Data Structures
