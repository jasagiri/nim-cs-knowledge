## Persistent singly linked list (a "cons list").
##
## Every update returns a new list and leaves the old one valid; lists share their tails through
## `ref` to immutable nodes, so `xs.cons(x)` is O(1) in time and space and two lists built from the
## same `xs` share all of `xs`. Use it as a stack, as the spine of recursive algorithms, or as the
## building block of the queues and heaps in this package; reach for `seq` when you need indexed
## access or cache-friendly scans.

import std/options

type
  NodeObj[T] = object
    head: T
    tail: ConsList[T]
  Node[T] = ref NodeObj[T]
  ConsList*[T] = object
    ## The empty list is `default(ConsList[T])`; there is no nil to check at the call site.
    node: Node[T]

proc `=destroy`[T](n: var NodeObj[T]) =
  ## Frees a long chain in a loop. The default destructor would recurse once per node and
  ## overflow the stack on a list of a few hundred thousand nodes. A node that another list still
  ## reaches (`isUniqueRef` is false) is left alone: its last owner frees it.
  var next = move(n.tail.node)
  while not next.isNil and isUniqueRef(next):
    let following = move(next.tail.node)   # `next` now has no tail, so freeing it is O(1)
    next = following
  reset(n.head)

func emptyList*[T](): ConsList[T] {.raises: [].} =
  ConsList[T]()

func isEmpty*[T](xs: ConsList[T]): bool {.raises: [].} =
  xs.node.isNil

func cons*[T](xs: ConsList[T]; x: T): ConsList[T] {.raises: [].} =
  ## New list with `x` in front; `xs` is untouched and shared.
  ConsList[T](node: Node[T](head: x, tail: xs))

func head*[T](xs: ConsList[T]): Option[T] {.raises: [].} =
  if xs.isEmpty: none(T) else: some(xs.node.head)

func tail*[T](xs: ConsList[T]): ConsList[T] {.raises: [].} =
  ## The list without its first element; the tail of the empty list is the empty list.
  if xs.isEmpty: xs else: xs.node.tail

func isUnshared*[T](xs: ConsList[T]): bool {.raises: [].} =
  ## True when no other list or variable reaches the first cell of `xs`, so that dropping `xs`
  ## frees it. Structures that tear themselves down iteratively use this to stop at shared cells.
  xs.isEmpty or isUniqueRef(xs.node)

func sharesNode*[T](a, b: ConsList[T]): bool {.raises: [].} =
  ## True when both lists start at the same node in memory (reference identity).
  a.node == b.node

iterator items*[T](xs: ConsList[T]): T {.raises: [].} =
  var cur = xs
  while not cur.isEmpty:
    yield cur.node.head
    cur = cur.node.tail

func foldLeft*[T, A](xs: ConsList[T]; init: A; f: proc(acc: A; x: T): A {.noSideEffect, raises: [].}): A {.raises: [].} =
  ## Left fold: `foldLeft([1,2,3], z, f) == f(f(f(z,1),2),3)`.
  var acc = init
  for x in items(xs):
    acc = f(acc, x)
  acc

func len*[T](xs: ConsList[T]): int {.raises: [].} =
  var n = 0
  for _ in items(xs):
    inc n
  n

func toSeq*[T](xs: ConsList[T]): seq[T] {.raises: [].} =
  for x in items(xs):
    result.add x

func reverse*[T](xs: ConsList[T]): ConsList[T] {.raises: [].} =
  var acc = emptyList[T]()
  for x in items(xs):
    acc = acc.cons(x)
  acc

func fromSeq*[T](items: openArray[T]): ConsList[T] {.raises: [].} =
  var acc = emptyList[T]()
  for i in countdown(items.high, 0):
    acc = acc.cons(items[i])
  acc

func append*[T](a, b: ConsList[T]): ConsList[T] {.raises: [].} =
  ## `a ++ b`: copies the spine of `a` (O(len a)) and shares all of `b`.
  var acc = b
  for x in items(a.reverse):
    acc = acc.cons(x)
  acc

func map*[T, U](xs: ConsList[T]; f: proc(x: T): U {.noSideEffect, raises: [].}): ConsList[U] {.raises: [].} =
  var acc = emptyList[U]()
  for x in items(xs):
    acc = acc.cons(f(x))
  acc.reverse

func `==`*[T](a, b: ConsList[T]): bool {.raises: [].} =
  a.toSeq == b.toSeq
