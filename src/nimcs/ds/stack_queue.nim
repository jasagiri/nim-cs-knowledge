## Stack (last in, first out) and queue (first in, first out) as values, plus the monotonic stack.
##
## `Stack[T]` wraps a `seq` used from its end; `Queue[T]` wraps a `std/deques` ring buffer. Both are
## value types (ADR-NCK-0002): `push`, `pop`, `enqueue` and `dequeue` return a new container and
## copy the storage, O(n), so keep a `var` local to one routine when you need the O(1) amortized
## in-place operations (the monotonic stack below does exactly that). When old versions must stay
## cheap, use `cons_list` as a persistent stack and `bankers_queue` as a persistent queue.
## `nextGreaterIndex` is the monotonic-stack technique: scan once while a stack of indices keeps its
## values decreasing, and every index leaves the stack exactly when its answer is found.

import std/[options, deques]

type
  Stack*[T] = object
    items: seq[T]       ## the top of the stack is the last element
  Queue*[T] = object
    buf: Deque[T]       ## the front of the queue is the first element

func emptyStack*[T](): Stack[T] {.raises: [].} =
  Stack[T]()

func len*[T](s: Stack[T]): int {.raises: [].} =
  s.items.len

func isEmpty*[T](s: Stack[T]): bool {.raises: [].} =
  s.items.len == 0

func push*[T](s: Stack[T]; x: T): Stack[T] {.raises: [].} =
  Stack[T](items: s.items & @[x])

func top*[T](s: Stack[T]): Option[T] {.raises: [].} =
  if s.items.len == 0: none(T) else: some(s.items[s.items.len - 1])

func pop*[T](s: Stack[T]): Stack[T] {.raises: [].} =
  ## The stack without its top item; the empty stack stays empty.
  if s.items.len == 0: s
  else: Stack[T](items: s.items[0 ..< s.items.len - 1])

func toSeq*[T](s: Stack[T]): seq[T] {.raises: [].} =
  ## The items from the top down to the bottom (the order `pop` would return them).
  result = newSeq[T](s.items.len)
  for i in 0 ..< s.items.len:
    result[i] = s.items[s.items.len - 1 - i]

func emptyQueue*[T](): Queue[T] {.raises: [].} =
  Queue[T](buf: initDeque[T]())

func len*[T](q: Queue[T]): int {.raises: [].} =
  q.buf.len

func isEmpty*[T](q: Queue[T]): bool {.raises: [].} =
  q.buf.len == 0

func enqueue*[T](q: Queue[T]; x: T): Queue[T] {.raises: [].} =
  var d = q.buf
  d.addLast x
  Queue[T](buf: d)

func front*[T](q: Queue[T]): Option[T] {.raises: [].} =
  if q.buf.len == 0: none(T) else: some(q.buf.peekFirst)

func dequeue*[T](q: Queue[T]): Queue[T] {.raises: [].} =
  ## The queue without its front item; the empty queue stays empty.
  if q.buf.len == 0: q
  else:
    var d = q.buf
    d.popFirst
    Queue[T](buf: d)

func toSeq*[T](q: Queue[T]): seq[T] {.raises: [].} =
  ## The items from the front to the back (the order `dequeue` would return them).
  for i in 0 ..< q.buf.len:
    result.add q.buf[i]

func nextGreaterIndex*[T](xs: openArray[T]): seq[Option[int]] {.raises: [].} =
  ## For each position `i`, the index of the nearest later element that is strictly greater than
  ## `xs[i]`, or `none` when there is none. O(n): each index is pushed and popped at most once.
  result = newSeq[Option[int]](xs.len)
  var pending: seq[int]           # indices still waiting, their values non-increasing from bottom to top
  for i in 0 ..< xs.len:
    while pending.len > 0 and xs[pending[pending.len - 1]] < xs[i]:
      result[pending.pop] = some(i)
    pending.add i

func nextGreater*[T](xs: openArray[T]): seq[Option[T]] {.raises: [].} =
  ## Like `nextGreaterIndex`, but gives the greater value instead of its index.
  let idx = nextGreaterIndex(xs)
  result = newSeq[Option[T]](xs.len)
  for i in 0 ..< xs.len:
    if idx[i].isSome: result[i] = some(xs[idx[i].get])
