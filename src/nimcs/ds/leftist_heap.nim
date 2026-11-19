## Leftist heap: a mergeable persistent min-heap.
##
## A binary tree with the heap order (a parent is not larger than its children) and the leftist
## property: the right spine is never longer than the left one. All work follows the right spine,
## so `merge`, `insert` and `deleteMin` are O(log n) worst case. Use it when two priority queues
## must be combined often; use `pairing_heap` for lower constants in practice.

import std/options

type
  NodeObj[T] = object
    rank: int          ## length of the right spine
    elem: T
    left, right: Node[T]
  Node[T] = ref NodeObj[T]
  LeftistHeap*[T] = object
    root: Node[T]
    size: int

proc `=destroy`[T](n: var NodeObj[T]) =
  ## The left spine can be as long as the heap (descending inserts), so the default destructor
  ## would recurse once per node. A work list frees the nodes this heap owns alone; a node still
  ## reachable from another heap (`isUniqueRef` is false) is left to its last owner.
  var pending: seq[Node[T]]
  if not n.left.isNil: pending.add move(n.left)
  if not n.right.isNil: pending.add move(n.right)
  while pending.len > 0:
    let c = pending.pop
    if isUniqueRef(c):
      if not c.left.isNil: pending.add move(c.left)
      if not c.right.isNil: pending.add move(c.right)
  reset(n.elem)

func emptyHeap*[T](): LeftistHeap[T] {.raises: [].} =
  LeftistHeap[T]()

func len*[T](h: LeftistHeap[T]): int {.raises: [].} =
  h.size

func isEmpty*[T](h: LeftistHeap[T]): bool {.raises: [].} =
  h.root.isNil

func rankOf[T](n: Node[T]): int =
  if n.isNil: 0 else: n.rank

func make[T](x: T; a, b: Node[T]): Node[T] =
  ## Puts the node with the larger rank on the left.
  if rankOf(a) >= rankOf(b): Node[T](rank: rankOf(b) + 1, elem: x, left: a, right: b)
  else: Node[T](rank: rankOf(a) + 1, elem: x, left: b, right: a)

func mergeNodes[T](a, b: Node[T]): Node[T] =
  if a.isNil: b
  elif b.isNil: a
  elif b.elem < a.elem: make(b.elem, b.left, mergeNodes(a, b.right))
  else: make(a.elem, a.left, mergeNodes(a.right, b))

func merge*[T](a, b: LeftistHeap[T]): LeftistHeap[T] {.raises: [].} =
  LeftistHeap[T](root: mergeNodes(a.root, b.root), size: a.size + b.size)

func insert*[T](h: LeftistHeap[T]; x: T): LeftistHeap[T] {.raises: [].} =
  h.merge(LeftistHeap[T](root: Node[T](rank: 1, elem: x), size: 1))

func findMin*[T](h: LeftistHeap[T]): Option[T] {.raises: [].} =
  if h.isEmpty: none(T) else: some(h.root.elem)

func deleteMin*[T](h: LeftistHeap[T]): LeftistHeap[T] {.raises: [].} =
  ## The heap without its minimum; the empty heap stays empty.
  if h.isEmpty: h
  else: LeftistHeap[T](root: mergeNodes(h.root.left, h.root.right), size: h.size - 1)

func fromSeq*[T](items: openArray[T]): LeftistHeap[T] {.raises: [].} =
  var h = emptyHeap[T]()
  for x in items:
    h = h.insert(x)
  h

func toSortedSeq*[T](h: LeftistHeap[T]): seq[T] {.raises: [].} =
  ## Heap sort: repeatedly take the minimum.
  var cur = h
  while not cur.isEmpty:
    result.add cur.root.elem
    cur = cur.deleteMin

func invariantsHold*[T](h: LeftistHeap[T]): bool {.raises: [].} =
  ## Heap order, leftist property and correct stored ranks, checked over the whole tree.
  func ok(n: Node[T]): bool =
    if n.isNil: true
    else:
      (n.left.isNil or not (n.left.elem < n.elem)) and
        (n.right.isNil or not (n.right.elem < n.elem)) and
        rankOf(n.left) >= rankOf(n.right) and n.rank == rankOf(n.right) + 1 and
        ok(n.left) and ok(n.right)
  ok(h.root)
