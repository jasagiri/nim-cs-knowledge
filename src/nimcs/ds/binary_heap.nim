## Array-based binary min-heap, as a value.
##
## The items sit in one `seq` where the children of index `i` are `2i + 1` and `2i + 2` and no
## child is smaller than its parent, so the minimum is always at index 0. `push` appends and sifts
## up, `pop` moves the last item to the root and sifts down, `heapify` builds a heap from any
## sequence in O(n) by sifting down from the last parent to the root. The type is a value
## (ADR-NCK-0002): `push` and `pop` return a new heap and copy the array, O(n); the O(log n) sift is
## the cheap part. Build with `heapify` and drain with `toSortedSeq` (both do their sifting on a
## local copy), or use `std/heapqueue` inside one routine when in-place updates are fine. When old
## versions must stay cheap, use the persistent `leftist_heap`, `pairing_heap` or `binomial_heap`.
## The item type needs `<`.

import std/options

type
  BinaryHeap*[T] = object
    items: seq[T]

func emptyHeap*[T](): BinaryHeap[T] {.raises: [].} =
  BinaryHeap[T]()

func len*[T](h: BinaryHeap[T]): int {.raises: [].} =
  h.items.len

func isEmpty*[T](h: BinaryHeap[T]): bool {.raises: [].} =
  h.items.len == 0

func siftUp[T](a: var seq[T]; start: int) =
  var i = start
  while i > 0:
    let parent = (i - 1) div 2
    if a[i] < a[parent]:
      swap(a[i], a[parent])
      i = parent
    else:
      break

func siftDown[T](a: var seq[T]; start, limit: int) =
  ## Sifts the item at `start` down within the first `limit` items.
  var i = start
  while true:
    let l = 2 * i + 1
    let r = l + 1
    var smallest = i
    if l < limit and a[l] < a[smallest]: smallest = l
    if r < limit and a[r] < a[smallest]: smallest = r
    if smallest == i: break
    swap(a[i], a[smallest])
    i = smallest

func push*[T](h: BinaryHeap[T]; x: T): BinaryHeap[T] {.raises: [].} =
  var a = h.items
  a.add x
  a.siftUp(a.len - 1)
  BinaryHeap[T](items: a)

func peek*[T](h: BinaryHeap[T]): Option[T] {.raises: [].} =
  if h.items.len == 0: none(T) else: some(h.items[0])

func pop*[T](h: BinaryHeap[T]): BinaryHeap[T] {.raises: [].} =
  ## The heap without its minimum; the empty heap stays empty.
  if h.items.len <= 1: BinaryHeap[T]()
  else:
    var a = h.items
    a[0] = a[a.len - 1]
    a.setLen(a.len - 1)
    a.siftDown(0, a.len)
    BinaryHeap[T](items: a)

func heapify*[T](items: openArray[T]): BinaryHeap[T] {.raises: [].} =
  ## Floyd's construction, O(n): sift down every parent, last one first.
  var a = @items
  for i in countdown(a.len div 2 - 1, 0):
    a.siftDown(i, a.len)
  BinaryHeap[T](items: a)

func toSortedSeq*[T](h: BinaryHeap[T]): seq[T] {.raises: [].} =
  ## Heap sort on a copy, O(n log n); the heap itself is untouched. Each round moves the current
  ## minimum to the end of the shrinking heap, so the array ends up in descending order and is
  ## read backwards.
  var a = h.items
  var last = a.len - 1
  while last > 0:
    swap(a[0], a[last])
    a.siftDown(0, last)
    dec last
  result = newSeq[T](a.len)
  for i in 0 ..< a.len:
    result[i] = a[a.len - 1 - i]

func invariantsHold*[T](h: BinaryHeap[T]): bool {.raises: [].} =
  ## No item is smaller than its parent.
  for i in 1 ..< h.items.len:
    if h.items[i] < h.items[(i - 1) div 2]: return false
  true
