# Cons list

## Intent
A persistent singly linked list: `cons` puts one element in front of an existing list without touching it, so any number of lists can share the same tail. It is the simplest persistent structure and the base of the queues and heaps in this package.

## Use when / avoid when
- Use it as a functional stack, as the accumulator of a recursive algorithm, or whenever you "build up, then reverse".
- Use it when old versions must stay valid and sharing tails saves memory.
- Avoid it for indexed access or appending at the end: use `skew_list` (indexing at the front), `pvector` (indexing and push at the back) or `bankers_queue` (FIFO).
- Avoid it when you need indexed access to long lists: use `pvector`. Length alone is not a problem: a custom `=destroy` frees the chain in a loop (measured in a release build with an 8 MB stack: 5 x 10^7 nodes build and drop without a crash; the default recursive destructor crashed between 2 x 10^5 and 5 x 10^5).

## Nim shape
`ConsList[T]` is a value `object` wrapping a `ref` to an immutable node; the empty list is the default value, so there is no `nil` for callers to check. Every public routine is a `func` with `{.raises: [].}`. Absence is `Option`: `head` returns `Option[T]`, and `tail` of the empty list is the empty list.

```nim
import std/options
import nimcs/ds/cons_list

let base = fromSeq([2, 3])
let a = base.cons(1)
let b = base.cons(9)
doAssert a.toSeq == @[1, 2, 3]
doAssert b.toSeq == @[9, 2, 3]
doAssert a.tail.sharesNode(b.tail)    # the same nodes in memory
doAssert base.head == some(2)
doAssert emptyList[int]().head.isNone
```

The main module is `src/nimcs/ds/cons_list.nim`. `isUnshared(xs)` says whether anything else still reaches the first cell; the structures built on this list use it to tear themselves down iteratively. A cell that another list still shares is left to its last owner. Name the iteration with `items(xs)` inside generic code you write on top of it; a plain `for x in xs` in a generic routine is looked up where the routine is instantiated and fails there when `cons_list` is not imported.

## Laws and invariants
- `xs.cons(x).head == some(x)` and `xs.cons(x).tail == xs`, sharing the node of `xs` (DS-CONSLIST-01).
- The empty list has no head, its tail is empty and its length is 0 (DS-CONSLIST-02).
- `xs.reverse.reverse == xs` and `reverse` agrees with reversing a `seq` (DS-CONSLIST-03).
- `append` is associative with the empty list as identity and agrees with `seq` concatenation (DS-CONSLIST-04).
- `a.append(b)` shares all of `b` (DS-CONSLIST-05).
- Consing never changes the list it started from (DS-CONSLIST-06).
- `foldLeft`, `map` and `len` agree with the `seq` versions (DS-CONSLIST-07).
- Dropping a list of three million nodes, or a long list whose tail another list shares, does not overflow the stack (DS-CONSLIST-08).
- `isUnshared` is false for a list another list was consed onto and true for a fresh or empty one (DS-CONSLIST-09).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `cons`, `head`, `tail` | O(1) | O(1) new |
| `len`, `toSeq`, `reverse`, `map`, `foldLeft` | O(n) | O(n) for the ones that build a list |
| `append(a, b)` | O(len a) | O(len a) new, `b` shared |

## Pitfalls
Appending one element at a time with `append` copies the growing left list every time and is quadratic.

```nim bad
import nimcs/ds/cons_list

func build(n: int): ConsList[int] =
  var acc = emptyList[int]()
  for i in 0 ..< n:
    acc = acc.append(fromSeq([i]))    # O(len acc) per step: O(n^2) overall
  acc
```

Cons in front and reverse once at the end.

```nim
import nimcs/ds/cons_list

func build(n: int): ConsList[int] =
  var acc = emptyList[int]()
  for i in 0 ..< n:
    acc = acc.cons(i)                 # O(1) per step
  acc.reverse

doAssert build(4).toSeq == @[0, 1, 2, 3]
```

## Related
`bankers_queue.nim`, `deque.nim`, `skew_list.nim`, `pairing_heap.nim`, `binomial_heap.nim`, `zipper.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `21a878bd1e78232f` A Tour of Scala - an interactive scala tutorial
- `55dcf27597d5d92a` Google's Common Lisp Style Guide
- `4b0dad6bfcfbe438` Lisp Tutorial
- `6a3d106c56e40887` OCaml From the Ground Up
- `9e0afdfae6157d74` OCaml from the Very Beginning
- `aeeff780b0fc104f` Practical Common Lisp
- `8c7c3db029a468ec` Programming in Scala, First Edition
- `04c90d5ac6a2d0db` Real World OCaml
