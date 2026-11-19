## Pairing heap: a mergeable persistent min-heap with a very simple shape.
##
## A node holds its element and a list of child heaps. `merge` makes the larger root a child of the
## smaller one in O(1); `deleteMin` merges the children pairwise from left to right and then
## folds the results from right to left, which is O(log n) amortized (ephemeral use). Use it as a
## default priority queue in functional code; see `leftist_heap` for a worst-case bound.

import std/options
import nimcs/ds/cons_list

type
  NodeObj[T] = object
    elem: T
    children: ConsList[Node[T]]
  Node[T] = ref NodeObj[T]
  PairingHeap*[T] = object
    root: Node[T]
    size: int

proc `=destroy`[T](n: var NodeObj[T]) =
  ## Dismantles a deep heap with a work list instead of one recursive call per level (descending
  ## inserts build a chain as deep as the heap is large). A node still reachable from another
  ## heap (`isUniqueRef` is false) is left to its last owner.
  var pending = @[move(n.children)]
  while pending.len > 0:
    var level = pending.pop
    while not level.isEmpty and level.isUnshared:
      var kid: Node[T]
      for k in items(level):    # `head` would leave an Option temporary holding a second reference
        kid = k
        break
      level = level.tail     # frees the first cell, leaving `kid` as the only owner if it was alone
      if isUniqueRef(kid):
        pending.add move(kid.children)
  reset(n.elem)

func emptyHeap*[T](): PairingHeap[T] {.raises: [].} =
  PairingHeap[T]()

func len*[T](h: PairingHeap[T]): int {.raises: [].} =
  h.size

func isEmpty*[T](h: PairingHeap[T]): bool {.raises: [].} =
  h.root.isNil

func link[T](a, b: Node[T]): Node[T] =
  if b.elem < a.elem: Node[T](elem: b.elem, children: b.children.cons(a))
  else: Node[T](elem: a.elem, children: a.children.cons(b))

func merge*[T](a, b: PairingHeap[T]): PairingHeap[T] {.raises: [].} =
  if a.isEmpty: b
  elif b.isEmpty: a
  else: PairingHeap[T](root: link(a.root, b.root), size: a.size + b.size)

func insert*[T](h: PairingHeap[T]; x: T): PairingHeap[T] {.raises: [].} =
  h.merge(PairingHeap[T](root: Node[T](elem: x), size: 1))

func findMin*[T](h: PairingHeap[T]): Option[T] {.raises: [].} =
  if h.isEmpty: none(T) else: some(h.root.elem)

func mergePairs[T](children: ConsList[Node[T]]): Node[T] =
  ## Two passes, iterative so that a wide node cannot overflow the stack.
  var paired: seq[Node[T]]
  var cur = children
  while not cur.isEmpty:
    let first = cur.head.get
    let rest = cur.tail
    if rest.isEmpty:
      paired.add first
      cur = rest
    else:
      paired.add link(first, rest.head.get)
      cur = rest.tail
  var acc: Node[T] = nil
  for i in countdown(paired.high, 0):
    acc = if acc.isNil: paired[i] else: link(paired[i], acc)
  acc

func deleteMin*[T](h: PairingHeap[T]): PairingHeap[T] {.raises: [].} =
  if h.isEmpty: h
  else: PairingHeap[T](root: mergePairs(h.root.children), size: h.size - 1)

func fromSeq*[T](items: openArray[T]): PairingHeap[T] {.raises: [].} =
  var h = emptyHeap[T]()
  for x in items:
    h = h.insert(x)
  h

func toSortedSeq*[T](h: PairingHeap[T]): seq[T] {.raises: [].} =
  var cur = h
  while not cur.isEmpty:
    result.add cur.root.elem
    cur = cur.deleteMin
