## Doubly linked list in an arena, as a value.
##
## A pointer-based doubly linked list needs two `ref`s per node that point at each other, which is
## a cycle: it cannot be immutable, cannot share structure between versions, and is awkward under
## ORC. This module keeps the nodes in one `seq` (the arena) and lets them refer to each other by
## index. `prev` and `next` are indices, the list is a plain value (ADR-NCK-0002), and `insertAfter`
## and `remove` work from a handle in O(1) plus one copy of the arena (O(n)) because an update
## returns a new list. Removed slots go on a free list and are reused; each slot carries a
## generation that is bumped on removal, so a handle to a removed element is rejected instead of
## silently pointing at whatever reused the slot. Use it when elements must be inserted or removed
## in the middle through handles (an LRU order, an editor buffer); for a persistent singly linked
## list use `cons_list`, for a queue or double-ended use `bankers_queue` or `deque`.

import std/options

const
  noLink = -1

type
  NodeId* = object
    ## A handle to one element: the arena slot and the generation the slot had when it was handed out.
    index*: int
    generation*: int
  Cell[T] = object
    live: bool
    generation: int
    elem: T
    prev, next: int       ## for a dead cell, `next` links the free list
  ArenaList*[T] = object
    cells: seq[Cell[T]]
    head, tail: int
    freeHead: int
    count: int

func emptyList*[T](): ArenaList[T] {.raises: [].} =
  ArenaList[T](head: noLink, tail: noLink, freeHead: noLink)

func len*[T](l: ArenaList[T]): int {.raises: [].} =
  l.count

func isEmpty*[T](l: ArenaList[T]): bool {.raises: [].} =
  l.count == 0

func isValid[T](l: ArenaList[T]; id: NodeId): bool =
  id.index >= 0 and id.index < l.cells.len and l.cells[id.index].live and
    l.cells[id.index].generation == id.generation

func alloc[T](l: var ArenaList[T]; x: T): int =
  ## Takes a slot from the free list or grows the arena; the cell is live and unlinked.
  if l.freeHead != noLink:
    result = l.freeHead
    l.freeHead = l.cells[result].next
    l.cells[result] = Cell[T](live: true, generation: l.cells[result].generation, elem: x,
      prev: noLink, next: noLink)
  else:
    result = l.cells.len
    l.cells.add Cell[T](live: true, generation: 0, elem: x, prev: noLink, next: noLink)
  inc l.count

func linkAfter[T](l: var ArenaList[T]; at: int; x: T): int =
  ## Adds `x` right after slot `at`; `at == noLink` means "before everything" (a new head).
  let n = l.alloc(x)
  let following = if at == noLink: l.head else: l.cells[at].next
  l.cells[n].prev = at
  l.cells[n].next = following
  if at == noLink: l.head = n else: l.cells[at].next = n
  if following == noLink: l.tail = n else: l.cells[following].prev = n
  n

func handle[T](l: ArenaList[T]; index: int): NodeId =
  NodeId(index: index, generation: l.cells[index].generation)

func pushBack*[T](l: ArenaList[T]; x: T): tuple[list: ArenaList[T], id: NodeId] {.raises: [].} =
  var r = l
  let n = r.linkAfter(r.tail, x)
  (r, r.handle(n))

func pushFront*[T](l: ArenaList[T]; x: T): tuple[list: ArenaList[T], id: NodeId] {.raises: [].} =
  var r = l
  let n = r.linkAfter(noLink, x)
  (r, r.handle(n))

func insertAfter*[T](l: ArenaList[T]; id: NodeId;
    x: T): Option[tuple[list: ArenaList[T], id: NodeId]] {.raises: [].} =
  ## Inserts `x` right after the element `id` names; `none` when the handle is stale or out of range.
  if not l.isValid(id): return none(tuple[list: ArenaList[T], id: NodeId])
  var r = l
  let n = r.linkAfter(id.index, x)
  some((list: r, id: r.handle(n)))

func remove*[T](l: ArenaList[T]; id: NodeId): Option[ArenaList[T]] {.raises: [].} =
  ## The list without the element `id` names; `none` when the handle is stale or out of range.
  if not l.isValid(id): return none(ArenaList[T])
  var r = l
  let p = r.cells[id.index].prev
  let n = r.cells[id.index].next
  if p == noLink: r.head = n else: r.cells[p].next = n
  if n == noLink: r.tail = p else: r.cells[n].prev = p
  r.cells[id.index] = Cell[T](live: false, generation: id.generation + 1, prev: noLink,
    next: r.freeHead)
  r.freeHead = id.index
  dec r.count
  some(r)

func get*[T](l: ArenaList[T]; id: NodeId): Option[T] {.raises: [].} =
  if l.isValid(id): some(l.cells[id.index].elem) else: none(T)

func toSeqForward*[T](l: ArenaList[T]): seq[T] {.raises: [].} =
  ## The elements from head to tail, following `next`.
  var i = l.head
  while i != noLink:
    result.add l.cells[i].elem
    i = l.cells[i].next

func toSeqBackward*[T](l: ArenaList[T]): seq[T] {.raises: [].} =
  ## The elements from tail to head, following `prev`.
  var i = l.tail
  while i != noLink:
    result.add l.cells[i].elem
    i = l.cells[i].prev

func invariantsHold*[T](l: ArenaList[T]): bool {.raises: [].} =
  ## Forward and backward links agree, `count` matches the live cells, the head has no `prev`
  ## and the tail no `next`, and every dead cell is on the free list exactly once.
  var seen = 0
  var i = l.head
  var prev = noLink
  while i != noLink:
    if i < 0 or i >= l.cells.len or seen > l.cells.len: return false
    if not l.cells[i].live or l.cells[i].prev != prev: return false
    prev = i
    i = l.cells[i].next
    inc seen
  if prev != l.tail or seen != l.count: return false
  var live = 0
  for c in l.cells:
    if c.live: inc live
  if live != l.count: return false
  var free = 0
  var f = l.freeHead
  while f != noLink:
    if f < 0 or f >= l.cells.len or l.cells[f].live or free > l.cells.len: return false
    inc free
    f = l.cells[f].next
  free + live == l.cells.len
