## Persistent double-ended queue from two lists with rebalancing.
##
## The front list holds the left end in order, the rear list the right end reversed. Pushing and
## popping at either end is O(1) except when one list becomes more than twice as long as the other
## (plus one): then the elements are split evenly again at O(n). Every operation is O(1) amortized
## when each version of the deque is used once (the ephemeral use). A persistent program that
## keeps pushing onto the same old version, just short of a rebalance, pays O(n) every time;
## there is no worst-case O(1) bound here (a real-time deque needs lazy rotations). Use it when
## elements enter or leave at both ends (sliding windows, undo/redo buffers); use
## `bankers_queue` when only one end pops.

import std/options
import nimcs/ds/cons_list

type
  Deque*[T] = object
    front: ConsList[T]
    rear: ConsList[T]
    lenFront: int
    lenRear: int

const balanceFactor = 2

func emptyDeque*[T](): Deque[T] {.raises: [].} =
  Deque[T]()

func len*[T](d: Deque[T]): int {.raises: [].} =
  d.lenFront + d.lenRear

func isEmpty*[T](d: Deque[T]): bool {.raises: [].} =
  d.len == 0

func rebuilt[T](all: seq[T]; frontCount: int): Deque[T] =
  ## `all` is the whole deque left to right; the first `frontCount` go to the front list.
  var rearItems: seq[T]
  for i in countdown(all.high, frontCount):
    rearItems.add all[i]
  Deque[T](front: fromSeq(all[0 ..< frontCount]), rear: fromSeq(rearItems),
    lenFront: frontCount, lenRear: all.len - frontCount)

func toSeq*[T](d: Deque[T]): seq[T] {.raises: [].} =
  ## Elements from left to right.
  d.front.toSeq & d.rear.reverse.toSeq

func balanced[T](d: Deque[T]): Deque[T] =
  ## Invariant: each list has at most `balanceFactor * other + 1` elements.
  if d.lenFront > balanceFactor * d.lenRear + 1 or d.lenRear > balanceFactor * d.lenFront + 1:
    rebuilt(d.toSeq, d.len div 2)
  else: d

func pushFront*[T](d: Deque[T]; x: T): Deque[T] {.raises: [].} =
  Deque[T](front: d.front.cons(x), rear: d.rear, lenFront: d.lenFront + 1,
    lenRear: d.lenRear).balanced

func pushBack*[T](d: Deque[T]; x: T): Deque[T] {.raises: [].} =
  Deque[T](front: d.front, rear: d.rear.cons(x), lenFront: d.lenFront,
    lenRear: d.lenRear + 1).balanced

func peekFront*[T](d: Deque[T]): Option[T] {.raises: [].} =
  if d.front.isEmpty: d.rear.reverse.head  # only possible with one element in `rear`
  else: d.front.head

func peekBack*[T](d: Deque[T]): Option[T] {.raises: [].} =
  if d.rear.isEmpty: d.front.reverse.head
  else: d.rear.head

func popFront*[T](d: Deque[T]): Deque[T] {.raises: [].} =
  ## The deque without its leftmost element; the empty deque stays empty.
  if d.isEmpty: d
  elif d.front.isEmpty: emptyDeque[T]()  # invariant: then `rear` has exactly one element
  else:
    Deque[T](front: d.front.tail, rear: d.rear, lenFront: d.lenFront - 1,
      lenRear: d.lenRear).balanced

func popBack*[T](d: Deque[T]): Deque[T] {.raises: [].} =
  if d.isEmpty: d
  elif d.rear.isEmpty: emptyDeque[T]()
  else:
    Deque[T](front: d.front, rear: d.rear.tail, lenFront: d.lenFront,
      lenRear: d.lenRear - 1).balanced

func fromSeq*[T](items: openArray[T]): Deque[T] {.raises: [].} =
  var d = emptyDeque[T]()
  for x in items:
    d = d.pushBack(x)
  d
